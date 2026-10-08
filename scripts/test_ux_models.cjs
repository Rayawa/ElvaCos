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
let backupControl = {};
let backupFileControl = {};
let metadataExportTime = 0;
let failExportTime = false;
let mediaControl = {};
let shareControl = {};

Module._load = function (id, parent, isMain) {
  if (parent?.filename.endsWith('/common/ShareService.ets')) {
    if (id === './SystemCapability') return { SystemCapability: { share: () => shareControl.available !== false } };
    if (id === '@kit.ArkData') return { uniformTypeDescriptor: { UniformDataType: { PLAIN_TEXT: 'text/plain' } } };
    if (id === '@kit.ShareKit') return { systemShare: { SharedData: class { constructor(value) { Object.assign(this, value); } }, ShareController: class { constructor(value) { this.value = value; } async show() { if (shareControl.fail) throw new Error('share rejected'); shareControl.data = this.value; } }, SharePreviewMode: { DETAIL: 'detail' } } };
  }
  if (parent?.filename.endsWith('/data/media/MediaRepository.ets')) {
    if (id === '@kit.MediaLibraryKit') return { photoAccessHelper: { PhotoViewPicker: class { async select(options) { mediaControl.pickerOptions = options; return { photoUris: mediaControl.selection || [] }; } }, PhotoViewMIMETypes: { IMAGE_TYPE: 'image' } } };
    if (id === '@kit.CoreFileKit') return { fileUri: { getUriFromPath: path => 'file://' + path }, fileIo: {
      OpenMode: { READ_ONLY: 1, CREATE: 2, WRITE_ONLY: 4, TRUNC: 8 },
      access: async path => { if (mediaControl.denied?.includes(path)) throw new Error('access denied'); return mediaControl.files.has(path); },
      mkdir: async path => mediaControl.files.add(path), open: async (path, mode) => { if (mode === 1 && !mediaControl.files.has(path)) throw new Error('file missing'); mediaControl.files.add(path); return { fd: path }; },
      close: async () => {}, stat: async () => ({ size: 10 }), copyFile: async (fd, path) => mediaControl.files.add(path),
      write: async (fd, packed) => mediaControl.shortWrite ? packed.byteLength - 1 : packed.byteLength,
      unlink: async path => { mediaControl.removed.push(path); mediaControl.files.delete(path); }, listFile: async dir => [...mediaControl.files].filter(path => path.startsWith(dir + '/')).map(path => path.slice(dir.length + 1))
    } };
    if (id === '@kit.ImageKit') return { image: {
      createImageSource: () => ({ getImageInfo: async () => ({ size: { width: 1000, height: 2000 } }), createPixelMap: async options => { mediaControl.desired = options.desiredSize; return { release: () => {} }; }, release: () => {} }),
      createImagePacker: () => ({ packToData: async () => new ArrayBuffer(10), release: () => {} })
    } };
  }
  if (id === '@kit.ArkTS') return { util: { generateRandomUUID: () => crypto.randomUUID(), TextEncoder: { create: () => ({ encodeInto: value => new Uint8Array(Buffer.from(value, 'utf8')) }) }, TextDecoder: class { decodeToString(bytes) { return Buffer.from(bytes).toString('utf8'); } } } };
  if (id === '@kit.CoreFileKit' && parent?.filename.endsWith('/common/BackupService.ets')) return { fileIo: { OpenMode: { READ_ONLY: 1, WRITE_ONLY: 2, TRUNC: 4 }, open: async () => ({ fd: 1 }), close: async fd => backupFileControl.close?.(fd), write: async (fd, buffer) => backupFileControl.write(fd, buffer), read: async (fd, buffer, options) => backupFileControl.read(fd, buffer, options), stat: async () => ({ size: backupFileControl.bytes?.length || 0 }) }, picker: { DocumentViewPicker: class { async save() { return backupFileControl.save?.() || []; } async select() { return backupFileControl.select?.() || []; } } } };
  if (id === '@kit.ArkData') return { relationalStore: { RdbPredicates: class {
    constructor(table) { this.table = table; this.terms = []; }
    equalTo(key, value) { this.terms.push([key, value]); return this; }
  } } };
  if (id === 'BuildProfile') return { DEBUG: false };
  if (parent?.filename.endsWith('/model/ApplicationState.ets')) {
    if (id === '../common/storage') return { setLastMetadataExport: async value => { if (failExportTime) throw new Error('preferences unavailable'); metadataExportTime = value; }, getLastMetadataExport: async () => metadataExportTime };
    if (id === '../common/formDrafts') return { formDraftStore: { clear: async () => {} } };
    const nativeService = ['DeviceCalendarService', 'EventReminderService', 'SettingsService', 'AccountService', 'HapticService', 'GripService', 'BackupService', 'MediaRepository', 'DemoDataRepository'].find(name => id.endsWith('/' + name));
    if (nativeService === 'BackupService') return { BackupService: class { async prepareRestore() { return backupControl.prepare?.(); } async restoreMetadata(input) { return backupControl.restore(input); } async export() { return backupControl.export?.() || false; } } };
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
  await test('draft snapshots and initial FormSession work when observed fields are non-enumerable accessors', () => {
    const observed = global.ObservedV2;
    try {
      global.ObservedV2 = Original => class extends Original {
        constructor(...args) {
          super(...args);
          for (const key of Object.keys(this)) {
            let current = this[key];
            Object.defineProperty(this, key, { get: () => current, set: value => { current = value; }, enumerable: false, configurable: true });
          }
        }
      };
      const observedModule = new Module(root + '/model/EditDraft.ets', module);
      observedModule.filename = root + '/model/EditDraft.ets';
      require.extensions['.ets'](observedModule, observedModule.filename);
      const NativeDraft = observedModule.exports.EditDraft, draft = new NativeDraft();
      assert.equal(Object.keys(draft).length, 0);
      const session = new FormSession(draft, new FormDraftStore({ read: async () => '', write: async () => {} }));
      assert.equal(session.dirty, false);
      draft.kind = 'shot'; draft.parentId = 'plan'; draft.name = '特写'; draft.referenceId = 'reference'; draft.preparationKeys = ['test'];
      const snapshot = JSON.parse(draft.serialize());
      assert.equal(snapshot.creationId, draft.creationId); assert.equal(snapshot.creationCharacterId, draft.creationCharacterId);
      assert.equal(snapshot.name, '特写'); assert.equal(snapshot.referenceId, 'reference'); assert.deepEqual(snapshot.preparationKeys, ['test']);
      const restored = NativeDraft.fromJSON(draft.serialize());
      assert.equal(restored.fingerprint(), draft.fingerprint()); assert.equal(session.dirty, true);
    } finally { global.ObservedV2 = observed; }
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
    assert.equal(distribution.reduce((sum, g) => sum + g.value, 0), 8); assert.equal(photoStage(photos, 5).length, 2);
    assert.equal(photoStage(photos, 4)[0].status, PhotoStatus.RETOUCHED); assert.equal(photoStage(photos, 6)[0].status, PhotoStatus.ARCHIVED);
    assert.equal(portfolioStage(photos, 5).length, 2); assert.equal(portfolioStage(photos, 7)[0].status, PhotoStatus.PUBLISHED);
  });
  await test('album uses shared readiness counts and effective plan dates, including completed and undated plans', () => {
    const { buildAlbumSummary } = require(root + '/model/AlbumSummary.ets');
    const p2 = Object.assign(new CosProject(), { id: 'album-completed', name: '已完成', eventId: '', targetDate: '', status: ProjectStatus.COMPLETED });
    const scoped = photos.map(photo => Object.assign(new PhotoAsset(), photo, { projectId: project.id }));
    const second = Object.assign(new PhotoAsset(), { id: 'second-final', projectId: p2.id, status: PhotoStatus.FINAL, createdAt: Date.now() });
    const readiness = [buildPlanReadiness(project, [], [], [], [], scoped, [], [event], '2026-12-31'), buildPlanReadiness(p2, [], [], [], [], [second], [], [], '2026-12-31')];
    const summary = buildAlbumSummary(readiness, [p2, project], [event], [...scoped, second]);
    assert.equal(summary.total, 9); assert.deepEqual(summary.counts, [2, 1, 1, 1, 3, 1]);
    const first = summary.plans[0]; assert.equal(first.id, project.id); assert.equal(first.date, event.date); assert.deepEqual(first.counts, readiness[0].photos.byStage);
    assert.equal(first.cover.status, PhotoStatus.FINAL); assert.equal(summary.plans[1].date, '');
    first.counts[0] = 100; assert.equal(readiness[0].photos.byStage[0], 2);
    const state = new AppState(); state.projects = [project, p2]; state.events = [event]; state.photos = [...scoped, second];
    assert.deepEqual(state.albumSummary.counts, summary.counts);
  });
  await test('album queue, plan scope and portfolio all query the same photo states and one vocabulary', () => {
    const { PhotoCollectionRoute, selectPhotoCollection } = require(root + '/model/PhotoCollection.ets');
    const { PHOTO_FILTER_LABELS, PHOTO_EDIT_STATUSES, photoStatusLabel } = require(root + '/model/PhotoStages.ets');
    const input = photos.map((photo, index) => Object.assign(new PhotoAsset(), photo, { id: 'album-' + index, projectId: index % 2 ? 'two' : 'one' }));
    const route = new PhotoCollectionRoute();
    assert.equal(selectPhotoCollection(input, route).length, 8);
    route.queue = true; assert.equal(selectPhotoCollection(input, route).length, 3);
    route.setFilter(3); assert.equal(selectPhotoCollection(input, route)[0].status, PhotoStatus.WAITING);
    route.setPlan('one'); assert.equal(selectPhotoCollection(input, route).length, 0);
    route.queue = false; route.setPlan(''); route.setPortfolio(true); assert.equal(selectPhotoCollection(input, route).length, 2);
    route.setFilter(7); assert.deepEqual(selectPhotoCollection(input, route).map(photo => photo.status), [PhotoStatus.PUBLISHED]);
    assert.deepEqual(PHOTO_FILTER_LABELS, ['全部', '待选', '已选', '待修', '已修', '成片', '归档', '已发布']);
    assert.equal(new Set(PHOTO_EDIT_STATUSES.map(photoStatusLabel)).size, 7);
    assert.equal(photoStatusLabel(PhotoStatus.IMPORTED), photoStatusLabel(PhotoStatus.RAW));
  });
  await test('photo batch freezes its actual selection, preserves it on failure, clears on committed success and explains filter changes', () => {
    const { PhotoCollectionRoute } = require(root + '/model/PhotoCollection.ets');
    const input = photos.map((photo, index) => Object.assign(new PhotoAsset(), photo, { id: 'batch-' + index, projectId: project.id }));
    const route = new PhotoCollectionRoute(project.id); route.selecting = true; route.targetStatus = PhotoStatus.WAITING; route.setFilter(1); route.selectAll(input);
    assert.deepEqual(route.selectedIds, ['batch-0', 'batch-1']); const submitted = route.begin(input); assert.deepEqual(submitted, route.selectedIds);
    submitted.pop(); route.setFilter(3); route.toggle('batch-0', input); route.selectAll([]);
    assert.equal(route.filter, 1); assert.equal(route.selectedIds.length, 2);
    route.finish(false); assert.deepEqual(route.selectedIds, ['batch-0', 'batch-1']); assert.equal(route.selecting, true);
    route.begin(input); route.finish(true); assert.deepEqual(route.selectedIds, []); assert.equal(route.filter, 1); assert.equal(route.selecting, false); assert.equal(route.targetStatus, PhotoStatus.WAITING);
    route.selecting = true; route.selectAll(input); route.setFilter(3); assert.deepEqual(route.selectedIds, []); assert.match(route.feedback, /已清空/);
    route.selectAll(input); assert.equal(route.selectedIds.length, 1); route.setPlan('different'); assert.deepEqual(route.selectedIds, []);
  });
  await test('album mode and photo viewer retain separate filters, collection offsets and source thumbnail identities', () => {
    const { AlbumRoute } = require(root + '/model/AlbumRoute.ets');
    const { PhotoViewerRoute, returnToPhotoCollection } = require(root + '/model/PhotoCollection.ets');
    const input = photos.map((photo, index) => Object.assign(new PhotoAsset(), photo, { id: 'return-' + index, projectId: project.id }));
    const route = new AlbumRoute(project.id); route.groupOffset = 450; route.byPlan.offset = 820; route.byPlan.setFilter(1); route.byPlan.offset = 820;
    const viewer = new PhotoViewerRoute(input[0].id, 'album', route.byPlan, input);
    assert.equal(viewer.context, route.byPlan); assert.equal(route.byPlan.anchorId, input[0].id); assert.deepEqual(viewer.visibleIds, ['return-0', 'return-1']);
    returnToPhotoCollection(viewer, input); assert.equal(route.byPlan.offset, 820); assert.equal(route.byPlan.filter, 1); assert.equal(route.byPlan.restoreVersion, 1);
    route.byPlan.selecting = true; route.byPlan.selectAll(input); route.showMode('queue'); assert.match(route.queue.feedback, /已清空/); assert.deepEqual(route.byPlan.selectedIds, []);
    route.queue.setFilter(3); route.queue.offset = 600; route.showMode('byPlan'); assert.equal(route.collection.offset, 820); assert.equal(route.collection.filter, 1); assert.equal(route.groupOffset, 450);
    input[0].status = PhotoStatus.FINAL; returnToPhotoCollection(viewer, input); assert.match(route.byPlan.feedback, /离开当前筛选/); assert.equal(route.byPlan.offset, 820);
  });
  await test('album removes only a deleted plan scope while preserving valid queue filters and restoring a reachable collection', () => {
    const { AlbumRoute } = require(root + '/model/AlbumRoute.ets');
    const route = new AlbumRoute('gone'); route.byPlan.filter = 5; route.byPlan.selectedIds = ['lost-photo'];
    route.queue.planId = project.id; route.queue.filter = 3; route.queue.offset = 300;
    route.reconcile([project], photos);
    assert.equal(route.byPlan.planId, ''); assert.equal(route.byPlan.filter, 5); assert.deepEqual(route.byPlan.selectedIds, []); assert.match(route.byPlan.feedback, /已不存在/);
    assert.equal(route.queue.planId, project.id); assert.equal(route.queue.filter, 3); assert.equal(route.queue.offset, 300);
    route.reconcile([project], photos, project.id); assert.equal(route.queue.planId, ''); assert.equal(route.queue.filter, 3);
  });
  function workFixture() {
    const state = new AppState();
    state.characters = [Object.assign(new entities.Character(), { id: 'role', name: '角色', workName: '作品', cover: '/local/role-thumb', favorite: true }), Object.assign(new entities.Character(), { id: 'other', name: '同名角色', favorite: false, status: 'Wishlist' })];
    state.variants = [Object.assign(new entities.CharacterVariant(), { id: 'version', characterId: 'role', name: '冬装' })];
    state.events = [Object.assign(new CosEvent(), { id: 'scene', name: '漫展', date: '2026-10-01' })];
    state.projects = [Object.assign(new CosProject(), { id: 'finished', characterId: 'role', variantId: 'version', eventId: 'scene', name: '登场', status: ProjectStatus.COMPLETED, updatedAt: 9 }), Object.assign(new CosProject(), { id: 'future', characterId: 'role', targetDate: '2026-12-01', updatedAt: 9999999 })];
    state.photos = [
      Object.assign(new PhotoAsset(), { id: 'final', projectId: 'finished', status: PhotoStatus.FINAL, thumbnailPath: '/local/final', createdAt: 10 }),
      Object.assign(new PhotoAsset(), { id: 'published', projectId: 'finished', status: PhotoStatus.PUBLISHED, thumbnailPath: '/local/published', createdAt: 20 }),
      Object.assign(new PhotoAsset(), { id: 'archive', projectId: 'finished', status: PhotoStatus.ARCHIVED, thumbnailPath: '/local/archive', createdAt: 900 }),
      Object.assign(new PhotoAsset(), { id: 'raw', projectId: 'finished', status: PhotoStatus.RAW, thumbnailPath: '/local/raw', createdAt: 999 }),
      Object.assign(new PhotoAsset(), { id: 'future-final', projectId: 'future', status: PhotoStatus.FINAL, thumbnailPath: '/local/future', createdAt: 9999 })];
    state.references = [Object.assign(new (require(root + '/model/Planning.ets').ReferenceImage)(), { id: 'ref', characterId: 'role', projectId: 'finished', thumbnailPath: '/local/reference' })];
    state.expenses = [Object.assign(new Expense(), { projectId: 'finished', amountCents: 12345 }), Object.assign(new Expense(), { projectId: 'future', amountCents: 1000 })];
    state.assets = [Object.assign(new Asset(), { id: 'wig', priceCents: 50000, status: AssetStatus.REPAIR })]; state.links = [Object.assign(new ProjectAsset(), { assetId: 'wig', projectId: 'finished' })];
    const { TeamMember } = require(root + '/model/Planning.ets');
    state.team = [Object.assign(new TeamMember(), { id: 'credit', projectId: 'finished', name: '伙伴', role: '摄影' }), Object.assign(new TeamMember(), { id: 'hidden', projectId: 'future', name: '他人', role: '摄影' })];
    return state;
  }
  await test('work cards use shared final, money and equipment counts with real scoped credits and covers', () => {
    const state = workFixture(), card = state.projectWork('finished'), summary = state.readiness('finished');
    assert.equal(card.value.schemaVersion, 2); assert.equal(card.value.finalCount, summary.photos.byStage[4]); assert.equal(card.value.finalCount, 2);
    assert.equal(card.value.spentCents, summary.money.spentCents); assert.equal(card.value.spentCents, 12345);
    assert.equal(card.value.reusedEquipmentCount, summary.equipment.total); assert.equal(card.value.equipmentValueCents, 50000);
    assert.equal(card.value.variant, '冬装'); assert.equal(card.value.event, '漫展'); assert.equal(card.value.date, '2026-10-01'); assert.equal(card.value.dateFromEvent, true);
    assert.deepEqual(card.value.credits, ['摄影 · 伙伴']); assert.equal(card.value.coverPhotoId, 'published'); assert.equal(card.coverPath, '/local/published');
    assert.equal(card.value.characterId, 'role'); assert.equal(state.references.length, 1); assert.equal(state.photos.length, 5);
    state.projects[0].targetDate = '2026-09-30'; assert.equal(state.projectWork('finished').value.date, '2026-09-30'); assert.equal(state.projectWork('finished').value.dateFromEvent, false);
    state.photos = state.photos.filter(photo => !['final', 'published'].includes(photo.id)); const empty = state.projectWork('finished');
    assert.equal(empty.value.finalCount, 0); assert.equal(empty.value.coverPhotoId, ''); assert.equal(empty.coverPath, '/local/role-thumb'); assert.match(empty.coverLabel, /非本场成片/);
    state.characters[0].cover = ''; assert.equal(state.projectWork('finished').coverPath, '');
  });
  await test('history and recent work use actual plan dates and completed status, never import or update time', () => {
    const { workHistory, recentWork } = require(root + '/model/ProjectWork.ets'), state = workFixture();
    state.projects.push(Object.assign(new CosProject(), { id: 'undated', characterId: 'role', status: ProjectStatus.ARCHIVED, updatedAt: 999999999 }));
    assert.deepEqual(workHistory(state.workCards).map(work => work.value.projectId), ['future', 'finished', 'undated']);
    assert.equal(recentWork(state.workCards, '2026-10-08').value.projectId, 'finished');
    state.projects[1].targetDate = '2026-10-07'; assert.equal(recentWork(state.workCards, '2026-10-08').value.projectId, 'future');
    state.projects[1].targetDate = ''; const unknown = state.projectWork('future'); assert.equal(unknown.value.date, '');
    state.projects = state.projects.filter(project => project.id === 'future'); state.photos = []; assert.equal(recentWork(state.workCards, '2026-10-08'), undefined);
    state.projects[0].status = ProjectStatus.COMPLETED; assert.equal(recentWork(state.workCards, '2026-10-08').value.projectId, 'future'); assert.equal(state.projectWork('missing'), undefined);
  });
  await test('character library searches and favorites use one flag and scoped versions and all plan history', () => {
    const { filterCharacters } = require(root + '/model/CharacterLibrary.ets'), state = workFixture(), route = new PlanListRoute();
    const summary = state.characterSummary('role'); assert.deepEqual(summary.variants, ['冬装']); assert.equal(summary.planCount, 2); assert.equal(state.characterSummary('other').planCount, 0);
    route.favoriteOnly = true; assert.deepEqual(filterCharacters(state.characters, route).map(character => character.id), ['role']);
    route.query = '作品'; assert.deepEqual(filterCharacters(state.characters, route).map(character => character.id), ['role']);
    route.query = '同名'; assert.deepEqual(filterCharacters(state.characters, route), []); route.favoriteOnly = false; assert.equal(filterCharacters(state.characters, route)[0].id, 'other');
    assert.equal(state.characters[1].status, 'Wishlist'); assert.equal(state.characters[1].favorite, false);
  });
  await test('character route preserves sections, offsets and version context; drafts reject foreign or deleted versions', () => {
    const { CharacterRoute } = require(root + '/model/CharacterRoute.ets'), state = workFixture(), route = new CharacterRoute('role', 'version');
    route.section = 1; route.offsets[1] = 600; route.restoreVersion++; route.library = new PlanListRoute(); route.library.query = '作品'; route.library.favoriteOnly = true; route.library.anchorId = 'role'; route.library.offsets[0] = 900; route.project = new (require(root + '/model/ProjectRoute.ets').ProjectRoute)('p', 0); route.project.offsets[0] = 700; route.restoreSource(); assert.equal(route.library.restoreVersion, 1); assert.equal(route.project.restoreVersion, 1); assert.equal(route.library.query, '作品'); assert.equal(route.library.favoriteOnly, true); assert.equal(route.library.offsets[0], 900); assert.equal(route.project.offsets[0], 700); route.restoreSource(true); assert.equal(route.library.anchorId, ''); assert.equal(route.variantId, 'version'); assert.equal(route.section, 1); assert.equal(route.offsets[1], 600);
    const draft = EditDraft.make(state, 'project', '', route.id, route.variantId); assert.equal(draft.characterId, 'role'); assert.equal(draft.variantId, 'version'); assert.equal(draft.advanced, true); assert.deepEqual(draft.issues(state), []);
    const restored = EditDraft.fromJSON(draft.serialize()); assert.equal(restored.variantId, 'version');
    state.variants[0].characterId = 'other'; assert.ok(draft.issues(state).some(issue => issue.field === 'variantId'));
    state.variants = []; assert.ok(draft.issues(state).some(issue => issue.field === 'variantId'));
    const invalid = EditDraft.make(state, 'project', '', 'role', 'gone'); assert.equal(invalid.variantId, 'gone'); assert.ok(invalid.issues(state).some(issue => issue.field === 'variantId'));
  });
  await test('structured sharing reuses the work card payload, excludes local paths and reports missing context or rejected native share', async () => {
    const { ShareService } = require(root + '/common/ShareService.ets'), { projectShareText } = require(root + '/model/ProjectWork.ets'), state = workFixture();
    const card = state.projectWork('finished'); assert.equal(ShareService.object(card), card.value); const text = projectShareText(card.value);
    assert.match(text, /冬装/); assert.match(text, /摄影 · 伙伴/); assert.match(text, /123.45/); assert.match(text, /未计入支出/);
    state.context = {}; shareControl = {}; assert.equal(await state.shareProject('finished'), true);
    assert.deepEqual(JSON.parse(shareControl.data.extraData.payload), card.value); assert.equal(shareControl.data.content, text); assert.equal(shareControl.data.extraData.schemaVersion, 2);
    assert.equal(shareControl.data.extraData.payload.includes('/local/'), false); assert.equal(shareControl.data.content.includes('/local/'), false);
    shareControl.fail = true; assert.equal(await state.shareProject('finished'), false); assert.match(state.error, /share rejected/); assert.equal(state.staleScopes.length, 0);
    shareControl.available = false; assert.equal(await state.shareProject('finished'), false); assert.match(state.error, /不支持系统分享/);
    shareControl = {}; state.context = undefined; assert.equal(await state.shareProject('finished'), false); assert.match(state.error, /尚未就绪/);
    state.context = {}; assert.equal(await state.shareProject('gone'), false); assert.match(state.error, /已不存在/);
  });
  await test('wardrobe composes search, type, status and exact location without inventing an empty location', () => {
    const { WardrobeRoute, wardrobeAssets, wardrobeLocations } = require(root + '/model/Wardrobe.ets');
    const route = new WardrobeRoute(); const data = [
      Object.assign(new Asset(), { id: 'a', name: 'Blue 假发', brand: '店铺', type: entities.AssetType.WIG, status: AssetStatus.ORDERED, location: ' 衣柜上层 ' }),
      Object.assign(new Asset(), { id: 'b', name: '蓝假发', type: entities.AssetType.WIG, status: AssetStatus.OWNED, location: '衣柜上层' }),
      Object.assign(new Asset(), { id: 'c', name: '鞋', type: entities.AssetType.SHOES, status: AssetStatus.LENT, location: '  ' }),
      Object.assign(new Asset(), { id: 'd', name: '道具', location: '未记录位置' })
    ];
    assert.deepEqual(wardrobeLocations(data), ['未记录位置', '衣柜上层']); route.query = 'blue'; route.type = entities.AssetType.WIG; route.status = AssetStatus.ORDERED; route.locationMode = 'named'; route.location = '衣柜上层';
    assert.deepEqual(wardrobeAssets(data, route).map(asset => asset.id), ['a']); assert.equal(data[0].status, AssetStatus.ORDERED); assert.equal(data[0].location, ' 衣柜上层 ');
    route.clear(); route.locationMode = 'unrecorded'; assert.deepEqual(wardrobeAssets(data, route).map(asset => asset.id), ['c']);
    route.locationMode = 'named'; route.location = '未记录位置'; assert.deepEqual(wardrobeAssets(data, route).map(asset => asset.id), ['d']);
    route.location = '已移走的位置'; route.offset = 900; route.anchorId = 'a'; assert.deepEqual(wardrobeAssets(data, route), []); assert.equal(route.filtered, true); route.changed(); assert.equal(route.offset, 0); assert.equal(route.anchorId, '');
    route.clear(); assert.equal(route.filtered, false); assert.equal(wardrobeAssets(data, route).length, 4);
  });
  await test('asset usage shares active plan semantics and counts exact packing and collection impact', () => {
    const { buildAssetUsage, assetUsesSegments, assetRemovalKey } = require(root + '/model/Wardrobe.ets');
    const a = Object.assign(new Asset(), { id: 'shared', status: AssetStatus.REPAIR, priceCents: 10000 });
    const plans = [Object.assign(new CosProject(), { id: 'live' }), Object.assign(new CosProject(), { id: 'done', status: ProjectStatus.COMPLETED }), Object.assign(new CosProject(), { id: 'archive', status: ProjectStatus.ARCHIVED })];
    const links = plans.map(plan => Object.assign(new ProjectAsset(), { projectId: plan.id, assetId: a.id }));
    const packing = plans.map(plan => Object.assign(new ChecklistItem(), { id: 'pack-' + plan.id, projectId: plan.id, assetId: a.id, done: true }));
    const entries = [{ id: 'note', scopeKind: 'asset', scopeId: a.id }];
    const readiness = plans.map(plan => buildPlanReadiness(plan, [], packing, [a], links, [], [], [], '2026-10-08'));
    const usage = buildAssetUsage(a.id, plans, links, packing, entries, readiness);
    assert.equal(usage.projects.length, 3); assert.deepEqual(usage.activeProjects.map(plan => plan.id), ['live']); assert.equal(usage.checklist.length, 3); assert.deepEqual(usage.entryIds, ['note']);
    assert.equal(readiness.every(plan => plan.equipment.available === 0 && plan.pack.packed === 1 && plan.prep.total === 0 && plan.money.spentCents === 0), true);
    assert.match(usage.removalMessage('假发'), /3 份计划关联/); assert.match(usage.removalMessage('假发'), /3 条打包项/); assert.match(usage.unlinkMessage(plans[0]), /1 条对应打包项/);
    assert.equal(usage.removalKey, assetRemovalKey(plans.map(plan => plan.id).reverse(), packing.map(item => item.id).reverse(), ['note']));
    assert.equal(assetUsesSegments(a, usage), true);
    const brief = buildAssetUsage(a.id, [plans[0]], [links[0]], [], [], [readiness[0]]); assert.equal(assetUsesSegments(a, brief), false); a.notes = '较长资料'; assert.equal(assetUsesSegments(a, brief), true);
  });
  await test('asset return routes restore wardrobe, plan, day and task contexts without changing their views', () => {
    const { AssetRoute } = require(root + '/model/AssetRoute.ets'), { WardrobeRoute } = require(root + '/model/Wardrobe.ets');
    const { ProjectRoute } = require(root + '/model/ProjectRoute.ets'), { EventRoute } = require(root + '/model/EventRoute.ets');
    const wardrobe = new WardrobeRoute(); Object.assign(wardrobe, { query: '假发', status: AssetStatus.REPAIR, offset: 800, anchorId: 'a' });
    const plan = new ProjectRoute('p', 2); plan.outing = true; plan.offsets[2] = 900; plan.expandedCategories = ['category'];
    const dayRoute = new EventRoute('event', true, 1); dayRoute.offsets[5] = 500;
    const tasksRoute = new TaskRoute('p'); tasksRoute.category = 'waiting'; tasksRoute.range = 'all'; tasksRoute.offset = 700;
    const route = new AssetRoute('a', 'wardrobe', '', 3); route.wardrobe = wardrobe; route.project = plan; route.event = dayRoute; route.tasks = tasksRoute; route.section = 1; route.offsets[1] = 400;
    route.restoreSource(); assert.equal(wardrobe.restoreVersion, 1); assert.equal(plan.restoreVersion, 1); assert.equal(dayRoute.restoreVersion, 1); assert.equal(tasksRoute.restoreVersion, 1);
    assert.equal(wardrobe.offset, 800); assert.equal(wardrobe.query, '假发'); assert.equal(wardrobe.status, AssetStatus.REPAIR); assert.equal(plan.section, 2); assert.equal(plan.outing, true); assert.equal(plan.offsets[2], 900);
    assert.equal(dayRoute.dayMode, true); assert.equal(dayRoute.section, 1); assert.equal(dayRoute.offsets[5], 500); assert.equal(tasksRoute.category, 'waiting'); assert.equal(tasksRoute.offset, 700);
    route.restoreSource(true); assert.equal(wardrobe.anchorId, ''); assert.match(wardrobe.feedback, /已删除/); assert.equal(wardrobe.offset, 800); assert.equal(route.offsets[1], 400);
  });
  async function wardrobeFixture() {
    const { AssetRepository, RelationRepository } = require(root + '/data/repository/Repositories.ets');
    const { EntryRepository } = require(root + '/data/repository/EntryRepository.ets'); const db = new SqliteAdapter();
    for (const match of fs.readFileSync(root + '/data/database/Schema.ets', 'utf8').matchAll(/`([^`]+)`/g)) await db.sql(match[1]);
    await db.sql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('role','角色',1,1)");
    for (const [id, status] of [['p1', 'Preparing'], ['p2', 'Completed'], ['p3', 'Preparing']]) await db.sql('INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES(?,\'role\',?,?,1,1)', [id, id, status]);
    const assets = new AssetRepository(db), relations = new RelationRepository(db), entries = new EntryRepository(db);
    const item = Object.assign(new Asset(), { id: 'shared', name: '假发', status: AssetStatus.ORDERED, location: '', priceCents: 10000 }); await assets.save(item);
    const state = new AppState(); state.assetRepo = assets; state.relations = relations; state.entryRepo = entries;
    async function refresh() { state.assets = await assets.list(); state.links = await relations.links(); state.checklist = (await db.sql('SELECT * FROM checklist_items')).rows.map(row => Object.assign(new ChecklistItem(), { id: row[0], projectId: row[1], assetId: row[2] || '', label: row[3], done: row[4] === 1, sortOrder: row[5] })); state.entries = await entries.list(); }
    state.projects = ['p1', 'p2', 'p3'].map(id => Object.assign(new CosProject(), { id, characterId: 'role', status: id === 'p2' ? ProjectStatus.COMPLETED : ProjectStatus.PREPARING }));
    state.refresh = refresh; await refresh(); return { db, assets, relations, entries, state, refresh, item };
  }
  async function shotsFixture() {
    const fixture = await wardrobeFixture(), { db, state } = fixture;
    const { ShotRepository } = require(root + '/data/repository/ShotRepository.ets'), { MetadataBackupRepository } = require(root + '/data/repository/MetadataBackupRepository.ets');
    await db.sql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('other-role','其他角色',1,1)");
    for (const [id, project, character] of [['plan-ref','p1',null], ['role-ref',null,'role'], ['foreign-ref',null,'other-role']]) await db.sql('INSERT INTO reference_images(id,project_id,character_id,source_uri,local_path,thumbnail_path,created_at) VALUES(?,?,?,?,?, ?,1)', [id,project,character,'test://' + id,'','']);
    const repo = new ShotRepository(db); state.shotRepo = repo; state.refresh = async () => { state.shots = await repo.list(); }; await state.refresh();
    return { ...fixture, repo, backup: new MetadataBackupRepository(db) };
  }
  await test('plan records preserve original history while scoping and sorting its read-only home', () => {
    const state = new AppState(), { DiaryEntry } = entities;
    const records = [
      Object.assign(new DiaryEntry(), { id: 'earlier', projectId: 'first', text: '创建计划', createdAt: 1 }),
      Object.assign(new DiaryEntry(), { id: 'other', projectId: 'second', text: '其他计划', createdAt: 9 }),
      Object.assign(new DiaryEntry(), { id: 'latest', projectId: 'first', text: '调整状态', createdAt: 5 }),
      Object.assign(new DiaryEntry(), { id: 'unscoped', projectId: '', text: '旧的未关联记录', createdAt: 10 })
    ];
    state.diary = records; assert.deepEqual(state.projectDiary('first').map(record => record.id), ['latest', 'earlier']);
    assert.equal(state.projectDiary('second')[0].text, '其他计划'); assert.deepEqual(state.projectDiary('missing'), []);
    assert.deepEqual(records.map(record => record.id), ['earlier', 'other', 'latest', 'unscoped']);
    state.diary = records.filter(record => record.projectId !== 'first'); assert.deepEqual(state.projectDiary('first'), []);
    assert.equal(state.diary.length, 2); assert.equal(state.projectDiary('second').length, 1);
  });
  await test('shot counts and completion stay independent of preparation, packing, equipment, money and photo workflow', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { db, state, repo } = await shotsFixture();
    try {
      state.preparationTasks = [Object.assign(new PreparationTask(), { id:'prepare', projectId:'p1', label:'准备', done:false })];
      state.checklist = [Object.assign(new ChecklistItem(), { projectId:'p1', done:true })]; state.photos = [Object.assign(new PhotoAsset(), { projectId:'p1', status:PhotoStatus.FINAL })]; state.expenses = [Object.assign(new Expense(), { projectId:'p1', amountCents:123 })];
      const before = state.readiness('p1'), beforeQueue = JSON.stringify(state.taskQueue); const shot = Object.assign(new ProjectShot(), { id:'shot', projectId:'p1', title:'道具特写' });
      await repo.save(shot,true); await state.refresh(); assert.equal(state.readiness('p1').shots.total,1); assert.equal(state.readiness('p1').shots.done,0);
      assert.equal((await state.toggleShot('shot','p1',false)).status,'ok'); const after = state.readiness('p1'); assert.equal(after.shots.done,1);
      for (const key of ['prep','pack','equipment','photos','money']) assert.deepEqual(after[key],before[key]); assert.equal(JSON.stringify(state.taskQueue),beforeQueue);
      assert.equal((await state.toggleShot('shot','p1',true)).status,'ok'); assert.equal(state.readiness('p1').shots.done,0);
    } finally { db.close(); }
  });
  await test('day shots appear only for this event and obey module enablement and data-driven removal', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { hasEventShots, availableDayModules, assembledDayModules } = require(root + '/model/DayMode.ets'), { db, state, repo } = await shotsFixture();
    try {
      const event = Object.assign(new CosEvent(), { id:'scene', date:'2026-10-08', startTime:'09:00' }); state.projects[0].eventId = event.id;
      const now = new Date('2026-10-08T12:00:00').getTime(); const available = () => availableDayModules(event,state.projects,[],[],now,hasEventShots(event.id,state.projects,state.readinessPlans));
      assert.equal(available().includes('shots'),false);
      const unrelated = Object.assign(new ProjectShot(), { id:'other-shot', projectId:'p3', title:'另一场' }); await repo.save(unrelated,true); await state.refresh(); assert.equal(available().includes('shots'),false);
      const shot = Object.assign(new ProjectShot(), { id:'today-shot', projectId:'p1', title:'今天要拍' }); await repo.save(shot,true); await state.refresh();
      assert.equal(available().includes('shots'),true); assert.equal(assembledDayModules(available(),{},0).some(module=>module.id==='shots'),false); assert.equal(assembledDayModules(available(),{},1).some(module=>module.id==='shots'),true);
      assert.equal(assembledDayModules(available(),{ shots:{ enabled:false,order:0 } },1).some(module=>module.id==='shots'),false);
      await repo.setDone(shot.id,'p1',true,false); await state.refresh(); assert.equal(available().includes('shots'),true);
      await repo.remove(shot.id,'p1'); await state.refresh(); assert.equal(available().includes('shots'),false);
    } finally { db.close(); }
  });
  await test('actual shot CRUD preserves completion on edit, stable order and owner, rejects duplicate creation and rolls back failures', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { db, repo } = await shotsFixture();
    try {
      const shot = Object.assign(new ProjectShot(), { id:'first', projectId:'p1', title:'特写', referenceId:'plan-ref' });
      db.failSql = 'INSERT INTO project_shots'; await assert.rejects(repo.save(shot,true),/injected/); db.failSql = ''; assert.equal((await repo.list()).length,0);
      await repo.save(shot,true); await assert.rejects(repo.save(shot,true),/已创建/); await repo.setDone(shot.id,'p1',true,false);
      await assert.rejects(repo.setDone(shot.id,'p1',true,false),/已变更/); await assert.rejects(repo.setDone(shot.id,'p3',false,true),/已变更/);
      shot.title = '新的画面'; shot.referenceId = 'role-ref'; await repo.save(shot,false); const edited = (await repo.list())[0]; assert.equal(edited.done,true); assert.equal(edited.title,'新的画面'); assert.equal(edited.referenceId,'role-ref'); assert.equal(edited.createdAt,shot.createdAt);
      const next = Object.assign(new ProjectShot(), { id:'second', projectId:'p1', title:'合影' }); await repo.save(next,true); assert.deepEqual((await repo.list()).map(item=>[item.id,item.sortOrder]),[['first',0],['second',1]]);
      await assert.rejects(repo.save(Object.assign(new ProjectShot(), { projectId:'p1', title:'', referenceId:'' }),true),/名称/);
      await assert.rejects(repo.save(Object.assign(new ProjectShot(), { projectId:'gone', title:'未知计划' }),true),/所属计划/);
      shot.referenceId = 'foreign-ref'; await assert.rejects(repo.save(shot,false),/不属于/); assert.equal((await repo.list())[0].referenceId,'role-ref');
      db.failSql = 'DELETE FROM project_shots'; await assert.rejects(repo.remove(shot.id,'p1'),/injected/); db.failSql = ''; assert.equal((await repo.list()).length,2);
      await repo.remove(shot.id,'p1'); await assert.rejects(repo.save(shot,false),/已不存在/); await assert.rejects(repo.remove(shot.id,'p1'),/已不存在/); assert.equal((await repo.list()).length,1);
    } finally { db.close(); }
  });
  await test('shot references clear when media or role ownership changes; project deletion cascades only its own shots', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { db, repo } = await shotsFixture();
    try {
      for (const [id,project,reference] of [['plan-shot','p1','plan-ref'],['role-shot','p1','role-ref'],['other-shot','p3','role-ref']]) await repo.save(Object.assign(new ProjectShot(),{id,projectId:project,title:id,referenceId:reference}),true);
      await repo.setDone('plan-shot','p1',true,false); await db.sql("DELETE FROM reference_images WHERE id='plan-ref'"); assert.equal((await repo.list()).find(item=>item.id==='plan-shot').referenceId,''); assert.equal((await repo.list()).find(item=>item.id==='plan-shot').done,true);
      await db.sql("UPDATE projects SET character_id='other-role' WHERE id='p1'"); assert.equal((await repo.list()).find(item=>item.id==='role-shot').referenceId,''); assert.equal((await repo.list()).find(item=>item.id==='other-shot').referenceId,'role-ref');
      await db.sql("UPDATE reference_images SET character_id='other-role' WHERE id='role-ref'"); assert.equal((await repo.list()).find(item=>item.id==='other-shot').referenceId,'');
      await db.sql("DELETE FROM projects WHERE id='p1'"); assert.deepEqual((await repo.list()).map(item=>item.id),['other-shot']);
    } finally { db.close(); }
  });
  await test('shot writes distinguish failed persistence from committed refresh failure and reload never repeats creation or completion', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { db, state, repo } = await shotsFixture();
    try {
      const shot = Object.assign(new ProjectShot(),{id:'saved',projectId:'p1',title:'合影'}); const reload = state.refresh;
      db.failSql = 'INSERT INTO project_shots'; assert.equal(await state.saveShot(shot,true),false); assert.equal(state.shots.length,0); db.failSql = '';
      state.refresh = async () => { throw new Error('read failure'); }; assert.equal(await state.saveShot(shot,true),true); assert.equal(state.lastOperation.status,'savedNotRefreshed'); assert.deepEqual(state.staleScopes,['shots']); assert.equal((await repo.list()).length,1);
      assert.equal((await state.toggleShot(shot.id,'p1',false)).status,'failed'); state.refresh = reload; assert.equal(await state.reloadRecords(),true); assert.equal(state.shots.length,1);
      state.refresh = async () => { throw new Error('read failure'); }; assert.equal((await state.toggleShot(shot.id,'p1',false)).status,'savedNotRefreshed'); assert.equal((await repo.list())[0].done,true);
      state.refresh = reload; assert.equal(await state.reloadRecords(),true); assert.equal(state.shots[0].done,true); assert.equal((await repo.list()).length,1);
    } finally { db.close(); }
  });
  await test('shot drafts preserve reference context, support old draft records and recognize interrupted committed creation', async () => {
    const { PlanningRepository } = require(root + '/data/repository/PlanningRepository.ets'), { db,state } = await shotsFixture();
    try {
      state.references = await new PlanningRepository(db).references(); let text=''; const store = new FormDraftStore({read:async()=>text,write:async value=>{text=value;}});
      const draft = EditDraft.make(state,'shot','','p1'); const session = new FormSession(draft,store); await session.initialize(state); draft.name='合影'; draft.referenceId='role-ref'; await session.flush();
      const snapshot = (await store.load(formDraftKey(draft))).payload; const restored = EditDraft.fromJSON(snapshot); assert.equal(restored.referenceId,'role-ref'); assert.deepEqual(restored.issues(state),[]);
      restored.referenceId='foreign-ref'; assert.ok(restored.issues(state).some(issue=>issue.field==='referenceId'));
      assert.equal(await draft.save(state),true); assert.equal(draft.committedCreation(state),true);
      const reopening = new FormSession(EditDraft.make(state,'shot','','p1'),store); await reopening.initialize(state); assert.equal(reopening.pendingRestore,undefined); assert.match(reopening.error,/上次创建已保存/);
      const old = JSON.parse(EditDraft.make(state,'character','').serialize()); delete old.referenceId; assert.equal(EditDraft.fromJSON(JSON.stringify(old)).referenceId,'');
      const baseline = JSON.parse(EditDraft.make(state,'character').fingerprint()); delete baseline.referenceId; text = JSON.stringify({ version:1,records:[{key:formDraftKey(EditDraft.make(state,'character')),payload:JSON.stringify(old),baseline:JSON.stringify(baseline),savedAt:Date.now()}] });
      const oldSession = new FormSession(EditDraft.make(state,'character'),store); await oldSession.initialize(state); oldSession.restore(); assert.equal(oldSession.sourceChanged,false);
    } finally { db.close(); }
  });
  await test('v7 shot backup preview and restore preserve links and completion; v6 clears only the absent shot type; invalid ownership and failed replacement retain records', async () => {
    const { ProjectShot } = require(root + '/model/Shot.ets'), { db,repo,backup } = await shotsFixture();
    try {
      await repo.save(Object.assign(new ProjectShot(),{id:'backed',projectId:'p1',title:'合影',referenceId:'role-ref'}),true); await repo.setDone('backed','p1',true,false);
      const exported = await backup.exportMetadata(); assert.equal(JSON.parse(exported).version,7); const preview = await backup.previewMetadata(exported); assert.equal(preview.counts.find(row=>row.table==='project_shots').incoming,1); assert.equal((await repo.list())[0].done,true);
      const bad = JSON.parse(exported); bad.tables.find(table=>table.name==='project_shots').rows[0].reference_id='foreign-ref'; await assert.rejects(backup.previewMetadata(JSON.stringify(bad)),/不属于/); assert.equal((await repo.list()).length,1);
      db.failSql='INSERT INTO project_shots'; await assert.rejects(backup.restoreMetadata(exported),/injected/); db.failSql=''; assert.equal((await repo.list())[0].done,true);
      const legacy = JSON.parse(exported); legacy.version=6; legacy.tables=legacy.tables.slice(0,16); const oldPreview = await backup.previewMetadata(JSON.stringify(legacy)); assert.equal(oldPreview.counts.find(row=>row.table==='project_shots').incoming,0);
      await backup.restoreMetadata(JSON.stringify(legacy)); assert.equal((await repo.list()).length,0); assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0],3);
      await backup.restoreMetadata(exported); assert.equal((await repo.list())[0].referenceId,'role-ref'); assert.equal((await repo.list())[0].done,true);
    } finally { db.close(); }
  });
  await test('role-scoped plan creation persists the selected version atomically and retains the draft after a failed write', async () => {
    const { CosProjectRepository, CharacterRepository, CharacterVariantRepository, DiaryEntryRepository } = require(root + '/data/repository/Repositories.ets');
    const { PreparationRepository } = require(root + '/data/repository/PreparationRepository.ets');
    const { db, state } = await wardrobeFixture();
    try {
      state.projectRepo = new CosProjectRepository(db); state.characterRepo = new CharacterRepository(db); state.variantRepo = new CharacterVariantRepository(db);
      state.preparationRepo = new PreparationRepository(db); state.diaryRepo = new DiaryEntryRepository(db);
      await state.variantRepo.save(Object.assign(new entities.CharacterVariant(), { id: 'winter', characterId: 'role', name: '冬装' }));
      state.refresh = async () => { state.characters = await state.characterRepo.list(); state.variants = await state.variantRepo.list(); state.projects = await state.projectRepo.list(); state.diary = await state.diaryRepo.list(); state.preparationCategories = await state.preparationRepo.categories(); state.preparationTasks = await state.preparationRepo.tasks(); };
      await state.refresh(); const source = state.variants[0], draft = EditDraft.make(state, 'project', '', 'role', 'winter');
      db.failSql = 'INSERT INTO projects'; assert.equal(await draft.save(state), false); assert.equal(draft.id, ''); assert.equal(draft.variantId, 'winter'); assert.equal(draft.name, '角色 · 计划'); assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 3);
      db.failSql = ''; assert.equal(await draft.save(state), true); const saved = (await db.sql('SELECT character_id,variant_id FROM projects WHERE id=?', [draft.creationId])).rows[0]; assert.deepEqual(saved, ['role', 'winter']);
      assert.equal(source.name, '冬装'); assert.equal(state.projects.find(project => project.id === draft.creationId).variantId, 'winter'); assert.equal(state.projectWork(draft.creationId).value.variant, '冬装');
      assert.equal((await db.sql('SELECT count(*) FROM characters')).rows[0][0], 1); assert.equal((await db.sql('SELECT count(*) FROM variants')).rows[0][0], 1);
    } finally { db.close(); }
  });
  await test('role favorite writes preserve legacy fields and failure leaves the original flag and work history intact', async () => {
    const { CharacterRepository } = require(root + '/data/repository/Repositories.ets'), { db, state } = await wardrobeFixture();
    try {
      state.characterRepo = new CharacterRepository(db); state.characters = await state.characterRepo.list(); state.refresh = async () => { state.characters = await state.characterRepo.list(); };
      const original = state.characters[0], favorite = Object.assign(new entities.Character(), original, { favorite: true });
      db.failSql = 'INSERT INTO characters'; assert.equal(await state.saveCharacter(favorite), false); assert.equal(state.characters[0].favorite, false); assert.equal((await db.sql('SELECT favorite FROM characters')).rows[0][0], 0);
      db.failSql = ''; assert.equal(await state.saveCharacter(favorite), true); assert.equal(state.characters[0].favorite, true); assert.equal(state.characters[0].status, 'Wishlist'); assert.equal(state.characterSummary('role').planCount, 3);
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 3); assert.equal((await db.sql('SELECT status FROM characters')).rows[0][0], 'Wishlist'); assert.equal(original.favorite, false);
    } finally { db.close(); }
  });
  await test('actual asset links are atomic, idempotent and use the current name; unlink only removes one plan packing context', async () => {
    const fixture = await wardrobeFixture(), { db, relations, item } = fixture;
    try {
      db.failSql = 'INSERT OR IGNORE INTO checklist_items'; await assert.rejects(relations.link('p1', item)); db.failSql = '';
      assert.equal((await relations.links()).length, 0); assert.equal((await db.sql('SELECT count(*) FROM checklist_items')).rows[0][0], 0);
      await db.sql("UPDATE assets SET name='当前假发' WHERE id='shared'"); await relations.link('p1', item); await relations.link('p1', item); await relations.link('p2', item);
      assert.equal((await relations.links()).length, 2); assert.deepEqual((await db.sql('SELECT label FROM checklist_items')).rows, [['当前假发'], ['当前假发']]);
      await db.sql("UPDATE checklist_items SET done=1 WHERE project_id='p2'");
      await assert.rejects(relations.unlink('p1', item.id, ['changed']), /已变化/); assert.equal((await relations.links()).length, 2);
      const id = (await db.sql("SELECT id FROM checklist_items WHERE project_id='p1'")).rows[0][0];
      db.failSql = 'DELETE FROM checklist_items'; await assert.rejects(relations.unlink('p1', item.id, [id])); db.failSql = ''; assert.equal((await relations.links()).length, 2);
      await relations.unlink('p1', item.id, [id]); assert.deepEqual((await relations.links()).map(link => link.projectId), ['p2']);
      assert.deepEqual((await db.sql('SELECT project_id,done FROM checklist_items')).rows, [['p2', 1]]); assert.equal((await db.sql('SELECT count(*) FROM assets')).rows[0][0], 1);
      await assert.rejects(relations.unlink('p1', item.id, []), /关联已变化/); await assert.rejects(relations.link('p1', Object.assign(new Asset(), { id: 'missing' })), /已不存在/);
      const created = Object.assign(new Asset(), { id: 'new-for-plan', name: '新装备', status: AssetStatus.ORDERED });
      await assert.rejects(fixture.assets.save(created, 'missing-plan')); assert.equal((await fixture.assets.list()).length, 1);
      db.failSql = 'INSERT INTO checklist_items'; await assert.rejects(fixture.assets.save(created, 'p3')); db.failSql = ''; assert.equal((await fixture.assets.list()).length, 1);
      await fixture.assets.save(created, 'p3'); assert.equal((await fixture.assets.list()).find(asset => asset.id === created.id).status, AssetStatus.ORDERED);
      assert.deepEqual((await db.sql("SELECT project_id,label,done FROM checklist_items WHERE asset_id='new-for-plan'")).rows, [['p3', '新装备', 0]]);
    } finally { db.close(); }
  });
  await test('asset deletion validates its reviewed impact, rolls back failures and retains packing labels, confirmations and expenses', async () => {
    const { CollectedEntry } = require(root + '/model/CollectedEntry.ets'); const f = await wardrobeFixture(), { db, assets, relations, entries, state, item, refresh } = f;
    try {
      await relations.link('p1', item); await relations.link('p2', item); await db.sql("UPDATE checklist_items SET done=1 WHERE project_id='p1'");
      await entries.save(Object.assign(new CollectedEntry(), { id: 'note', scopeKind: 'asset', scopeId: item.id, text: '保留收录' }));
      await db.sql("INSERT INTO expenses(id,project_id,name,category,amount_cents,date,notes,created_at) VALUES('expense','p1','假发','其他',500,'2026-10-08','',1)");
      await refresh(); const reviewed = state.assetUsage(item.id); assert.equal(reviewed.projects.length, 2); assert.equal(reviewed.activeProjects.length, 1);
      await relations.link('p3', item); await assert.rejects(assets.remove(item.id, reviewed.removalKey), /关联已变化/); assert.equal((await assets.list()).length, 1);
      await refresh(); const current = state.assetUsage(item.id); db.failSql = 'DELETE FROM assets'; await assert.rejects(assets.remove(item.id, current.removalKey)); db.failSql = '';
      assert.equal((await relations.links()).length, 3); assert.equal((await entries.list())[0].scopeKind, 'asset');
      await assets.remove(item.id, current.removalKey); assert.equal((await assets.list()).length, 0); assert.equal((await relations.links()).length, 0);
      assert.deepEqual((await db.sql('SELECT asset_id,label,done FROM checklist_items ORDER BY project_id')).rows, [[null, '假发', 1], [null, '假发', 0], [null, '假发', 0]]);
      assert.equal((await entries.list())[0].scopeKind, 'global'); assert.equal((await entries.list())[0].text, '保留收录'); assert.equal((await db.sql('SELECT amount_cents FROM expenses')).rows[0][0], 500);
      await assert.rejects(assets.remove(item.id, current.removalKey), /不存在/);
    } finally { db.close(); }
  });
  await test('AppState shared asset changes update every plan while preserving prep and packing; committed relation failures only reload', async () => {
    const f = await wardrobeFixture(), { db, state, item, refresh } = f;
    try {
      assert.equal(await state.linkAsset('p1', item), true); assert.equal(await state.linkAsset('p3', item), true);
      await db.sql("UPDATE checklist_items SET done=1 WHERE project_id='p1'"); await refresh();
      assert.equal(state.assetUsage(item.id).activeProjects.length, 2); assert.equal(state.readiness('p1').equipment.available, 0); assert.equal(state.readiness('p3').equipment.available, 0);
      assert.equal(await state.saveAsset(Object.assign(new Asset(), item, { status: AssetStatus.OWNED })), true);
      assert.equal(state.readiness('p1').equipment.available, 1); assert.equal(state.readiness('p3').equipment.available, 1); assert.equal(state.readiness('p1').pack.packed, 1); assert.equal(state.readiness('p3').pack.packed, 0); assert.equal(state.readiness('p1').prep.total, 0); assert.equal(state.readiness('p1').money.spentCents, 0);
      let reads = 0; state.refresh = async () => { reads++; if (reads === 1) throw new Error('read failed'); await refresh(); };
      assert.equal(await state.linkAsset('p2', item), true); assert.equal(state.lastOperation.status, 'savedNotRefreshed');
      db.failSql = 'INSERT OR IGNORE'; assert.equal(await state.reloadRecords(), true); db.failSql = ''; assert.equal((await db.sql('SELECT count(*) FROM checklist_items')).rows[0][0], 3);
      state.refresh = refresh; const usage = state.assetUsage(item.id); db.failSql = 'DELETE FROM assets'; assert.equal(await state.removeAsset(item.id, usage.removalKey), false); db.failSql = ''; assert.equal(state.assets.length, 1);
      reads = 0; state.refresh = async () => { reads++; if (reads === 1) throw new Error('read failed'); await refresh(); };
      assert.equal(await state.removeAsset(item.id, usage.removalKey), true); assert.equal(state.lastOperation.status, 'savedNotRefreshed'); db.failSql = 'DELETE FROM assets'; assert.equal(await state.reloadRecords(), true); db.failSql = '';
      assert.equal(state.assets.length, 0); assert.equal(state.links.length, 0); assert.equal(state.checklist.length, 3); assert.equal(state.checklist.every(item => !item.assetId), true);
    } finally { db.close(); }
  });
  await test('photo import tracks progress, preserves successes and retries only failed sources', async () => {
    const { PhotoImportJob } = require(root + '/model/PhotoImport.ets');
    const job = new PhotoImportJob(), committed = new Map(); let unavailable = true, readFailure = true; const calls = [], removed = [];
    const ports = {
      find: async (id, uri) => { if (uri === 'read' && readFailure) throw new Error('database read unavailable'); return committed.get(uri); },
      exists: async () => true,
      import: async (uri, projectId) => { calls.push(uri); assert.equal(job.processed < job.total, true); if (uri === 'bad' && unavailable) throw new Error('grant unavailable'); return Object.assign(new PhotoAsset(), { sourceUri: uri, projectId }); },
      add: async photo => { if (photo.sourceUri === 'write' && unavailable) throw new Error('database write unavailable'); committed.set(photo.sourceUri, photo); },
      replace: async () => { throw new Error('unexpected replacement'); }, remove: async photo => removed.push(photo.sourceUri)
    };
    job.begin('plan'); await job.run(['ok', 'ok', 'bad', 'write', 'read'], ports);
    assert.equal(job.phase, 'completed'); assert.equal(job.processed, 5); assert.equal(job.succeeded, 1); assert.equal(job.skipped, 1);
    assert.deepEqual(job.failures.map(item => item.uri), ['bad', 'write', 'read']); assert.deepEqual(removed, ['write']); assert.equal(committed.size, 1);
    const retry = job.failures.map(item => item.uri); unavailable = false; readFailure = false; job.begin('plan'); await job.run(retry, ports);
    assert.equal(job.succeeded, 3); assert.equal(job.failures.length, 0); assert.equal(committed.size, 4); assert.equal(calls.filter(uri => uri === 'ok').length, 1);
  });
  await test('photo import processes a 300-source batch sequentially with exact progress and no duplicate records', async () => {
    const { PhotoImportJob } = require(root + '/model/PhotoImport.ets'), job = new PhotoImportJob(); const records = new Set(); let active = 0, maximum = 0;
    job.begin('plan'); const uris = Array.from({ length: 300 }, (_, index) => 'uri-' + index);
    await job.run(uris.concat(uris[0]), { find: async () => undefined, exists: async () => false,
      import: async uri => { maximum = Math.max(maximum, ++active); await Promise.resolve(); active--; return Object.assign(new PhotoAsset(), { sourceUri: uri }); },
      add: async photo => records.add(photo.sourceUri), replace: async () => {}, remove: async () => {} });
    assert.equal(job.total, 301); assert.equal(job.processed, 301); assert.equal(job.succeeded, 300); assert.equal(job.skipped, 1); assert.equal(records.size, 300); assert.equal(maximum, 1);
  });
  await test('photo import cancellation keeps committed items and removes only the uncommitted staged item', async () => {
    const { PhotoImportJob } = require(root + '/model/PhotoImport.ets'); const job = new PhotoImportJob(); const committed = [], removed = [];
    const ports = { find: async () => undefined, exists: async () => false,
      import: async uri => { if (uri === 'second') job.cancel(); return Object.assign(new PhotoAsset(), { sourceUri: uri }); },
      add: async photo => committed.push(photo.sourceUri), replace: async () => {}, remove: async photo => removed.push(photo.sourceUri) };
    job.begin('plan'); await job.run(['first', 'second', 'third'], ports);
    assert.deepEqual(committed, ['first']); assert.deepEqual(removed, ['second']); assert.equal(job.succeeded, 1); assert.equal(job.cancelled, 2); assert.equal(job.processed, 1); assert.equal(job.failures.length, 0);
  });
  await test('actual media inspection separates absent paths, missing files and access failure; thumbnail writes are complete', async () => {
    const { MediaRepository } = require(root + '/data/media/MediaRepository.ets');
    const repo = new MediaRepository({ filesDir: '/sandbox', cacheDir: '/cache' });
    mediaControl = { files: new Set(['/sandbox/media/original', 'test://source']), removed: [], denied: ['/denied'] };
    assert.deepEqual(await repo.inspect({ localPath: '', thumbnailPath: '/missing' }), { original: 'unlinked', thumbnail: 'missing' });
    assert.deepEqual(await repo.inspect({ localPath: '/sandbox/media/original', thumbnailPath: '/denied' }), { original: 'available', thumbnail: 'unreadable' });
    const photo = Object.assign(new PhotoAsset(), { projectId: 'plan', sourceUri: 'test://old', localPath: '/sandbox/media/original', thumbnailPath: '/sandbox/media/oldthumb' });
    mediaControl.shortWrite = true; await assert.rejects(repo.rebuildThumbnail(photo), /未完整写入/);
    assert.equal(mediaControl.files.has(photo.localPath), true); assert.equal(mediaControl.removed.includes(photo.localPath), false);
    await assert.rejects(repo.import('test://source', 'plan'), /未完整写入/); assert.equal(mediaControl.files.has('test://source'), true);
    mediaControl.shortWrite = false; const rebuilt = await repo.rebuildThumbnail(photo);
    assert.equal(rebuilt.localPath, photo.localPath); assert.notEqual(rebuilt.thumbnailPath, photo.thumbnailPath); assert.deepEqual(mediaControl.desired, { width: 240, height: 480 });
    assert.equal(await repo.exists(rebuilt), true);
    await repo.select(500); assert.equal(mediaControl.pickerOptions.maxSelectNumber, 500);
    mediaControl.files.add('/sandbox/media/version.jpg'); mediaControl.files.add('/sandbox/media/orphan.jpg');
    await repo.collect([rebuilt], [], [], ['/sandbox/media/version.jpg']); assert.equal(mediaControl.files.has('/sandbox/media/version.jpg'), true); assert.equal(mediaControl.files.has('/sandbox/media/orphan.jpg'), false);
  });
  await test('media replacement is atomic and preserves photo identity, workflow, caption, time, covers and edited versions', async () => {
    const { PhotoAssetRepository, RelationRepository } = require(root + '/data/repository/Repositories.ets'); const repairDb = new SqliteAdapter();
    try {
      for (const match of fs.readFileSync(root + '/data/database/Schema.ets', 'utf8').matchAll(/`([^`]+)`/g)) await repairDb.sql(match[1]);
      await repairDb.sql("INSERT INTO characters(id,name,cover,created_at,updated_at) VALUES('role','角色','/old-thumb',1,1)");
      await repairDb.sql("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('plan','role','照片计划','Preparing',1,1)");
      await repairDb.sql("INSERT INTO photos VALUES('photo','plan','old-uri','/old','/old-thumb','Final','保留说明',123)");
      await repairDb.sql("INSERT INTO photo_versions VALUES('original','photo','Original','{}','/old',1)");
      await repairDb.sql("INSERT INTO photo_versions VALUES('edited','photo','Edited','edited-recipe','/edited',2)");
      const repo = new PhotoAssetRepository(repairDb), staged = Object.assign(new PhotoAsset(), { projectId: 'plan', sourceUri: 'new-uri', localPath: '/new', thumbnailPath: '/new-thumb' });
      repairDb.failSql = 'UPDATE characters'; await assert.rejects(repo.replaceMedia('photo', 'plan', staged), /injected/); repairDb.failSql = '';
      assert.deepEqual((await repairDb.sql('SELECT source_uri,local_path,thumbnail_path FROM photos')).rows[0], ['old-uri', '/old', '/old-thumb']);
      await repo.replaceMedia('photo', 'plan', staged);
      assert.deepEqual((await repairDb.sql('SELECT id,project_id,status,caption,created_at,source_uri,local_path FROM photos')).rows[0], ['photo', 'plan', 'Final', '保留说明', 123, 'new-uri', '/new']);
      assert.equal((await repairDb.sql('SELECT cover FROM characters')).rows[0][0], '/new-thumb');
      assert.deepEqual((await repairDb.sql('SELECT name,recipe,rendered_path FROM photo_versions ORDER BY id')).rows, [['Edited', 'edited-recipe', '/edited'], ['Original', '{}', '/new']]);
      assert.deepEqual((await repo.renderedPaths()).sort(), ['/edited', '/new']);
      await assert.rejects(repo.replaceMedia('photo', 'wrong-plan', staged), /已变化/);
      await repairDb.sql("UPDATE photo_versions SET rendered_path=''"); await repo.replaceMedia('photo', 'plan', staged);
      assert.equal((await repairDb.sql("SELECT rendered_path FROM photo_versions WHERE name='Original'")).rows[0][0], '/new');
      assert.equal((await repairDb.sql("SELECT rendered_path FROM photo_versions WHERE name='Edited'")).rows[0][0], '');
      await repairDb.sql("UPDATE photo_versions SET rendered_path='/edited' WHERE name='Edited'");
      await repairDb.sql("INSERT INTO photos VALUES('collision','plan','collision-uri','/collision','/collision-thumb','Raw','',1)");
      await assert.rejects(repo.replaceMedia('photo', 'plan', Object.assign(new PhotoAsset(), staged, { sourceUri: 'collision-uri' })));
      assert.equal((await repo.list()).find(photo => photo.id === 'photo').sourceUri, 'new-uri'); await repo.remove('collision');
      const state = new AppState(); state.photoRepo = repo; state.relations = new RelationRepository(repairDb); state.projects = [Object.assign(new CosProject(), { id: 'plan' })]; state.photos = await repo.list();
      let imports = 0, refreshes = 0; const removed = [];
      state.media = { select: async () => [], import: async uri => { imports++; return Object.assign(new PhotoAsset(), staged, { id: entities.newId(), sourceUri: uri }); }, remove: async media => removed.push(media), rebuildThumbnail: async photo => Object.assign(new PhotoAsset(), staged, { sourceUri: photo.sourceUri, localPath: photo.localPath }) };
      state.refresh = async () => { refreshes++; if (refreshes === 1) throw new Error('read unavailable'); state.photos = await repo.list(); };
      assert.equal(await state.repairPhoto('photo'), false); assert.equal(imports, 0); // Picker cancellation
      refreshes = 0; state.media.select = async () => ['repaired-uri'];
      assert.equal(await state.repairPhoto('photo'), true); assert.equal(state.lastOperation.status, 'savedNotRefreshed'); assert.equal(imports, 1); assert.equal(removed.length, 0);
      repairDb.failSql = 'UPDATE photos'; assert.equal(await state.reloadRecords(), true); repairDb.failSql = ''; assert.equal(imports, 1);
      repairDb.failSql = 'UPDATE photos'; assert.equal(await state.repairPhoto('photo', true), false); repairDb.failSql = '';
      assert.equal(removed.length, 1); assert.equal(removed[0].localPath, ''); assert.equal((await repo.list())[0].localPath, '/new');
      const { CharacterRepository } = require(root + '/data/repository/Repositories.ets'); state.characterRepo = new CharacterRepository(repairDb); state.projects[0].characterId = 'role'; state.characters = await state.characterRepo.list();
      state.refresh = async () => { state.photos = await repo.list(); state.characters = await state.characterRepo.list(); };
      state.media.inspect = async () => ({ original: 'available', thumbnail: 'missing' });
      assert.equal(await state.setCover(state.photos[0]), false); assert.match(state.error, /缩略图不可用/);
      state.media.inspect = async () => ({ original: 'available', thumbnail: 'available' }); assert.equal(await state.setCover(state.photos[0]), true); assert.match(state.notice, /角色封面/);
      const draft = EditDraft.make(state, 'photo', 'photo'); assert.equal(draft.notes, '保留说明'); assert.equal(draft.title(), '编辑照片说明'); assert.deepEqual(draft.issues(state), []);
      let raw = ''; const store = new FormDraftStore({ read: async () => raw, write: async value => { raw = value; } }); const session = new FormSession(draft, store);
      await session.initialize(state); draft.notes = '新的说明'; assert.equal(session.dirty, true); await session.flush();
      const reopened = new FormSession(EditDraft.make(state, 'photo', 'photo'), store); await reopened.initialize(state); reopened.restore(); assert.equal(reopened.draft.notes, '新的说明'); assert.equal(await reopened.draft.save(state), true); await reopened.finish(true, true);
      assert.equal((await repo.list())[0].caption, '新的说明'); assert.equal((await repo.list())[0].status, PhotoStatus.FINAL); assert.equal((await repo.list())[0].createdAt, 123);
      draft.notes = 'x'.repeat(20001); assert.equal(draft.issues(state)[0].field, 'notes');
      await repo.remove('photo'); state.photos = []; assert.equal(await draft.save(state), false); await assert.rejects(repo.setCaption('photo', ''), /不存在/); await assert.rejects(repo.setStatuses(['photo'], PhotoStatus.RAW), /已变化/);
      assert.equal((await repairDb.sql('SELECT count(*) FROM photos')).rows[0][0], 0);
    } finally { repairDb.close(); }
  });
  await test('AppState import partial results, source deduplication and retry stay committed across refresh failure', async () => {
    const { PhotoAssetRepository, RelationRepository } = require(root + '/data/repository/Repositories.ets'); const importDb = new SqliteAdapter();
    try {
      for (const match of fs.readFileSync(root + '/data/database/Schema.ets', 'utf8').matchAll(/`([^`]+)`/g)) await importDb.sql(match[1]);
      await importDb.sql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('role','角色',1,1)");
      await importDb.sql("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('plan','role','照片计划','Preparing',1,1)");
      const repo = new PhotoAssetRepository(importDb), state = new AppState(); state.photoRepo = repo; state.relations = new RelationRepository(importDb); state.projects = [Object.assign(new CosProject(), { id: 'plan' })];
      let bad = true; const imported = []; state.media = { select: async () => ['ok', 'ok', 'bad'], exists: async () => true, import: async uri => { imported.push(uri); if (uri === 'bad' && bad) throw new Error('grant unavailable'); return Object.assign(new PhotoAsset(), { projectId: 'plan', sourceUri: uri, localPath: '/local/' + uri, thumbnailPath: '/thumb/' + uri }); }, remove: async () => {} };
      state.refresh = async () => { state.photos = await repo.list(); };
      assert.equal(await state.importPhotos('plan'), true); assert.equal(state.lastOperation.status, 'partial'); assert.equal(state.photoImport.succeeded, 1); assert.equal(state.photoImport.skipped, 1); assert.equal(state.photoImport.failures.length, 1);
      assert.equal((await importDb.sql('SELECT count(*) FROM photos')).rows[0][0], 1);
      const before = state.photos[0]; await repo.setCaption(before.id, '保留'); await repo.setStatuses([before.id], PhotoStatus.FINAL);
      state.media.select = async () => ['ok']; state.media.exists = async () => false;
      assert.equal(await state.importPhotos('plan'), true); assert.equal((await repo.list())[0].id, before.id); assert.equal((await repo.list())[0].createdAt, before.createdAt); assert.equal((await repo.list())[0].caption, '保留'); assert.equal((await repo.list())[0].status, PhotoStatus.FINAL);
      assert.equal((await importDb.sql('SELECT count(*) FROM photo_versions')).rows[0][0], 1);
      state.media.select = async () => ['bad']; state.media.exists = async () => true; assert.equal(await state.importPhotos('plan'), false);
      bad = false; let reads = 0; state.refresh = async () => { reads++; if (reads === 1) throw new Error('refresh failed'); state.photos = await repo.list(); };
      assert.equal(await state.retryPhotoImport(), true); assert.equal(state.lastOperation.status, 'savedNotRefreshed'); assert.equal(state.photoImport.failures.length, 0); assert.equal(imported.filter(uri => uri === 'ok').length, 2);
      assert.equal(await state.retryPhotoImport(), false); assert.equal((await importDb.sql('SELECT count(*) FROM photos')).rows[0][0], 2);
      importDb.failSql = 'INSERT INTO photos'; assert.equal(await state.reloadRecords(), true); importDb.failSql = ''; assert.equal((await importDb.sql('SELECT count(*) FROM photos')).rows[0][0], 2);
      state.media.select = async () => []; assert.equal(await state.importPhotos('plan'), false); assert.equal(state.notice, '');
      state.media.select = async () => ['never']; state.media.import = async () => { throw new Error('format not supported'); };
      assert.equal(await state.importPhotos('plan'), false); assert.equal(state.lastOperation.status, 'failed'); assert.equal(state.photoImport.failures.length, 1); assert.match(state.error, /没有照片导入成功/);
    } finally { importDb.close(); }
  });
  await test('actual photo batch repository rolls back invalid IDs and AppState refresh failure does not reapply the batch', async () => {
    const { PhotoAssetRepository } = require(root + '/data/repository/Repositories.ets');
    const { PhotoCollectionRoute } = require(root + '/model/PhotoCollection.ets');
    const batchDb = new SqliteAdapter();
    try {
      for (const match of fs.readFileSync(root + '/data/database/Schema.ets', 'utf8').matchAll(/`([^`]+)`/g)) await batchDb.sql(match[1]);
      await batchDb.sql("INSERT INTO characters(id,name,created_at,updated_at) VALUES('role','角色',1,1)");
      await batchDb.sql("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('plan','role','照片计划','Preparing',1,1)");
      for (const id of ['photo-a', 'photo-b']) await batchDb.sql("INSERT INTO photos VALUES(?,'plan',?,'','','Raw','',1)", [id, 'test://' + id]);
      const repo = new PhotoAssetRepository(batchDb);
      await assert.rejects(repo.setStatuses(['photo-a', 'missing'], PhotoStatus.FINAL), /已变化/);
      assert.deepEqual((await batchDb.sql('SELECT status FROM photos')).rows, [['Raw'], ['Raw']]);
      const state = new AppState(); state.photoRepo = repo; state.photos = await repo.list(); let reads = 0;
      state.refresh = async () => { reads++; if (reads === 1) throw new Error('read failed'); state.photos = await repo.list(); };
      const route = new PhotoCollectionRoute('plan'); route.selecting = true; route.selectAll(state.photos);
      const ids = route.begin(state.photos); route.finish(await state.setPhotoStatuses(ids, PhotoStatus.WAITING));
      assert.equal(state.lastOperation.status, 'savedNotRefreshed'); assert.deepEqual(route.selectedIds, []); assert.equal(route.selecting, false);
      assert.deepEqual((await batchDb.sql('SELECT status FROM photos')).rows, [['WaitingForRetouch'], ['WaitingForRetouch']]);
      batchDb.failSql = 'UPDATE photos'; assert.equal(await state.reloadRecords(), true); batchDb.failSql = '';
      assert.equal(reads, 2); assert.equal(state.photos.every(photo => photo.status === PhotoStatus.WAITING), true);
    } finally { batchDb.close(); }
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
      state.projects = [Object.assign(new CosProject(), { id: 'positive' })]; state.preparationRepo = preparations; state.shotRepo = new (require(root + '/data/repository/ShotRepository.ets').ShotRepository)(db);
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
      state.projectRepo = new CosProjectRepository(db); state.characterRepo = new CharacterRepository(db); state.diaryRepo = new DiaryEntryRepository(db); state.preparationRepo = preparations; state.shotRepo = new (require(root + '/data/repository/ShotRepository.ets').ShotRepository)(db);
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
      assert.equal(JSON.parse(exported).version, 7); await backup.restoreMetadata(exported);
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
    await test('current waiting fields round trip; v5 defaults them without changing task history', async () => {
      await backup.restoreMetadata(exported); const current = (await preparations.tasks()).find(task => task.id === 'persist-wait');
      assert.equal(current.waitingOn, '毛娘'); assert.equal(current.waitingUntil, '2026-10-11');
      const old = JSON.parse(exported); old.version = 5; old.tables = old.tables.slice(0, 16);
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
    await test('backup invalid foreign key is rejected before offering replacement', async () => {
      const doc = JSON.parse(exported); doc.tables.find(t => t.name === 'projects').rows[0].character_id = 'missing';
      await assert.rejects(backup.previewMetadata(JSON.stringify(doc)), /关联无效/);
      await assert.rejects(backup.restoreMetadata(JSON.stringify(doc)), /关联无效/);
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
      assert.equal((await db.sql('SELECT name FROM characters')).rows[0][0], 'Legacy');
    });
    await test('backup preview counts current and incoming objects without any transaction or mutation', async () => {
      const before = await backup.exportMetadata(); const originalTransaction = db.transaction;
      db.transaction = async () => { throw new Error('preview must not begin a transaction'); };
      const doc = JSON.parse(exported); doc.version = 4; doc.tables = doc.tables.slice(0, 15);
      for (const row of doc.tables.find(table => table.name === 'preparation_tasks').rows) { delete row.waiting_on; delete row.waiting_until; }
      const preview = await backup.previewMetadata(JSON.stringify(doc));
      assert.equal(preview.version, 4); assert.equal(preview.exportedAt, doc.exportedAt);
      assert.equal(preview.counts.length, 17); assert.equal(preview.counts.find(row => row.table === 'projects').incoming, 4);
      assert.equal(preview.counts.find(row => row.table === 'entries').incoming, 0);
      assert.equal(preview.incomingCount, preview.counts.reduce((sum, row) => sum + row.incoming, 0));
      assert.deepEqual(JSON.parse(await backup.exportMetadata()).tables, JSON.parse(before).tables);
      db.transaction = originalTransaction;
    });
    await test('backup preview rejects duplicate IDs, duplicate relationships, invalid states and mismatched owners', async () => {
      const original = JSON.parse(exported);
      const mutations = [
        doc => doc.tables.find(t => t.name === 'characters').rows.push({ ...doc.tables.find(t => t.name === 'characters').rows[0] }),
        doc => { doc.tables.find(t => t.name === 'projects').rows[0].status = 'Unknown'; },
        doc => { doc.tables.find(t => t.name === 'preparation_tasks').rows[0].project_id = 'zero'; },
        doc => { doc.tables.find(t => t.name === 'preparation_tasks').rows[0].done = 2; },
        doc => { doc.tables.find(t => t.name === 'preparation_tasks').rows[0].id = ''; },
        doc => { doc.exportedAt = -1; },
        doc => doc.tables.find(t => t.name === 'preparation_categories').rows.push({ ...doc.tables.find(t => t.name === 'preparation_categories').rows[0], id: 'duplicate-name' }),
      ];
      for (const mutation of mutations) {
        const doc = structuredClone(original); mutation(doc); await assert.rejects(backup.previewMetadata(JSON.stringify(doc)));
      }
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
    });
    await test('backup preview states media gaps and rejects duplicate photo sources and conflicting reference ownership', async () => {
      const doc = JSON.parse(exported);
      const photo = { id: 'preview-photo', project_id: 'positive', source_uri: 'test://media', local_path: '/foreign/file', thumbnail_path: '/foreign/thumb', status: 'Final', caption: '', created_at: 1 };
      doc.tables.find(t => t.name === 'photos').rows.push(photo);
      doc.tables.find(t => t.name === 'photo_versions').rows.push({ id: 'preview-version', photo_id: photo.id, name: '版本', recipe: '{}', rendered_path: '/foreign/rendered', created_at: 1 });
      const reference = { id: 'preview-reference', project_id: null, character_id: 'c', source_uri: 'test://reference', local_path: '/foreign/ref', thumbnail_path: '/foreign/ref-thumb', caption: '', created_at: 1 };
      doc.tables.find(t => t.name === 'reference_images').rows.push(reference);
      const preview = await backup.previewMetadata(JSON.stringify(doc));
      assert.equal(preview.mediaWithoutLocalPath, 2); assert.equal(preview.counts.find(row => row.table === 'photos').incoming, 1);
      assert.equal((await db.sql('SELECT count(*) FROM photos')).rows[0][0], 0);
      doc.tables.find(t => t.name === 'photos').rows.push({ ...photo, id: 'other-photo' });
      await assert.rejects(backup.previewMetadata(JSON.stringify(doc)), /重复的关联/);
      doc.tables.find(t => t.name === 'photos').rows.pop(); reference.project_id = 'positive';
      await assert.rejects(backup.previewMetadata(JSON.stringify(doc)), /必须且只能属于/);
    });
    await test('backup valid replacement rolls all tables back when the actual SQL write fails', async () => {
      await db.sql("UPDATE characters SET name='Before failed replacement'");
      db.failSql = 'INSERT INTO projects'; await assert.rejects(backup.restoreMetadata(exported), /injected write failure/); db.failSql = '';
      assert.equal((await db.sql('SELECT name FROM characters')).rows[0][0], 'Before failed replacement');
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4); await backup.restoreMetadata(exported);
    });
    await test('backup file export checks UTF-8 byte counts and closes files on complete and partial writes', async () => {
      const { BackupService: ActualBackupService } = require(root + '/common/BackupService.ets');
      const service = new ActualBackupService(db, {}); let closes = 0, output;
      backupFileControl = { save: () => ['test://export'], close: () => { closes++; }, write: (fd, bytes) => { output = Buffer.from(bytes); return bytes.byteLength; } };
      assert.equal(await service.export(), true); assert.equal(closes, 1); assert.equal(JSON.parse(output.toString('utf8')).version, 7);
      assert.equal(output.includes(Buffer.from('毛娘', 'utf8')), true);
      backupFileControl.write = (fd, bytes) => bytes.byteLength - 1;
      await assert.rejects(service.export(), /未完整写入/); assert.equal(closes, 2);
      backupFileControl.save = () => []; assert.equal(await service.export(), false); assert.equal(closes, 2);
    });
    await test('backup file selection reads chunks, closes files and only returns a validated preview', async () => {
      const { BackupService: ActualBackupService } = require(root + '/common/BackupService.ets');
      const service = new ActualBackupService(db, {}); let closes = 0;
      backupFileControl = { bytes: Buffer.from(exported), select: () => ['test://import'], close: () => { closes++; }, read: (fd, buffer, options) => { const part = backupFileControl.bytes.subarray(options.offset, options.offset + Math.min(buffer.byteLength, 127)); new Uint8Array(buffer).set(part); return part.length; } };
      const selection = await service.prepareRestore(); assert.equal(selection.input, exported); assert.equal(selection.preview.version, 7); assert.equal(closes, 1);
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
      backupFileControl.read = () => 0; await assert.rejects(service.prepareRestore(), /读取不完整/); assert.equal(closes, 2);
      backupFileControl.bytes = Buffer.from('bad json'); backupFileControl.read = (fd, buffer) => { new Uint8Array(buffer).set(backupFileControl.bytes); return backupFileControl.bytes.length; };
      await assert.rejects(service.prepareRestore()); assert.equal(closes, 3);
      backupFileControl.select = () => []; assert.equal(await service.prepareRestore(), undefined); backupFileControl = {};
    });
    await test('backup state selection and cancellation only stage validated input, export cancellation never records success', async () => {
      const state = new AppState(); state.context = {}; state.db = db; let replacements = 0;
      backupControl = { prepare: async () => ({ input: exported, preview: await backup.previewMetadata(exported) }), restore: async input => { replacements++; await backup.restoreMetadata(input); }, export: async () => false };
      assert.equal(await state.restoreData(), false); assert.equal(replacements, 0);
      assert.equal(await state.prepareRestoreData(), true); assert.ok(state.restorePreview); assert.equal(replacements, 0);
      assert.equal(await state.exportData(), false); assert.equal(state.lastMetadataExport, 0); assert.equal(state.notice, '');
      state.cancelRestoreData(); assert.equal(state.restorePreview, undefined); assert.equal(await state.restoreData(), false);
      backupControl.prepare = async () => undefined; assert.equal(await state.prepareRestoreData(), false); assert.equal(state.notice, '');
      backupControl.export = async () => true; failExportTime = true;
      assert.equal(await state.exportData(), true); assert.equal(state.lastOperation.status, 'partial'); assert.match(state.notice, /已导出/); assert.ok(state.lastMetadataExport);
      failExportTime = false; assert.equal(await state.exportData(), true); assert.equal(metadataExportTime, state.lastMetadataExport);
    });
    await test('backup committed replacement clears its input before refresh; reload never replays replacement', async () => {
      const state = new AppState(); state.context = {}; state.db = db; let writes = 0, refreshes = 0;
      backupControl = { prepare: async () => ({ input: exported, preview: await backup.previewMetadata(exported) }), restore: async input => { writes++; await backup.restoreMetadata(input); } };
      state.refresh = async () => { refreshes++; if (refreshes === 1) throw new Error('read unavailable'); };
      assert.equal(await state.prepareRestoreData(), true);
      assert.equal(await state.restoreData(), true); assert.equal(writes, 1); assert.equal(state.restorePreview, undefined);
      assert.equal(state.lastOperation.status, 'savedNotRefreshed'); assert.match(state.notice, /已替换恢复/);
      assert.equal(await state.restoreData(), false); assert.equal(writes, 1);
      assert.equal(await state.reloadRecords(), true); assert.equal(writes, 1); assert.equal(refreshes, 2);
    });
    await test('backup replacement failure preserves staged input and original records for explicit retry', async () => {
      const state = new AppState(); state.context = {}; state.db = db; state.refresh = async () => {};
      backupControl = { prepare: async () => ({ input: exported, preview: await backup.previewMetadata(exported) }), restore: async input => backup.restoreMetadata(input) };
      await state.prepareRestoreData(); db.failSql = 'INSERT INTO projects';
      assert.equal(await state.restoreData(), false); assert.ok(state.restorePreview); assert.equal(state.lastOperation.status, 'failed'); db.failSql = '';
      assert.equal((await db.sql('SELECT count(*) FROM projects')).rows[0][0], 4);
      assert.equal(await state.restoreData(), true); assert.equal(state.restorePreview, undefined); backupControl = {};
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
