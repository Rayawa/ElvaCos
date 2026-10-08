#!/usr/bin/env node
// Execute the actual pure ArkTS models on the host. Native APIs are covered by
// the Harmony build and optional device suites; this runner stubs identity only.
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
  if (id === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: 26, distributionOSApiVersion: 60100 } };
  return originalLoad.call(this, id, parent, isMain);
};
global.$r = name => name;
require.extensions['.ets'] = function (module, filename) {
  const source = fs.readFileSync(filename, 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
  module._compile(output, filename);
};
const root = path.resolve(__dirname, '../entry/src/main/ets');
const entities = require(root + '/model/Entities.ets');
const { CosProject, ProjectStatus, Asset, AssetStatus, ProjectAsset, ChecklistItem, PhotoAsset, PhotoStatus, CosEvent } = entities;
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
  await test('all photo surfaces share six disjoint stages and final includes published', () => {
    const distribution = photoDistribution(photos); assert.deepEqual(distribution.map(g => g.value), read().photos.byStage);
    assert.equal(distribution.reduce((sum, g) => sum + g.value, 0), 8); assert.equal(photoStage(photos, 4).length, 2);
    assert.equal(photoStage(photos, 5)[0].status, PhotoStatus.RETOUCHED); assert.equal(photoStage(photos, 6)[0].status, PhotoStatus.ARCHIVED);
    assert.equal(portfolioStage(photos, 1).length, 2); assert.equal(portfolioStage(photos, 2)[0].status, PhotoStatus.PUBLISHED);
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
    const { MetadataBackupRepository } = require(root + '/data/repository/MetadataBackupRepository.ets');
    const backup = new MetadataBackupRepository(db);
    const exported = await backup.exportMetadata();
    await test('current backup round trip preserves explicit zero, unset and unknown budgets', async () => {
      assert.equal(JSON.parse(exported).version, 5); await backup.restoreMetadata(exported);
      assert.deepEqual((await db.sql('SELECT id,budget_cents,budget_configured FROM projects ORDER BY id')).rows, [['positive',1234,1], ['unknown',0,null], ['unset',0,0], ['zero',0,1]]);
    });
    await test('v1, v2 and v3 backups infer positive budgets but preserve historical zero as unknown', async () => {
      for (const version of [1,2,3]) {
        const doc = JSON.parse(exported); doc.version = version; doc.tables = doc.tables.slice(0, version === 1 ? 10 : version === 2 ? 12 : 15);
        for (const row of doc.tables.find(t => t.name === 'projects').rows) delete row.budget_configured;
        await backup.restoreMetadata(JSON.stringify(doc));
        assert.deepEqual((await db.sql('SELECT id,budget_configured FROM projects ORDER BY id')).rows, [['positive',1], ['unknown',null], ['unset',null], ['zero',null]]);
      }
    });
    await test('v4 backup retains budget flags and defaults the new entries table to empty', async () => {
      const doc = JSON.parse(exported); doc.version = 4; doc.tables = doc.tables.slice(0,15); await backup.restoreMetadata(JSON.stringify(doc));
      assert.deepEqual((await db.sql('SELECT id,budget_configured FROM projects ORDER BY id')).rows, [['positive',1], ['unknown',null], ['unset',0], ['zero',1]]);
      assert.equal((await db.sql('SELECT count(*) FROM entries')).rows[0][0], 0);
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
      assert.equal((await db.sql('SELECT count(*) FROM preparation_tasks')).rows[0][0],1); assert.equal((await entries.list()).length,0);
      await assert.rejects(entries.convert(note,'task','project','zero','','2026-10-08'), /已变化/);
      assert.equal((await db.sql('SELECT count(*) FROM preparation_tasks')).rows[0][0],1);
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
