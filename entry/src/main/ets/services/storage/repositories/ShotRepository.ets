import { relationalStore } from '@kit.ArkData';
import { ProjectShot } from '../../../models/Shot';
import { requiredName } from '../../../domain/plans/Rules';
import { Database, WriteTransaction } from '../database/Database';

export class ShotRepository {
    private db: Database;

    constructor(db: Database) {
        this.db = db;
    }

    async list(): Promise<ProjectShot[]> {
        const result: ProjectShot[] = [];
        let offset = 0;
        while (true) {
            const rows = await this.db.getStore()
                .querySql('SELECT * FROM project_shots ORDER BY project_id,sort_order,id LIMIT ? OFFSET ?', [500, offset]);
            let count = 0;
            try {
                while (rows.goToNextRow()) {
                    const shot = new ProjectShot();
                    shot.id = rows.getString(rows.getColumnIndex('id'));
                    shot.projectId = rows.getString(rows.getColumnIndex('project_id'));
                    shot.title = rows.getString(rows.getColumnIndex('title'));
                    shot.done = rows.getLong(rows.getColumnIndex('done')) === 1;
                    shot.referenceId = rows.getString(rows.getColumnIndex('reference_id'));
                    shot.sortOrder = rows.getLong(rows.getColumnIndex('sort_order'));
                    shot.createdAt = rows.getLong(rows.getColumnIndex('created_at'));
                    result.push(shot);
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
        return result;
    }

    async save(shot: ProjectShot, create: boolean): Promise<void> {
        const title = requiredName(shot.title);
        await this.db.transaction(async (tx: WriteTransaction): Promise<void> => {
            const rows = await this.db.getStore().querySql('SELECT project_id FROM project_shots WHERE id=?', [shot.id]);
            try {
                const exists = rows.goToNextRow();
                if (create && exists) {
                    throw new Error('拍摄事项已创建，请重新加载后查看');
                }
                if (!create && (!exists || rows.getString(0) !== shot.projectId)) {
                    throw new Error('拍摄事项已不存在或归属已变更');
                }
            } finally {
                rows.close();
            }
            const owner = await this.db.getStore().querySql('SELECT id FROM projects WHERE id=?', [shot.projectId]);
            try {
                if (!owner.goToNextRow()) {
                    throw new Error('所属计划已不存在');
                }
            } finally {
                owner.close();
            }
            if (create) {
                await tx.execute('INSERT INTO project_shots(id,project_id,title,done,reference_id,sort_order,created_at) SELECT ?,?,?,0,?,COALESCE(MAX(sort_order)+1,0),? FROM project_shots WHERE project_id=?', [shot.id, shot.projectId, title, shot.referenceId, shot.createdAt, shot.projectId]);
            } else {
                // Editing the description cannot undo a concurrent completion.
                await tx.execute('UPDATE project_shots SET title=?,reference_id=? WHERE id=? AND project_id=?', [title, shot.referenceId, shot.id, shot.projectId]);
            }
        });
    }

    async setDone(id: string, projectId: string, done: boolean, expected: boolean): Promise<void> {
        const changed = await this.db.getStore()
            .update({ done: done ? 1 : 0 }, new relationalStore.RdbPredicates('project_shots').equalTo('id', id).equalTo('project_id', projectId).equalTo('done', expected ? 1 : 0));
        if (changed !== 1) {
            throw new Error('拍摄事项已变更或不存在，请重新加载后继续');
        }
    }

    async remove(id: string, projectId: string): Promise<void> {
        await this.db.transaction(async (tx: WriteTransaction): Promise<void> => {
            const rows = await this.db.getStore().querySql('SELECT id FROM project_shots WHERE id=? AND project_id=?', [id, projectId]);
            try {
                if (!rows.goToNextRow()) {
                    throw new Error('拍摄事项已不存在');
                }
            } finally {
                rows.close();
            }
            await tx.execute('DELETE FROM project_shots WHERE id=? AND project_id=?', [id, projectId]);
        });
    }
}
