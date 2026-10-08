#!/usr/bin/env node
// Execute the actual pure ArkTS models on the host. Native APIs are covered by
// the Harmony build and optional device suites; native services and observation
// are stubbed here. Repository writes use isolated SQLite.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const crypto = require('node:crypto');
const studio = (process.env.DEVECO_HOME || path.join(process.env.HOME, 'Applications/DevEco-Studio.app')).replace(/\/Contents$/, '') + '/Contents';
const ts = require(path.join(studio, 'tools/ohpm/node_modules/typescript'));
const originalLoad = Module._load;
Module._load = function (id, parent, isMain) {
  if (id === '@kit.ArkTS') return { util: { generateRandomUUID: () => crypto.randomUUID() } };
  if (id === '@kit.ArkData') return { relationalStore: { RdbPredicates: class {
    constructor(table) { this.table = table; this.terms = []; }
    equalTo(key, value) { this.terms.push([key, value]); return this; }
  } } };
  if (id === 'BuildProfile') return { DEBUG: false };
  if (parent?.filename.endsWith('/model/ApplicationState.ets')) {
    if (id === '../common/storage') return {};
    if (id === '../common/formDrafts') return { formDraftStore: { clear: async () => {} } };
    const nativeService = ['DeviceCalendarService', 'EventReminderService', 'SettingsService', 'AccountService', 'HapticService', 'GripService', 'ShareService', 'BackupService', 'MediaRepository', 'DemoDataRepository'].find(name => id.endsWith('/' + name));
    if (nativeService) return { [nativeService]: class { static async confirm() {} } };
  }
  if (['@kit.AbilityKit', '@kit.BackgroundTasksKit', '@kit.NotificationKit'].includes(id)) return {};
  if (id === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: 26, distributionOSApiVersion: 60100 } };
  return originalLoad.call(this, id, parent, isMain);
};
global.$r = name => name;
require.extensions['.ets'] = function (module, filename) {
  const source = fs.readFileSync(filename, 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
  module._compile(output, filename);
};
global.canIUse = () => true;
// Host execution intentionally does not model native observation or UI lifecycle.
global.Trace = () => undefined;
global.ObservedV2 = value => value;
global.Computed = () => undefined;
const root = path.resolve(__dirname, '../entry/src/main/ets');
const entities = require(root + '/model/Entities.ets');
const { CosProject, ProjectStatus, Asset, AssetStatus, ProjectAsset, ChecklistItem, PhotoAsset, PhotoStatus, CosEvent } = entities;
const day = require(root + '/model/DayMode.ets');
const { PreparationUndo, PREPARATION_UNDO_MS, usablePreparationUndo, visiblePreparationUndos, homeCandidates, advanceHomeSnapshot, reconcileHomeRows, homeTaskCapacity } = require(root + '/model/HomeSummary.ets');
const { AppState } = require(root + '/model/ApplicationState.ets');
const { EditDraft } = require(root + '/model/EditDraft.ets');
const { FormDraftStore, formDraftKey } = require(root + '/model/FormDraftStore.ets');
const { FormSession } = require(root + '/model/FormSession.ets');
const { ScheduleRoute } = require(root + '/model/ScheduleRoute.ets');
const { deadlineTasksOnDate, buildScheduleView, scheduleTaskRoute } = require(root + '/model/ScheduleView.ets');
const { scheduleGroups } = require(root + '/model/Schedule.ets');
const { EventSaveCoordinator } = require(root + '/common/EventSaveCoordinator.ets');
const { buildTaskQueue, TaskRoute, filterTaskQueue } = require(root + '/model/TaskQueue.ets');
const { LedgerRoute } = require(root + '/model/LedgerRoute.ets');
const { ledgerRange, buildLedgerSummary } = require(root + '/model/LedgerSummary.ets');
const { PlanListRoute, filterPlanList } = require(root + '/model/PlanListRoute.ets');
const { PreparationTask } = require(root + '/model/Preparation.ets');
const { Expense } = require(root + '/model/Planning.ets');
const { buildPlanReadiness, budgetLabel } = require(root + '/model/PlanReadiness.ets');
const { photoStage, portfolioStage } = require(root + '/model/Rules.ets');
const { photoDistribution } = require(root + '/model/Statistics.ets');
const { executeOperation, operationCommitted } = require(root + '/model/OperationResult.ets');
// A real isolated SQLite connection exercises the actual backup repository and
// migration SQL. The adapter only translates RDB result accessors and RPC.
const { spawn } = require('node:child_process');
const readline = require('node:readline');
class SqliteAdapter {
  constructor() {
    const worker = `import json, sqlite3, sys
connection = sqlite3.connect(':memory:', isolation_level=None)
connection.execute('PRAGMA foreign_keys=ON')
for line in sys.stdin:
    try:
        request = json.loads(line)
        cursor = connection.execute(request['sql'], request.get('args', []))
        result = {'columns': [field[0] for field in cursor.description], 'rows': cursor.fetchall()} if cursor.description else {'columns': [], 'rows': []}
        print(json.dumps({'result': result}), flush=True)
    except Exception as error:
        print(json.dumps({'error': str(error)}), flush=True)
connection.close()
`;
    this.pending = [];
    this.worker = spawn('python3', ['-u', '-c', worker], { stdio: ['pipe', 'pipe', 'inherit'] });
    readline.createInterface({ input: this.worker.stdout }).on('line', line => {
      const response = JSON.parse(line), waiter = this.pending.shift();
      if (response.error) waiter.reject(new Error(response.error)); else waiter.resolve(response.result);
    });
  }
  sql(sql, args = []) { if (this.failSql && sql.startsWith(this.failSql)) return Promise.reject(new Error('injected write failure')); return new Promise((resolve, reject) => { this.pending.push({ resolve, reject }); this.worker.stdin.write(JSON.stringify({ sql, args }) + '\n'); }); }
  getStore() { return this; }
  async executeSql(sql, args) { await this.sql(sql, args); }
  async update(values, predicate) {
    await this.sql('UPDATE ' + predicate.table + ' SET ' + Object.keys(values).map(key => key + '=?').join(',') + ' WHERE ' + predicate.terms.map(([key]) => key + '=?').join(' AND '), [...Object.values(values), ...predicate.terms.map(([, value]) => value)]);
    return (await this.sql('SELECT changes()')).rows[0][0];
  }
  async querySql(sql, args) {
    const data = await this.sql(sql, args); let index = -1;
    return {
      rowCount: data.rows.length, goToNextRow: () => ++index < data.rows.length,
      getColumnIndex: key => data.columns.indexOf(key), getValue: col => data.rows[index][col],
      getString: col => String(data.rows[index][col]), getLong: col => Number(data.rows[index][col]),
      isColumnNull: col => data.rows[index][col] === null, close: () => {},
    };
  }
  async transaction(action) {
    await this.sql('BEGIN');
    try {
      await action({ execute: (sql, args) => this.executeSql(sql, args), insert: (table, row) => this.sql('INSERT INTO ' + table + '(' + Object.keys(row).join(',') + ') VALUES(' + Object.keys(row).map(() => '?').join(',') + ')', Object.values(row)) });
      await this.sql('COMMIT');
    } catch (error) { await this.sql('ROLLBACK'); throw error; }
  }
  close() { this.worker.stdin.end(); }
}
let count = 0;
async function test(name, action) { await action(); count++; console.log('PASS ' + name); }
const project = Object.assign(new CosProject(), { id: 'p', eventId: 'event' });
const event = Object.assign(new CosEvent(), { id: 'event', date: '2026-12-31' });
const task = (id, dueDate, extra = {}) => Object.assign(new PreparationTask(), { id, projectId: 'p', dueDate, label: id }, extra);
const tasks = [task('overdue', '2026-12-30'), task('today', '2026-12-31'), task('week', '2027-01-07'), task('later', '2027-01-08'), task('undated', ''), task('waiting', '2026-12-01', { waitingOn: '快递' }), task('until', '', { waitingUntil: '2027-01-03' }), task('done', '2026-12-01', { done: true, waitingOn: '快递' })];
const asset = Object.assign(new Asset(), { id: 'a', status: AssetStatus.REPAIR, priceCents: 90000 });
const link = Object.assign(new ProjectAsset(), { projectId: 'p', assetId: 'a' });
const pack = Object.assign(new ChecklistItem(), { projectId: 'p', done: true });
const expenses = [Object.assign(new Expense(), { projectId: 'p', amountCents: 1234 }), Object.assign(new Expense(), { projectId: 'other', amountCents: 9999 })];
const photos = Object.values(PhotoStatus).map(status => Object.assign(new PhotoAsset(), { projectId: 'p', status }));
const read = () => buildPlanReadiness(project, tasks, [pack], [asset], [link], photos, expenses, [event], '2026-12-31');
(async () => {
  const dayEvent = Object.assign(new CosEvent(), { id: 'day', date: '2026-10-08', dateMode: 'multiple', endDate: '2026-10-10' });
  const time = value => new Date(value).getTime();
  await test('day entry opens at local eve 20:00 and ends after the entire last day', () => {
    assert.equal(day.dayWindow(dayEvent, time('2026-10-07T19:59:59')), false);
    assert.equal(day.dayWindow(dayEvent, time('2026-10-07T20:00:00')), true);
    assert.equal(day.dayWindow(dayEvent, time('2026-10-10T23:59:59')), true);
    assert.equal(day.dayWindow(dayEvent, time('2026-10-11T00:00:00')), false);
    assert.equal(day.dayWindow(Object.assign(new CosEvent(), { dateMode: 'pending' }), time('2026-10-08T12:00:00')), false);
    assert.equal(day.dayTitle(dayEvent, time('2026-10-07T20:00:00')), '明天 · ' + dayEvent.name);
    assert.equal(day.dayNumber(dayEvent, time('2026-10-09T12:00:00')), '第 2 天');
    const newYear = Object.assign(new CosEvent(), { date: '2027-01-01' });
    assert.equal(day.dayWindow(newYear, time('2026-12-31T20:00:00')), true);
  });
  await test('dismissal is per event and local day; a multi-day entry returns tomorrow', () => {
    const another = Object.assign(new CosEvent(), { id: 'another', date: '2026-10-08' });
    const tomorrow = Object.assign(new CosEvent(), { id: 'tomorrow', date: '2026-10-09' });
    assert.deepEqual(day.dayEntries([dayEvent, another], { day: '2026-10-08' }, time('2026-10-08T12:00:00')).map(e => e.id), ['another']);
    assert.deepEqual(day.dayEntries([dayEvent, another], { day: '2026-10-08' }, time('2026-10-09T12:00:00')).map(e => e.id), ['day']);
    assert.equal(day.dayEntries([tomorrow, dayEvent], {}, time('2026-10-08T21:00:00'))[0].id, 'day');
    assert.deepEqual(day.dayEntries([dayEvent], {}, time('2026-10-11T00:00:00')), []);
    assert.equal(day.dayTitle(dayEvent, time('2026-10-11T00:00:00')), '2026-10-08 · ' + dayEvent.name);
  });
  await test('multi-event strip prioritizes the next start before elapsed starts and tomorrow', () => {
    const make = (id, date, startTime) => Object.assign(new CosEvent(), { id, date, timeMode: 'start', startTime });
    const events = [make('elapsed', '2026-10-08', '09:00'), make('next', '2026-10-08', '22:00'), make('tomorrow', '2026-10-09', '08:00')];
    assert.deepEqual(day.dayEntries(events, {}, time('2026-10-08T21:00:00')).map(e => e.id), ['next', 'elapsed', 'tomorrow']);
  });
  await test('empty, typical and full module assembly keeps the fixed two sections', () => {
    const now = time('2026-10-08T19:00:00');
    const emptyEvent = Object.assign(new CosEvent(), { id: 'empty', dateMode: 'pending' });
    assert.deepEqual(day.availableDayModules(emptyEvent, [], [], [], now), []);
    for (const section of [0, 1]) assert.deepEqual(day.assembledDayModules([], {}, section), []);
    const projects = [Object.assign(new CosProject(), { id: 'p', eventId: 'day' })];
    const typical = day.availableDayModules(dayEvent, projects, [], [], time('2026-10-08T12:00:00'));
    assert.deepEqual(day.assembledDayModules(typical, {}, 0).map(m => m.id), ['packing']);
    assert.deepEqual(day.assembledDayModules(typical, {}, 1).map(m => m.id), ['plans']);
    const entries = [{ scopeKind: 'event', scopeId: 'day', kind: 'ticket' }], team = [{ projectId: 'p' }];
    const fullEvent = Object.assign(new CosEvent(), dayEvent, { timeMode: 'start', startTime: '09:00' });
    const full = day.availableDayModules(fullEvent, projects, entries, team, now, true);
    assert.deepEqual(day.assembledDayModules(full, {}, 0).map(m => m.id), ['packing', 'credentials', 'people']);
    assert.deepEqual(day.assembledDayModules(full, {}, 1).map(m => m.id), ['plans', 'shots', 'timeline', 'wrapup']);
    assert.equal(day.availableDayModules(dayEvent, [], [], [], time('2026-10-07T21:00:00')).includes('wrapup'), false);
    assert.equal(day.availableDayModules(dayEvent, [], [], [], time('2026-10-08T17:59:59')).includes('wrapup'), false);
  });
  await test('module preferences validate input and preserve disabled modules and order', () => {
    assert.deepEqual(day.parseDayModules('broken'), {}); assert.deepEqual(day.parseDayModules('null'), {});
    const preferences = day.parseDayModules(JSON.stringify({ packing: { enabled: false, order: 2 }, people: { enabled: true, order: 0 }, credentials: { enabled: true, order: 1 }, extra: { enabled: true, order: 0 } }));
    assert.equal(preferences.extra, undefined);
    assert.deepEqual(day.orderedDayModules(preferences, 0).map(m => m.id), ['people', 'credentials', 'packing']);
    assert.deepEqual(day.assembledDayModules(['packing', 'people', 'credentials'], preferences, 0).map(m => m.id), ['people', 'credentials']);
    assert.deepEqual(day.parseDayModules('{"packing":{"enabled":"false","order":0}}'), {});
  });
  await test('schedule groups keep ongoing multi-day activities visible and isolate pending dates', () => {
    const pending = Object.assign(new CosEvent(), { id: 'pending', dateMode: 'pending' });
    const future = Object.assign(new CosEvent(), { id: 'future', date: '2026-10-12' });
    const ended = Object.assign(new CosEvent(), { id: 'ended', date: '2026-10-01' });
    assert.deepEqual(scheduleGroups([future, ended, pending, dayEvent], '2026-10-09').map(g => g.events.map(e => e.id)), [['day'], ['future'], ['pending'], ['ended']]);
  });
  await test('schedule route shares its selected day across modes, clamps month navigation and retains source offsets', () => {
    const route = new ScheduleRoute('2024-01-31');
    assert.equal(route.dateFocused, false); assert.equal(route.calendar, false);
    route.offsets = [240, 110]; route.showCalendar(true); route.moveMonth(1);
    assert.equal(route.selectedDate, '2024-02-29'); assert.equal(route.month, 1);
    route.showCalendar(false); assert.equal(route.selectedDate, '2024-02-29'); assert.equal(route.dateFocused, true);
    route.selectDate('2026-12-31'); route.moveMonth(1); assert.equal(route.selectedDate, '2027-01-31');
    route.selectDate('invalid'); assert.equal(route.selectedDate, '2027-01-31');
    route.showPending(); assert.equal(route.calendar, false); assert.equal(route.dateFocused, false); assert.equal(route.filter, 2);
    assert.equal(route.selectedDate, '2027-01-31'); assert.deepEqual(route.offsets, [240, 110]);
    route.clearDate(); assert.equal(route.filter, 0);
  });
  await test('schedule cells and selected-day list share multi-day events, actual task deadlines and pending-date access', () => {
    const ongoing = Object.assign(new CosEvent(), { id: 'ongoing', date: '2026-12-30', dateMode: 'multiple', endDate: '2027-01-02', eventType: '漫展' });
    const shoot = Object.assign(new CosEvent(), { id: 'shoot', date: '2026-12-31', eventType: '拍摄' });
    const pending = Object.assign(new CosEvent(), { id: 'pending', dateMode: 'pending', eventType: '漫展' });
    const route = new ScheduleRoute('2026-12-31'); route.selectDate('2026-12-31');
    const model = () => buildScheduleView([ongoing, shoot, pending], [read()], [project], route, '2026-12-31');
    let view = model(); const cell = view.days.find(item => item.day.date === route.selectedDate);
    assert.strictEqual(view.selectedEvents, cell.events); assert.strictEqual(view.selectedTasks, cell.tasks);
    assert.deepEqual(view.selectedEvents.map(item => item.id).sort(), ['ongoing', 'shoot']);
    assert.deepEqual(view.selectedTasks.map(item => item.task.id), ['today']); assert.equal(view.pendingCount, 1);
    assert.strictEqual(view.groups[0].events, view.selectedEvents);
    route.showCalendar(true); route.showCalendar(false); assert.deepEqual(model().selectedTasks.map(item => item.task.id), ['today']);
    route.eventType = '漫展'; view = model(); assert.deepEqual(view.selectedEvents.map(item => item.id), ['ongoing']); assert.equal(view.selectedTasks.length, 1);
    route.showPending(); view = model(); assert.deepEqual(view.groups[0].events.map(item => item.id), ['pending']);
    route.selectDate('2027-01-02'); assert.deepEqual(model().selectedEvents.map(item => item.id), ['ongoing']);
    route.selectDate('2027-01-03'); assert.deepEqual(model().selectedEvents, []);
  });
  await test('deadline task rows stay stable after completion, retain waiting semantics and route to the exact preparation item', () => {
    const p = Object.assign(new CosProject(), { id: 'calendar-plan', name: '日历计划' });
    const localTasks = [Object.assign(new PreparationTask(), { id: 'normal', projectId: p.id, label: '普通任务', dueDate: '2026-10-01', sortOrder: 0 }), Object.assign(new PreparationTask(), { id: 'waiting', projectId: p.id, label: '等待任务', dueDate: '2026-10-01', waitingOn: '快递', waitingUntil: '2026-10-03', sortOrder: 1 }), Object.assign(new PreparationTask(), { id: 'undated', projectId: p.id })];
    const plans = () => [buildPlanReadiness(p, localTasks, [], [], [], [], [], [], '2026-10-08')];
    const items = () => deadlineTasksOnDate(plans(), [p], '2026-10-01');
    let rows = items(); assert.deepEqual(rows.map(item => item.task.id), ['normal', 'waiting']);
    assert.equal(rows[0].overdue, true); assert.equal(rows[1].waiting, true); assert.equal(rows[1].overdue, false);
    assert.deepEqual(deadlineTasksOnDate(plans(), [p], '2026-10-03'), []);
    const target = scheduleTaskRoute(rows[1]); assert.equal(target.projectId, p.id); assert.equal(target.focusId, 'waiting'); assert.equal(target.section, 1); assert.equal(target.source, 'preparation');
    localTasks[0].done = true; rows = items(); assert.deepEqual(rows.map(item => item.task.id), ['normal', 'waiting']); assert.equal(rows[0].task.done, true); assert.equal(rows[0].overdue, false);
    p.status = ProjectStatus.COMPLETED; assert.deepEqual(items(), []);
    p.status = ProjectStatus.ARCHIVED; assert.deepEqual(items(), []);
  });
  await test('notification publishing failure preserves reminder intent and can be retried', async () => {
    const event = Object.assign(new CosEvent(), { date: '2027-01-01', reminderMinutes: 30 });
    let persisted, published = 0;
    const coordinator = new EventSaveCoordinator(async event => { persisted = { ...event }; }, async () => { if (++published === 1) throw new Error('通知未授权'); return 42; }, async () => {});
    assert.match(await coordinator.save(event), /通知未授权/);
    assert.equal(persisted.reminderMinutes, 30); assert.equal(persisted.reminderId, -1);
    assert.match(day.reminderState(event, time('2026-10-08T12:00:00')), /未建立/);
    await coordinator.save(event, persisted); assert.equal(persisted.reminderId, 42); assert.equal(published, 2);
    assert.equal(day.reminderState(event, time('2026-10-08T12:00:00')), '系统提醒已建立');
    assert.equal(day.reminderState(event, time('2027-01-01T12:00:00')), '提醒时间已过');
    event.reminderMinutes = -1; assert.equal(day.reminderState(event, time('2027-01-01T12:00:00')), '未选择提醒');
  });
  await test('readiness keeps preparation, packing and equipment independent', () => {
    const r = read(); assert.equal(r.prep.done, 1); assert.equal(r.prep.total, 8); assert.equal(r.prep.waiting, 2);
    assert.equal(r.pack.packed, 1); assert.equal(r.equipment.available, 0); assert.equal(r.equipment.total, 1);
    assert.equal(r.money.spentCents, 1234); assert.equal(r.date, event.date); assert.equal(r.dateFromEvent, true);
  });
  await test('waiting and undated tasks never become overdue; week crosses year', () => {
    const r = read(); assert.deepEqual(r.prep.overdue.map(t => t.id), ['overdue']); assert.deepEqual(r.prep.today.map(t => t.id), ['today']);
    assert.deepEqual(r.prep.upcoming.map(t => t.id), ['week']); assert.deepEqual(r.prep.undated.map(t => t.id), ['undated']);
    assert.equal(r.prep.pending.length, 5); assert.equal(r.prep.next.id, 'overdue');
  });
  await test('finished plans leave the actionable date groups', () => {
    for (const status of [ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED]) { project.status = status; const r = read(); assert.equal(r.active, false); assert.equal(r.prep.overdue.length, 0); }
    project.status = ProjectStatus.PREPARING;
  });
  await test('explicit date overrides activity date without mutating either', () => {
    project.targetDate = '2027-01-02'; const r = read(); assert.equal(r.date, project.targetDate); assert.equal(r.dateFromEvent, false); assert.equal(event.date, '2026-12-31'); project.targetDate = '';
  });
  await test('empty preparation and packing stay empty', () => {
    const r = buildPlanReadiness(project, [], [], [], [], [], [], [], '2026-12-31'); assert.equal(r.prep.total, 0); assert.equal(r.prep.percent, 0); assert.equal(r.pack.total, 0); assert.equal(r.photos.byStage.reduce((a, b) => a + b, 0), 0);
  });
  await test('plan date and detailed status filters compose with all three list sections', () => {
    const make = (id, status, targetDate, eventId = '') => Object.assign(new CosProject(), { id, name: id, characterId: 'role', status, targetDate, eventId });
    const list = [make('ready-undated', ProjectStatus.READY, ''), make('event-inherited', ProjectStatus.PREPARING, '', 'event'), make('complete-undated', ProjectStatus.COMPLETED, ''), make('archived', ProjectStatus.ARCHIVED, '2027-01-03'), make('next-week', ProjectStatus.READY, '2027-01-07')];
    const role = Object.assign(new entities.Character(), { id: 'role', name: '角色名' });
    const plans = list.map(p => buildPlanReadiness(p, [], [], [], [], [], [], [event], '2026-12-31'));
    const route = new PlanListRoute();
    const find = () => filterPlanList(list, plans, [role], route, '2026-12-31').map(p => p.id);
    assert.deepEqual(find(), ['ready-undated', 'event-inherited', 'next-week']);
    route.dateRange = 'undated'; route.status = ProjectStatus.READY;
    assert.deepEqual(find(), ['ready-undated']);
    route.section = 1; route.status = '';
    assert.deepEqual(find(), ['complete-undated']);
    route.section = 2; route.dateRange = 'week'; route.status = ProjectStatus.ARCHIVED;
    assert.deepEqual(find(), ['archived']);
    route.status = ProjectStatus.READY;
    assert.deepEqual(find(), ['next-week']);
    route.status = ''; route.dateRange = 'today'; route.query = '  角色名  ';
    assert.deepEqual(find(), ['event-inherited']);
    route.query = 'no match';
    assert.deepEqual(find(), []);
    assert.equal(list[1].targetDate, ''); assert.equal(list[3].status, ProjectStatus.ARCHIVED);
    route.offsets = [18, 240, 60]; route.section = 1;
    assert.equal(route.offsets[route.section], 240);
  });
  await test('task queue uses one row per photo stage and never counts waiting as overdue', () => {
    const queue = buildTaskQueue([read()], [project], '2026-12-31');
    const awaiting = queue.filter(item => item.kind === 'waiting');
    assert.equal(awaiting.filter(item => item.source === 'preparation').length, 2);
    assert.equal(awaiting.filter(item => item.source === 'asset').length, 1);
    const route = new TaskRoute(); const actionable = filterTaskQueue(queue, route, '2026-12-31');
    assert.equal(actionable.some(item => item.kind === 'waiting'), false);
    assert.equal(actionable.some(item => item.focusId === 'undated'), false);
    assert.equal(actionable.some(item => item.focusId === 'later'), false);
    assert.equal(actionable.filter(item => item.kind === 'photo').length, 2);
    const manyPhotos = Array.from({ length: 32 }, () => Object.assign(new PhotoAsset(), { projectId: 'p' }));
    const many = buildTaskQueue([buildPlanReadiness(project, [], [], [], [], manyPhotos, [], [event], '2026-12-31')], [project], '2026-12-31');
    assert.equal(many.length, 1); assert.equal(many[0].title, '待选 32 张'); assert.equal(many[0].section, 3); assert.equal(many[0].photoFilter, 1);
    route.category = 'waiting'; route.range = 'all'; assert.equal(filterTaskQueue(queue, route, '2026-12-31').length, 3);
    route.range = 'overdue'; assert.equal(filterTaskQueue(queue, route, '2026-12-31').length, 0);
    const preparationItem = queue.find(item => item.focusId === 'overdue'); assert.equal(preparationItem.section, 1);
    const pendingPack = Object.assign(new ChecklistItem(), { projectId: 'p', done: false });
    const packingQueue = buildTaskQueue([buildPlanReadiness(project, [], [pendingPack], [], [], [], [], [event], '2026-12-31')], [project], '2026-12-31');
    assert.equal(packingQueue[0].section, 2); assert.equal(packingQueue[0].focusId, pendingPack.id);
    const completed = Object.assign(new CosProject(), project, { status: ProjectStatus.COMPLETED });
    assert.deepEqual(buildTaskQueue([buildPlanReadiness(completed, tasks, [pendingPack], [asset], [link], photos, [], [event], '2026-12-31')], [completed], '2026-12-31'), []);
    route.category = 'preparation'; route.range = 'undated'; assert.deepEqual(filterTaskQueue(queue, route, '2026-12-31').map(item => item.focusId), ['undated']);
    route.range = 'all'; route.projectId = 'missing'; assert.equal(filterTaskQueue(queue, route, '2026-12-31').length, 0);
  });
  await test('form snapshots preserve creation IDs and business changes while ignoring view expansion', () => {
    const state = new AppState(); const draft = EditDraft.make(state, 'project');
    const original = draft.fingerprint(); draft.advanced = true; draft.preparationExpanded = true;
    assert.equal(draft.fingerprint(), original);
    draft.characterName = '角色'; draft.name = '漫展计划'; draft.money = '0'; draft.budgetEdited = true;
    const restored = EditDraft.fromJSON(draft.serialize());
    assert.equal(restored.creationId, draft.creationId); assert.equal(restored.creationCharacterId, draft.creationCharacterId);
    assert.equal(restored.fingerprint(), draft.fingerprint()); assert.equal(restored.money, '0');
    assert.equal(restored.preparationKeys.length, draft.preparationKeys.length);
    assert.notEqual(restored.preparationKeys, draft.preparationKeys);
    assert.notEqual(draft.fingerprint(), original);
    const fresh = EditDraft.make(state, 'project'); assert.equal(fresh.fingerprint(), original);
    assert.throws(() => EditDraft.fromJSON('{}'), /草稿/);
    const broken = JSON.parse(draft.serialize()); broken.notes = 4;
    assert.throws(() => EditDraft.fromJSON(JSON.stringify(broken)), /草稿字段/);
  });
  await test('form validation identifies exact schedule fields and rejects stale owners without creating replacements', async () => {
    const state = new AppState(); state.projects = [project];
    const missing = EditDraft.make(state, 'project', 'deleted');
    assert.equal(missing.issues(state)[0].field, 'object'); assert.equal(await missing.save(state), false);
    const expense = EditDraft.make(state, 'expense'); expense.name = '摄影'; expense.money = '12.34';
    assert.equal(expense.issues(state)[0].field, 'parentId'); expense.parentId = project.id;
    assert.deepEqual(expense.issues(state), []); expense.money = '-1'; assert.equal(expense.issues(state)[0].field, 'money');
    const event = EditDraft.make(state, 'event'); event.name = '漫展'; event.dateMode = 'multiple'; event.date = '2026-10-08'; event.endDate = '2026-10-07';
    assert.equal(event.issues(state)[0].field, 'endDate');
    event.endDate = event.date; event.timeMode = 'range'; event.startTime = '09:00'; event.endTime = '08:00';
    assert.equal(event.issues(state)[0].field, 'endTime');
    event.endTime = '10:00'; assert.deepEqual(event.issues(state), []);
    event.timeMode = 'invalid'; assert.equal(event.issues(state)[0].field, 'timeMode');
    const preparation = EditDraft.make(state, 'preparation', '', project.id); preparation.name = '任务';
    assert.equal(preparation.issues(state)[0].field, 'categoryId');
  });
  await test('form drafts persist separately by object context and recover only after explicit selection', async () => {
    let text = ''; const store = new FormDraftStore({ read: async () => text, write: async value => { text = value; } });
    const state = new AppState(); const first = new FormSession(EditDraft.make(state, 'event', '', '2026-10-08'), store);
    await first.initialize(state); first.draft.name = '保留活动'; first.draft.notes = '未提交';
    assert.equal(first.dirty, true); assert.equal(await first.flush(), true);
    assert.equal(state.events.length, 0); assert.equal(first.savedAt > 0, true);
    const other = new FormSession(EditDraft.make(state, 'event', '', '2026-10-09'), store);
    await other.initialize(state); assert.equal(other.pendingRestore, undefined);
    const reopened = new FormSession(EditDraft.make(state, 'event', '', '2026-10-08'), store);
    await reopened.initialize(state); assert.equal(reopened.draft.name, ''); assert.equal(reopened.pendingRestore.payload.includes('未提交'), true);
    assert.equal(await reopened.finish(false), true); // untouched close keeps the saved draft
    const selected = new FormSession(EditDraft.make(state, 'event', '', '2026-10-08'), store);
    await selected.initialize(state); selected.restore();
    assert.equal(selected.draft.name, '保留活动'); assert.equal(selected.recoveredAt, first.savedAt);
    assert.equal(selected.pendingRestore, undefined); assert.equal(selected.dirty, true);
    assert.equal(await selected.finish(true), true); assert.equal(await store.load(formDraftKey(first.draft)), undefined);
    assert.equal(await selected.flush(), true); assert.equal(await store.load(formDraftKey(first.draft)), undefined);
  });
  await test('a global expense draft keeps its recovery context after the user selects a plan', async () => {
    let text = ''; const store = new FormDraftStore({ read: async () => text, write: async value => { text = value; } });
    const state = new AppState(); state.projects = [project];
    const draft = EditDraft.make(state, 'expense'); const key = formDraftKey(draft);
    const session = new FormSession(draft, store); await session.initialize(state);
    draft.parentId = project.id; draft.name = '摄影费'; draft.money = '12.34'; await session.flush();
    assert.equal(EditDraft.fromJSON((await store.load(key)).payload).parentId, project.id);
    const reopened = new FormSession(EditDraft.make(state, 'expense'), store); await reopened.initialize(state); reopened.restore();
    assert.equal(reopened.draft.parentId, project.id); assert.deepEqual(reopened.draft.issues(state), []);
    assert.equal(state.expenses.length, 0); await reopened.finish(true); assert.equal(await store.load(key), undefined);
  });
  await test('draft queues serialize cleanup after pending writes and retain failed drafts for retry', async () => {
    let text = '', failed = false, release;
    const gate = new Promise(resolve => { release = resolve; }); let block = true;
    const store = new FormDraftStore({ read: async () => text, write: async value => { if (block) await gate; if (failed) throw new Error('full'); text = value; } });
    const state = new AppState(); const session = new FormSession(EditDraft.make(state, 'character'), store); await session.initialize(state);
    session.draft.name = '草稿'; const write = session.flush(); const finish = session.finish(true); release();
    assert.equal(await write, true); assert.equal(await finish, true); assert.equal((await store.load(formDraftKey(session.draft))), undefined);
    block = false;
    const retry = new FormSession(EditDraft.make(state, 'character'), store); await retry.initialize(state); retry.draft.name = '再次输入';
    failed = true; assert.equal(await retry.flush(), false); assert.equal(retry.error.includes('尚未保存'), true);
    failed = false; assert.equal(await retry.flush(), true); failed = true;
    assert.equal(await retry.finish(true), false); assert.equal(retry.dirty, true);
    failed = false; assert.equal(await retry.finish(true), true);
  });
  await test('unread recovery cannot be overwritten; explicit bypass preserves old drafts and allows local input', async () => {
    let text = 'broken JSON'; const store = new FormDraftStore({ read: async () => text, write: async value => { text = value; } });
    const state = new AppState(); const session = new FormSession(EditDraft.make(state, 'character'), store);
    await session.initialize(state); assert.equal(session.recoveryChecked, false);
    session.draft.name = '未覆盖'; assert.equal(await session.flush(), false); assert.equal(text, 'broken JSON');
    session.ignoreRecovery(); assert.equal(session.recoveryChecked, true); assert.equal(session.skipDrafts, true);
    assert.equal(await session.flush(), true); assert.equal(text, 'broken JSON');
    assert.equal(await session.finish(true), true); assert.equal(text, 'broken JSON');
    await store.clear();
    const retry = new FormSession(EditDraft.make(state, 'character'), store); await retry.initialize(state);
    assert.equal(retry.recoveryChecked, true); assert.equal(retry.pendingRestore, undefined);
  });
  await test('restoring an edit notices source changes; a committed create draft is never replayed', async () => {
    let text = ''; const store = new FormDraftStore({ read: async () => text, write: async value => { text = value; } });
    const state = new AppState(); const character = Object.assign(new entities.Character(), { id: 'draft-character', name: '原名' }); state.characters = [character];
    const edit = new FormSession(EditDraft.make(state, 'character', character.id), store); await edit.initialize(state); edit.draft.name = '未提交名字'; await edit.flush();
    character.name = '另一处已改'; const reopened = new FormSession(EditDraft.make(state, 'character', character.id), store); await reopened.initialize(state); reopened.restore();
    assert.equal(reopened.sourceChanged, true); assert.equal(reopened.draft.name, '未提交名字'); assert.equal(character.name, '另一处已改');
    const creating = new FormSession(EditDraft.make(state, 'character'), store); await creating.initialize(state); creating.draft.name = '新角色'; await creating.flush();
    const committed = Object.assign(new entities.Character(), { id: creating.draft.creationId, name: '新角色' }); state.characters.push(committed);
    assert.equal(await creating.draft.save(state), false); assert.equal(state.characters.length, 2);
    const next = new FormSession(EditDraft.make(state, 'character'), store); await next.initialize(state);
    assert.equal(next.pendingRestore, undefined); assert.equal(next.error.includes('上次创建已保存'), true);
    assert.equal(await store.load(formDraftKey(creating.draft)), undefined);
    text = 'bad json'; await assert.rejects(store.load(formDraftKey(next.draft)));
    assert.equal(text, 'bad json'); await store.clear(); assert.equal(text, '');
  });
  await test('home summary keeps waiting first and stable rows through completion, undo and retirement', () => {
    const queue = buildTaskQueue([read()], [project], '2026-12-31');
    const snapshot = homeCandidates(queue);
    assert.equal(snapshot.length, 5); assert.equal(snapshot[0].kind, 'waiting');
    assert.equal(snapshot.some(item => ['undated', 'later'].includes(item.group)), false);
    const target = snapshot.find(item => item.source === 'preparation');
    const original = tasks.find(item => item.id === target.focusId);
    const token = new PreparationUndo(original, 1000);
    const remaining = queue.filter(item => item.focusId !== target.focusId).reverse();
    let rows = reconcileHomeRows(snapshot, remaining, [token], 1001);
    assert.deepEqual(rows.map(row => row.key), snapshot.map(item => item.id));
    assert.equal(rows.find(row => row.key === target.id).undo.id, token.id);
    assert.equal(rows.find(row => row.key === target.id).retired, false);
    rows = reconcileHomeRows(snapshot, remaining, [token], token.expiresAt);
    assert.equal(rows.find(row => row.key === target.id).retired, true);
    rows = reconcileHomeRows(snapshot, queue.slice().reverse(), [], 1002);
    assert.deepEqual(rows.map(row => row.key), snapshot.map(item => item.id));
    assert.equal(rows.find(row => row.key === target.id).retired, false);
    const moved = Object.assign({}, target, { id: 'preparation:' + target.projectId + ':' + target.focusId, kind: 'preparation', group: 'today' });
    rows = reconcileHomeRows(snapshot, [moved], [], 1002);
    assert.equal(rows.find(row => row.key === target.id).item.kind, 'preparation');
    assert.equal(rows.find(row => row.key === target.id).key, target.id);
  });
  await test('home refills new work at the end without reordering pending rows or interrupting undo', () => {
    const queue = buildTaskQueue([read()], [project], '2026-12-31');
    const snapshot = homeCandidates(queue); const target = snapshot[0];
    const token = new PreparationUndo(tasks.find(task => task.id === target.focusId), 1000);
    const remaining = queue.filter(item => item.focusId !== target.focusId);
    assert.deepEqual(advanceHomeSnapshot(snapshot, remaining, [token], token.expiresAt - 1).map(item => item.id), snapshot.map(item => item.id));
    let updated = advanceHomeSnapshot(snapshot, remaining, [token], token.expiresAt);
    assert.equal(updated[0].id, target.id); // the retired row can animate to zero before removal
    updated = advanceHomeSnapshot(updated, remaining, [token], token.expiresAt + 1000);
    assert.deepEqual(updated.slice(0, 4).map(item => item.id), snapshot.slice(1).map(item => item.id));
    assert.equal(updated.length, 5); assert.equal(updated.some(item => item.id === target.id), false);
    const added = Object.assign({}, queue[0], { id: 'new-task', focusId: 'new-task' });
    const short = snapshot.slice(0, 2);
    const next = advanceHomeSnapshot(short, [added, ...queue], [], 1001);
    assert.deepEqual(next.slice(0, 2).map(item => item.id), short.map(item => item.id));
    assert.equal(next[2].id, added.id);
  });
  await test('undo eligibility rejects elapsed windows, changed values, missing tasks and finished plans', () => {
    const original = task('undo', '2026-12-31'); const token = new PreparationUndo(original, 1000);
    const completed = Object.assign(new PreparationTask(), original, { done: true });
    assert.equal(token.previousDone, false); assert.equal(token.expectedDone, true); assert.equal(token.expiresAt, 1000 + PREPARATION_UNDO_MS);
    assert.equal(usablePreparationUndo(token, [completed], [project], token.expiresAt - 1), true);
    assert.equal(usablePreparationUndo(token, [completed], [project], token.expiresAt), false);
    assert.equal(usablePreparationUndo(token, [original], [project], 1001), false);
    assert.equal(usablePreparationUndo(token, [], [project], 1001), false);
    assert.equal(usablePreparationUndo(token, [completed], [Object.assign(new CosProject(), project, { status: ProjectStatus.ARCHIVED })], 1001), false);
    assert.equal(visiblePreparationUndos([token], [original], [project], 1001, true).length, 1);
    assert.equal(visiblePreparationUndos([token], [original], [project], 1001, false).length, 0);
    assert.equal(visiblePreparationUndos([token], [], [project], 1001, true).length, 0);
  });
  await test('home capacity accounts for a day entry, window height and larger rows without shrinking text', () => {
    assert.equal(homeTaskCapacity(800, 100, 96, 140, 150, 64), 3);
    assert.equal(homeTaskCapacity(708, 100, 96, 212, 150, 64), 1);
    assert.equal(homeTaskCapacity(1200, 100, 96, 140, 150, 64), 5);
    assert.equal(homeTaskCapacity(400, 100, 96, 212, 150, 128), 1);
    assert.equal(homeTaskCapacity(800, 100, 96, 140, 150, 100), 2);
  });
  await test('all photo surfaces share six disjoint stages and final includes published', () => {
    const distribution = photoDistribution(photos); assert.deepEqual(distribution.map(g => g.value), read().photos.byStage);
    assert.equal(distribution.reduce((sum, g) => sum + g.value, 0), 8); assert.equal(photoStage(photos, 4).length, 2);
    assert.equal(photoStage(photos, 5)[0].status, PhotoStatus.RETOUCHED); assert.equal(photoStage(photos, 6)[0].status, PhotoStatus.ARCHIVED);
    assert.equal(portfolioStage(photos, 1).length, 2); assert.equal(portfolioStage(photos, 2)[0].status, PhotoStatus.PUBLISHED);
  });
  await test('ledger periods use local calendar boundaries, inclusive endpoints and reject invalid custom ranges', () => {
    const route = new LedgerRoute();
    assert.equal(ledgerRange(route, '2024-02-08').end, '2024-02-29');
    assert.equal(ledgerRange(route, '2026-12-31').end, '2026-12-31');
    route.range = 'year';
    assert.equal(ledgerRange(route, '2026-12-31').start, '2026-01-01');
    route.range = 'custom'; route.startDate = '2026-12-31'; route.endDate = '2027-01-01';
    assert.equal(ledgerRange(route, '2026-12-31').error, '');
    route.endDate = '2026-12-30'; assert.match(ledgerRange(route, '2026-12-31').error, /不能早于/);
    route.endDate = '2026-02-30'; assert.match(ledgerRange(route, '2026-12-31').error, /有效/);
    assert.equal(buildLedgerSummary(expenses, [read()], route, '2026-12-31').records.length, 0);
    route.range = 'all'; assert.equal(ledgerRange(route, 'invalid').error, '');
  });
  await test('ledger summary, classification, recorded-month chart and rows share the same project/date/category set', () => {
    const make = (id, projectId, date, category, amountCents) => Object.assign(new Expense(), { id, projectId, date, category, amountCents });
    const records = [make('first', 'p', '2026-01-01', '服装', 101), make('last', 'p', '2026-01-31', '摄影', 202), make('next', 'p', '2026-02-01', '服装', 303), make('other', 'other', '2026-01-11', '服装', 404), make('undated', 'other', '', '交通', 505), make('previous', 'p', '2025-12-31', '服装', 606)];
    const route = new LedgerRoute();
    const find = () => buildLedgerSummary(records, [], route, '2026-01-15');
    const agree = summary => {
      assert.equal(summary.totalCents, summary.records.reduce((sum, item) => sum + item.amountCents, 0));
      assert.equal(summary.totalCents, summary.categories.reduce((sum, item) => sum + item.amount, 0));
      assert.equal(summary.totalCents, Math.round(summary.months.reduce((sum, item) => sum + item.value, 0) * 100));
    };
    let summary = find(); assert.equal(summary.totalCents, 707); agree(summary);
    route.projectId = 'p'; summary = find(); assert.equal(summary.totalCents, 303); agree(summary);
    route.category = '服装'; summary = find(); assert.equal(summary.totalCents, 101); agree(summary);
    assert.deepEqual(summary.records.map(item => item.id), ['first']); assert.equal(summary.categories[0].percent, 100);
    route.category = ''; route.range = 'custom'; route.startDate = '2026-01-31'; route.endDate = '2026-02-01';
    summary = find(); assert.equal(summary.totalCents, 505); agree(summary);
    route.range = 'year'; route.projectId = ''; summary = find(); assert.equal(summary.totalCents, 1010); agree(summary);
    route.range = 'all'; summary = find(); assert.equal(summary.totalCents, 2121); agree(summary);
    assert.equal(summary.months.find(item => item.label === '未记录日期').value, 5.05);
    route.category = 'missing'; summary = find(); assert.equal(summary.totalCents, 0); assert.deepEqual(summary.categories, []);
    assert.equal(records.length, 6); assert.equal(records[0].date, '2026-01-01');
  });
  await test('ledger budget comparison covers only explicitly budgeted plans and never compares a month or category to lifetime budgets', () => {
    const make = (id, budgetConfigured, budgetCents) => Object.assign(new CosProject(), { id, budgetConfigured, budgetCents });
    const projects = [make('p', true, 100), make('zero', true, 0), make('unset', false, 0), make('unknown', undefined, 0)];
    const records = projects.map((project, i) => Object.assign(new Expense(), { projectId: project.id, amountCents: 20 + 10 * i, date: '2026-01-15' }));
    const plans = projects.map(p => buildPlanReadiness(p, [], [], [], [], [], records, [], '2026-01-15'));
    const route = new LedgerRoute(); const readLedger = () => buildLedgerSummary(records, plans, route, '2026-01-15');
    let summary = readLedger(); assert.equal(summary.canCompareBudget, false);
    route.range = 'all'; summary = readLedger();
    assert.equal(summary.totalCents, 140); assert.equal(summary.budgetCount, 2); assert.equal(summary.budgetCents, 100); assert.equal(summary.budgetSpentCents, 50); assert.equal(summary.canCompareBudget, true);
    route.category = '服装'; assert.equal(readLedger().canCompareBudget, false);
    route.category = ''; route.projectId = 'zero'; summary = readLedger();
    assert.equal(summary.budgetCount, 1); assert.equal(summary.budgetCents, 0); assert.equal(summary.canCompareBudget, true); assert.match(summary.budgetText, /0.00/);
    route.projectId = 'unknown'; summary = readLedger(); assert.equal(summary.canCompareBudget, false); assert.match(summary.budgetText, /历史预算未明确/);
    route.projectId = 'unset'; assert.match(readLedger().budgetText, /未设置预算/);
    route.offset = 350; route.chartZoom = 2; route.chartPan = 0.4;
    readLedger(); assert.equal(route.offset, 350); assert.equal(route.chartZoom, 2);
  });
  await test('unknown, unset and explicit zero budget have distinct labels', () => {
    assert.equal(budgetLabel(undefined, 0), '历史预算未明确'); assert.equal(budgetLabel(false, 0), '未设置预算'); assert.equal(budgetLabel(true, 0), '预算 ¥0.00');
  });
  await test('write failure never refreshes and is not committed', async () => {
    let refreshed = 0; const result = await executeOperation(async () => { throw new Error('disk full'); }, async () => { refreshed++; });
    assert.equal(result.status, 'failed'); assert.equal(result.detail, 'disk full'); assert.equal(refreshed, 0); assert.equal(operationCommitted(result), false);
  });
  await test('refresh failure preserves commit and reload never replays the write', async () => {
    let writes = 0, refreshes = 0; const refresh = async () => { refreshes++; if (refreshes === 1) throw new Error('read failed'); };
    const result = await executeOperation(async () => { writes++; }, refresh); assert.equal(result.status, 'savedNotRefreshed'); assert.equal(operationCommitted(result), true);
    await refresh(); assert.equal(writes, 1); assert.equal(refreshes, 2);
  });
  await test('successful operation writes before refreshing', async () => {
    const order = []; const result = await executeOperation(async () => { order.push('write'); }, async () => { order.push('refresh'); }); assert.equal(result.status, 'ok'); assert.deepEqual(order, ['write', 'refresh']);
  });
  const db = new SqliteAdapter();
  try {
    for (const match of fs.readFileSync(root + '/data/database/Schema.ets', 'utf8').matchAll(/`([^`]+)`/g)) await db.sql(match[1]);
    await db.sql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Legacy',1,1)");
    for (const [id, cents, configured] of [['zero',0,1], ['unset',0,0], ['unknown',0,null], ['positive',1234,1]]) {
      await db.sql("INSERT INTO projects(id,character_id,name,status,budget_cents,budget_configured,created_at,updated_at) VALUES(?,'c',?,'Preparing',?,?,1,1)", [id,id,cents,configured]);
    }
    await db.sql("INSERT INTO preparation_categories VALUES('waiting-category','positive','造型',0)");
    await db.sql("INSERT INTO preparation_tasks(id,project_id,category_id,label,done,due_date,waiting_on,waiting_until) VALUES('persist-wait','positive','waiting-category','等假发',1,'2026-10-01','快递','2026-10-10')");
    const { PreparationRepository } = require(root + '/data/repository/PreparationRepository.ets');
    const preparations = new PreparationRepository(db);
    await test('waiting fields persist through the actual preparation repository without losing completion', async () => {
      const saved = (await preparations.tasks()).find(task => task.id === 'persist-wait');
      assert.equal(saved.done, true); assert.equal(saved.waitingOn, '快递'); assert.equal(saved.waitingUntil, '2026-10-10');
      saved.waitingOn = '毛娘'; saved.waitingUntil = '2026-10-11'; await preparations.saveTask(saved);
      const updated = (await preparations.tasks()).find(task => task.id === 'persist-wait');
      assert.equal(updated.waitingOn, '毛娘'); assert.equal(updated.waitingUntil, '2026-10-11'); assert.equal(updated.done, true);
      updated.waitingUntil = 'bad date'; await assert.rejects(preparations.saveTask(updated), /等待日期/);
      assert.equal((await preparations.tasks()).find(task => task.id === 'persist-wait').waitingUntil, '2026-10-11');
    });
    await test('conditional preparation completion and undo update only the expected task value', async () => {
      const item = Object.assign(new PreparationTask(), { id: 'cas', projectId: 'positive', categoryId: 'waiting-category', label: '等道具', notes: '保留备注', dueDate: '2026-10-08', waitingOn: '快递', sortOrder: 8 });
      await preparations.saveTask(item);
      await preparations.setDone(item.id, true, item.projectId, false);
      const saved = (await preparations.tasks()).find(task => task.id === item.id);
      assert.equal(saved.done, true); assert.equal(saved.notes, item.notes); assert.equal(saved.waitingOn, item.waitingOn); assert.equal(saved.dueDate, item.dueDate); assert.equal(saved.sortOrder, 8);
      await assert.rejects(preparations.setDone(item.id, true, item.projectId, false), /已变更或不存在/);
      await assert.rejects(preparations.setDone(item.id, false, 'zero', true), /已变更或不存在/);
      db.failSql = 'UPDATE preparation_tasks';
      await assert.rejects(preparations.setDone(item.id, false, item.projectId, true), /injected/);
      db.failSql = ''; assert.equal((await preparations.tasks()).find(task => task.id === item.id).done, true);
      await preparations.setDone(item.id, false, item.projectId, true);
      assert.equal((await preparations.tasks()).find(task => task.id === item.id).done, false);
      await db.sql('DELETE FROM preparation_tasks WHERE id=?', [item.id]);
      await assert.rejects(preparations.setDone(item.id, false, item.projectId, true), /已变更或不存在/);
    });
    await test('actual home completion and undo preserve failed writes and distinguish saved-but-not-refreshed snapshots', async () => {
      const state = new AppState(); state.settings.haptic = false;
      state.projects = [Object.assign(new CosProject(), { id: 'positive' })]; state.preparationRepo = preparations;
      const item = Object.assign(new PreparationTask(), { id: 'home-write', projectId: 'positive', categoryId: 'waiting-category', label: '带道具' });
      await preparations.saveTask(item); await state.refresh(['preparationTasks']);
      db.failSql = 'UPDATE preparation_tasks';
      assert.equal((await state.completeHomePreparation(item.id, item.projectId)).status, 'failed');
      assert.equal(state.preparationUndos.length, 0); assert.equal(state.preparationTasks.find(task => task.id === item.id).done, false);
      db.failSql = '';
      const refresh = state.refresh.bind(state); state.refresh = async () => { throw new Error('read failure'); };
      assert.equal((await state.completeHomePreparation(item.id, item.projectId)).status, 'savedNotRefreshed');
      assert.equal((await preparations.tasks()).find(task => task.id === item.id).done, true);
      assert.equal(state.preparationTasks.find(task => task.id === item.id).done, false);
      const token = state.preparationUndos[0]; assert.equal(token.taskId, item.id);
      assert.equal((await state.undoHomePreparation(token.id)).status, 'failed'); assert.equal(state.preparationUndos.length, 1);
      state.refresh = refresh; assert.equal(await state.reloadRecords(), true);
      state.busy = true; assert.equal((await state.undoHomePreparation(token.id)).status, 'failed'); assert.equal(state.preparationUndos.length, 1); state.busy = false;
      db.failSql = 'UPDATE preparation_tasks';
      assert.equal((await state.undoHomePreparation(token.id)).status, 'failed'); assert.equal(state.preparationUndos.length, 1);
      db.failSql = ''; assert.equal((await state.undoHomePreparation(token.id)).status, 'ok');
      assert.equal(state.preparationUndos.length, 0); assert.equal((await preparations.tasks()).find(task => task.id === item.id).done, false);
      assert.equal((await state.completeHomePreparation(item.id, item.projectId)).status, 'ok');
      const changedToken = state.preparationUndos[0]; await preparations.setDone(item.id, false);
      assert.equal((await state.undoHomePreparation(changedToken.id)).status, 'failed'); assert.equal(state.preparationUndos.length, 0);
      await state.refresh(['preparationTasks']); await state.completeHomePreparation(item.id, item.projectId);
      state.preparationUndos[0].expiresAt = Date.now() - 1;
      assert.equal((await state.undoHomePreparation(state.preparationUndos[0].id)).status, 'failed');
      assert.equal((await preparations.tasks()).find(task => task.id === item.id).done, true);
      await db.sql('DELETE FROM preparation_tasks WHERE id=?', [item.id]);
    });
    await test('a project draft uses its persisted IDs in the real transaction and is recognized after an interrupted cleanup', async () => {
      const { CosProjectRepository, CharacterRepository, DiaryEntryRepository } = require(root + '/data/repository/Repositories.ets');
      const state = new AppState();
      state.projectRepo = new CosProjectRepository(db); state.characterRepo = new CharacterRepository(db); state.diaryRepo = new DiaryEntryRepository(db); state.preparationRepo = preparations;
      let text = ''; const store = new FormDraftStore({ read: async () => text, write: async value => { text = value; } });
      const draft = EditDraft.make(state, 'project'); const session = new FormSession(draft, store); await session.initialize(state);
      draft.name = '恢复验证计划'; draft.characterName = '恢复验证角色'; await session.flush();
      const savedDraft = (await store.load(formDraftKey(draft))).payload; const id = draft.creationId, characterId = draft.creationCharacterId;
      assert.equal(await draft.save(state), true); assert.equal(draft.id, id);
      assert.equal((await db.sql('SELECT character_id FROM projects WHERE id=?', [id])).rows[0][0], characterId);
      assert.equal((await db.sql('SELECT name FROM characters WHERE id=?', [characterId])).rows[0][0], '恢复验证角色');
      // Simulate process termination after the transaction, before deleting its draft.
      const interrupted = EditDraft.fromJSON(savedDraft); assert.equal(interrupted.id, '');
      assert.equal(await interrupted.save(state), false);
      assert.equal((await db.sql('SELECT count(*) FROM projects WHERE id=?', [id])).rows[0][0], 1);
      const reopening = new FormSession(EditDraft.make(state, 'project'), store); await reopening.initialize(state);
      assert.equal(reopening.pendingRestore, undefined); assert.equal(reopening.error.includes('上次创建已保存'), true);
      await db.sql('DELETE FROM projects WHERE id=?', [id]); await db.sql('DELETE FROM characters WHERE id=?', [characterId]);
    });
    const { MetadataBackupRepository } = require(root + '/data/repository/MetadataBackupRepository.ets');
    const backup = new MetadataBackupRepository(db);
    const exported = await backup.exportMetadata();
    await test('current backup round trip preserves explicit zero, unset and unknown budgets', async () => {
      assert.equal(JSON.parse(exported).version, 6); await backup.restoreMetadata(exported);
      assert.deepEqual((await db.sql('SELECT id,budget_cents,budget_configured FROM projects ORDER BY id')).rows, [['positive',1234,1], ['unknown',0,null], ['unset',0,0], ['zero',0,1]]);
    });
    await test('v1, v2 and v3 backups infer positive budgets but preserve historical zero as unknown', async () => {
      for (const version of [1,2,3]) {
        const doc = JSON.parse(exported); doc.version = version; doc.tables = doc.tables.slice(0, version === 1 ? 10 : version === 2 ? 12 : 15);
        for (const row of doc.tables.find(t => t.name === 'preparation_tasks')?.rows || []) { delete row.waiting_on; delete row.waiting_until; }
        for (const row of doc.tables.find(t => t.name === 'projects').rows) delete row.budget_configured;
        await backup.restoreMetadata(JSON.stringify(doc));
        assert.deepEqual((await db.sql('SELECT id,budget_configured FROM projects ORDER BY id')).rows, [['positive',1], ['unknown',null], ['unset',null], ['zero',null]]);
      }
    });
    await test('v4 backup retains budget flags and defaults the new entries table to empty', async () => {
      const doc = JSON.parse(exported); doc.version = 4; doc.tables = doc.tables.slice(0,15); for (const row of doc.tables.find(t => t.name === 'preparation_tasks').rows) { delete row.waiting_on; delete row.waiting_until; } await backup.restoreMetadata(JSON.stringify(doc));
      assert.deepEqual((await db.sql('SELECT id,budget_configured FROM projects ORDER BY id')).rows, [['positive',1], ['unknown',null], ['unset',0], ['zero',1]]);
      assert.equal((await db.sql('SELECT count(*) FROM entries')).rows[0][0], 0);
    });
    await test('v6 waiting fields round trip; v5 defaults them without changing task history', async () => {
      await backup.restoreMetadata(exported); const current = (await preparations.tasks()).find(task => task.id === 'persist-wait');
      assert.equal(current.waitingOn, '毛娘'); assert.equal(current.waitingUntil, '2026-10-11');
      const old = JSON.parse(exported); old.version = 5;
      for (const row of old.tables.find(table => table.name === 'preparation_tasks').rows) { delete row.waiting_on; delete row.waiting_until; }
      await backup.restoreMetadata(JSON.stringify(old)); const restored = (await preparations.tasks()).find(task => task.id === 'persist-wait');
      assert.equal(restored.waitingOn, ''); assert.equal(restored.waitingUntil, ''); assert.equal(restored.done, true); assert.equal(restored.dueDate, '2026-10-01');
      const bad = JSON.parse(exported); bad.tables.find(table => table.name === 'preparation_tasks').rows[0].waiting_until = '2026-02-30';
      await assert.rejects(backup.restoreMetadata(JSON.stringify(bad)), /无效日期/);
      assert.equal((await preparations.tasks()).find(task => task.id === 'persist-wait').waitingUntil, '');
    });
    await test('invalid budget flags are rejected before replacement', async () => {
      const doc = JSON.parse(exported); doc.tables.find(t => t.name === 'projects').rows[0].budget_configured = 2;
      await assert.rejects(backup.restoreMetadata(JSON.stringify(doc)), /预算标记/);
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
    });
    await test('backup foreign key failure rolls replacement back', async () => {
      const doc = JSON.parse(exported); doc.tables.find(t => t.name === 'projects').rows[0].character_id = 'missing';
      await assert.rejects(backup.restoreMetadata(JSON.stringify(doc)), /FOREIGN KEY/);
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
      assert.equal((await db.sql('SELECT name FROM characters')).rows[0][0], 'Legacy');
    });
    const { EntryRepository } = require(root + '/data/repository/EntryRepository.ets');
    const { entryFromText, validateEntry, CollectedEntry } = require(root + '/model/CollectedEntry.ets');
    const entries = new EntryRepository(db);
    await test('capture needs no title, type selection or owner', async () => {
      const link = entryFromText('https://example.com/ticket'); assert.equal(link.title,''); assert.equal(link.kind,'link'); assert.equal(link.scopeKind,'global'); validateEntry(link);
      const note = entryFromText('下一次试试这个造型'); assert.equal(note.kind,'note'); assert.equal(note.scopeId,''); await entries.save(note);
      assert.equal((await entries.list())[0].text, note.text);
    });
    await test('entry assignment rejects missing owners and preserves source', async () => {
      const note = (await entries.list())[0]; note.scopeKind = 'project'; note.scopeId = 'missing'; await assert.rejects(entries.save(note), /已不存在/);
      assert.equal((await entries.list())[0].scopeKind, 'global');
    });
    await test('task conversion commits the category, task and removal together once', async () => {
      const note = (await entries.list())[0]; await entries.convert(note,'task','project','zero','','2026-10-08');
      assert.equal((await db.sql("SELECT count(*) FROM preparation_tasks WHERE project_id='zero'")).rows[0][0],1); assert.equal((await entries.list()).length,0);
      await assert.rejects(entries.convert(note,'task','project','zero','','2026-10-08'), /已变化/);
      assert.equal((await db.sql("SELECT count(*) FROM preparation_tasks WHERE project_id='zero'")).rows[0][0],1);
    });
    await test('conversion failure leaves the original entry intact', async () => {
      const note = entryFromText('门票'); await entries.save(note); db.failSql = 'INSERT INTO expenses';
      await assert.rejects(entries.convert(note,'expense','project','zero','123.45','2026-10-08'), /injected/); db.failSql = '';
      assert.equal((await entries.list())[0].id,note.id); assert.equal((await db.sql('SELECT count(*) FROM expenses')).rows[0][0],0);
      await entries.convert(note,'expense','project','zero','123.45','2026-10-08'); assert.equal((await db.sql('SELECT amount_cents FROM expenses')).rows[0][0],12345);
    });
    await test('reference conversion preserves media paths and excludes it from photos', async () => {
      const entry = Object.assign(new CollectedEntry(), { kind:'image', localPath:'/sandbox/original', thumbnailPath:'/sandbox/thumb' }); await entries.save(entry);
      await entries.convert(entry,'reference','character','c','','2026-10-08');
      assert.deepEqual((await db.sql('SELECT character_id,local_path,thumbnail_path FROM reference_images')).rows[0],['c','/sandbox/original','/sandbox/thumb']);
      assert.equal((await db.sql('SELECT count(*) FROM photos')).rows[0][0],0);
    });
    await test('entry metadata restore strips foreign paths and rejects dangling scope', async () => {
      const entry = Object.assign(new CollectedEntry(), { kind:'image', scopeKind:'project', scopeId:'zero', localPath:'/sandbox/existing', thumbnailPath:'/sandbox/existing-thumb' }); await entries.save(entry);
      const saved = await backup.exportMetadata(); const doc = JSON.parse(saved);
      doc.tables.find(t => t.name === 'entries').rows.push({id:'foreign',kind:'image',scope_kind:'global',scope_id:'',title:'',url:'',text:'',local_path:'/etc/passwd',thumbnail_path:'/etc/passwd',pinned:0,created_at:1});
      await backup.restoreMetadata(JSON.stringify(doc)); const current = await entries.list(); assert.equal(current.find(e=>e.id==='foreign').localPath,''); assert.equal(current.find(e=>e.id===entry.id).localPath,entry.localPath);
      doc.tables.find(t => t.name === 'entries').rows[0].scope_id='missing'; await assert.rejects(backup.restoreMetadata(JSON.stringify(doc)), /不存在的对象/);
      assert.equal((await entries.list()).length,2);
      await db.sql("DELETE FROM projects WHERE id='zero'"); assert.equal((await entries.list()).find(e=>e.id===entry.id).scopeKind,'global');
    });
  } finally { db.close(); }
  console.log(`${count} model and backup checks passed`);
})().catch(error => { console.error(error); process.exitCode = 1; });
