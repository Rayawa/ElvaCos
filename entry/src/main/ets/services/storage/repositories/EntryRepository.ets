import { Database, WriteTransaction } from '../database/Database';
import { CollectedEntry, validateEntry, entryTitle } from '../../../models/CollectedEntry';
import { PreparationCategory, PreparationTask } from '../../../models/Preparation';
import { Expense, ReferenceImage } from '../../../models/Planning';
import { moneyToCents, validDate } from '../../../domain/plans/Rules';

export function entryScopeTable(scope: string): string {
    if (scope === 'event') {
        return 'events';
    }
    if (scope === 'project') {
        return 'projects';
    }
    if (scope === 'character') {
        return 'characters';
    }
    if (scope === 'asset') {
        return 'assets';
    }
    throw new Error('收录归属无效');
}

export class EntryRepository {
    private db: Database;

    constructor(db: Database) {
        this.db = db;
    }

    async list(): Promise<CollectedEntry[]> {
        const entries: CollectedEntry[] = [];
        let offset = 0;
        while (true) {
            const rows = await this.db.getStore()
                .querySql('SELECT * FROM entries ORDER BY pinned DESC,created_at DESC,id LIMIT 500 OFFSET ?', [offset]);
            let count = 0;
            try {
                while (rows.goToNextRow()) {
                    const entry = new CollectedEntry();
                    entry.id = rows.getString(rows.getColumnIndex('id'));
                    entry.kind = rows.getString(rows.getColumnIndex('kind'));
                    entry.scopeKind = rows.getString(rows.getColumnIndex('scope_kind'));
                    entry.scopeId = rows.getString(rows.getColumnIndex('scope_id'));
                    entry.title = rows.getString(rows.getColumnIndex('title'));
                    entry.url = rows.getString(rows.getColumnIndex('url'));
                    entry.text = rows.getString(rows.getColumnIndex('text'));
                    entry.localPath = rows.getString(rows.getColumnIndex('local_path'));
                    entry.thumbnailPath = rows.getString(rows.getColumnIndex('thumbnail_path'));
                    entry.pinned = rows.getLong(rows.getColumnIndex('pinned')) === 1;
                    entry.createdAt = rows.getLong(rows.getColumnIndex('created_at'));
                    entries.push(entry);
                    count++;
                }
            } finally {
                rows.close();
            }
            if (count < 500) {
                break;
            }
            offset += count;
        }
        return entries;
    }

    async checkScope(scopeKind: string, scopeId: string): Promise<void> {
        if (scopeKind === 'global') {
            if (scopeId) {
                throw new Error('未归位收录不应有归属对象');
            }
            return;
        }
        const rows = await this.db.getStore().querySql('SELECT id FROM ' + entryScopeTable(scopeKind) + ' WHERE id=?', [scopeId]);
        try {
            if (rows.rowCount !== 1) {
                throw new Error('归属对象已不存在，请重新选择');
            }
        } finally {
            rows.close();
        }
    }

    async save(entry: CollectedEntry): Promise<void> {
        validateEntry(entry);
        await this.checkScope(entry.scopeKind, entry.scopeId);
        await this.db.getStore()
            .executeSql('INSERT INTO entries(id,kind,scope_kind,scope_id,title,url,text,local_path,thumbnail_path,pinned,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,scope_kind=excluded.scope_kind,scope_id=excluded.scope_id,title=excluded.title,url=excluded.url,text=excluded.text,local_path=excluded.local_path,thumbnail_path=excluded.thumbnail_path,pinned=excluded.pinned', [entry.id,entry.kind,entry.scopeKind,entry.scopeId,entry.title,entry.url,entry.text,entry.localPath,entry.thumbnailPath,entry.pinned ? 1 : 0,entry.createdAt]);
    }

    async remove(id: string): Promise<void> {
        await this.db.getStore().executeSql('DELETE FROM entries WHERE id=?', [id]);
    }
    // Conversions consume the source exactly once and commit the new object together.

    async convert(entry: CollectedEntry, kind: string, scopeKind: string, scopeId: string, amount: string, date: string): Promise<void> {
        validateEntry(entry);
        await this.checkScope(scopeKind, scopeId);
        if ((kind === 'task' || kind === 'expense') && scopeKind !== 'project') {
            throw new Error('请选择目标计划');
        }
        if (kind === 'reference' && !['project','character'].includes(scopeKind)) {
            throw new Error('参考图只能归属计划或角色');
        }
        if (!['task','expense','reference'].includes(kind)) {
            throw new Error('转换类型无效');
        }
        const name = entryTitle(entry).slice(0, 80);
        const cents = kind === 'expense' ? moneyToCents(amount) : 0;
        if (kind === 'expense' && !validDate(date)) {
            throw new Error('请选择记账日期');
        }
        if (kind === 'reference' && (!entry.localPath || !entry.thumbnailPath)) {
            throw new Error('参考图需要可用的本地图片，请先补入图片');
        }
        await this.db.transaction(async (tx: WriteTransaction) => {
            const source = await this.db.getStore().querySql('SELECT id FROM entries WHERE id=?', [entry.id]);
            try {
                if (source.rowCount !== 1) {
                    throw new Error('收录已变化，请重新加载');
                }
            } finally {
                source.close();
            }
            if (kind === 'task') {
                const category = new PreparationCategory();
                category.projectId = scopeId;
                category.name = '收录整理';
                const rows = await this.db.getStore()
                    .querySql("SELECT id FROM preparation_categories WHERE project_id=? AND name='收录整理'", [scopeId]);
                try {
                    if (rows.goToNextRow()) {
                        category.id = rows.getString(0);
                    } else {
                        await tx.execute('INSERT INTO preparation_categories(id,project_id,name,sort_order) VALUES(?,?,?,0)', [category.id,scopeId,category.name]);
                    }
                } finally {
                    rows.close();
                }
                const task = new PreparationTask();
                await tx.execute('INSERT INTO preparation_tasks(id,project_id,category_id,label,notes,sort_order) VALUES(?,?,?,?,?,0)', [task.id,scopeId,category.id,name,entry.text || entry.url]);
            } else if (kind === 'expense') {
                const expense = new Expense();
                await tx.execute('INSERT INTO expenses(id,project_id,name,category,amount_cents,date,notes,created_at) VALUES(?,?,?,?,?,?,?,?)', [expense.id,scopeId,name,'其他',cents,date,entry.text || entry.url,expense.createdAt]);
            } else {
                const reference = new ReferenceImage();
                await tx.execute('INSERT INTO reference_images(id,project_id,character_id,source_uri,local_path,thumbnail_path,caption,created_at) VALUES(?,?,?,?,?,?,?,?)', [reference.id,scopeKind === 'project' ? scopeId : null,scopeKind === 'character' ? scopeId : null,'entry://' + entry.id,entry.localPath,entry.thumbnailPath,entry.title || entry.text,reference.createdAt]);
            }
            await tx.execute('DELETE FROM entries WHERE id=?', [entry.id]);
        });
    }
}
