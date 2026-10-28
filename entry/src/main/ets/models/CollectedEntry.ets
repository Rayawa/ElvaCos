import { newId, ManagedMedia } from './Entities';
import { safeUrl } from '../domain/plans/Rules';

export const ENTRY_KINDS: string[] = ['link', 'ticket', 'map', 'note', 'idea', 'image'];

export const ENTRY_KIND_LABELS: string[] = ['链接', '票', '地图', '笔记', '想法', '图片'];

export const ENTRY_SCOPES: string[] = ['global', 'event', 'project', 'character', 'asset'];

export const ENTRY_SCOPE_LABELS: string[] = ['未归位', '活动', '计划', '角色', '装备'];

export class CollectedEntry implements ManagedMedia {
    id: string = newId();
    kind: string = 'note';
    scopeKind: string = 'global';
    scopeId: string = '';
    title: string = '';
    url: string = '';
    text: string = '';
    localPath: string = '';
    thumbnailPath: string = '';
    pinned: boolean = false;
    createdAt: number = Date.now();
}

@ObservedV2
export class InboxRoute {
    @Trace kind: string = '';
    scopeKind: string = 'global';
    scopeId: string = '';
    @Trace untriagedOnly: boolean = true;
    @Trace content: string = '';
    @Trace restoreVersion: number = 0;
    @Trace feedback: string = '';
    offset: number = 0;
    anchorId: string = '';

    setKind(kind: string): void {
        if (kind && !ENTRY_KINDS.includes(kind) || this.kind === kind) {
            return;
        }
        this.kind = kind;
        this.resetPosition();
    }

    setUntriagedOnly(value: boolean): void {
        if (this.untriagedOnly === value) {
            return;
        }
        this.untriagedOnly = value;
        this.resetPosition();
    }

    private resetPosition(): void {
        this.offset = 0;
        this.anchorId = '';
        this.feedback = '';
        this.restoreVersion++;
    }

    reconcile(entries: CollectedEntry[]): void {
        if (this.anchorId && !filterCollectedEntries(entries, this).some((entry: CollectedEntry) => entry.id === this.anchorId)) {
            this.anchorId = '';
            this.feedback = '原收录已不在当前范围，保留筛选与附近位置。';
        }
    }

    constructor(scopeKind: string = 'global', scopeId: string = '') {
        this.scopeKind = scopeKind;
        this.scopeId = scopeId;
    }
}

export function entryFromText(value: string, scopeKind: string = 'global', scopeId: string = ''): CollectedEntry {
    const entry = new CollectedEntry();
    const content = value.trim();
    if (!content) {
        throw new Error('粘贴一个链接、写一句话，或选择图片即可收录');
    }
    entry.scopeKind = scopeKind;
    entry.scopeId = scopeId;
    if (/^https?:\/\/[^\s]+$/i.test(content)) {
        entry.kind = 'link';
        entry.url = safeUrl(content);
    } else {
        entry.text = content;
    }
    return entry;
}

export function entryTitle(entry: CollectedEntry): string {
    return entry.title || entry.text || entry.url || ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(entry.kind)] || '收录';
}

export function validateEntry(entry: CollectedEntry, restored: boolean = false): void {
    if (!ENTRY_KINDS.includes(entry.kind) || !ENTRY_SCOPES.includes(entry.scopeKind)) {
        throw new Error('收录类型或归属无效');
    }
    if ((entry.scopeKind === 'global') !== (entry.scopeId === '')) {
        throw new Error('请选择有效的收录归属');
    }
    entry.url = safeUrl(entry.url);
    if (entry.title.length > 80 || entry.text.length > 20000) {
        throw new Error('标题最多 80 字，正文最多 20000 字');
    }
    if (!restored && !entry.url && !entry.text.trim() && !entry.localPath) {
        throw new Error('收录内容为空，请写一句话或选择图片');
    }
}
/** One query serves standalone and owner-scoped collection views. */

export function filterCollectedEntries(entries: CollectedEntry[], route: InboxRoute): CollectedEntry[] {
    return entries.filter((entry: CollectedEntry) =>
        (route.scopeKind === 'global' ? !route.untriagedOnly || entry.scopeKind === 'global' : entry.scopeKind === route.scopeKind && entry.scopeId === route.scopeId) &&
        (!route.kind || entry.kind === route.kind));
}
