import { HapticService } from '../../ui/feedback/HapticService';
import { ContextRow } from '../common/ContextRow';
import { displayName, today } from '../../utils/format/format';
import { StatusPill, Field, EmptyState } from '../common/Surfaces';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppState } from '../../state/ApplicationState';
import { CollectedEntry, InboxRoute, filterCollectedEntries, ENTRY_KINDS, ENTRY_KIND_LABELS, ENTRY_SCOPES, ENTRY_SCOPE_LABELS, entryTitle } from '../../models/CollectedEntry';
import { operationCommitted } from '../../domain/operations/OperationResult';
import { Theme } from '../../ui/theme/Theme';
import { appSheetOptions, dismissSheet, registerInlineSheetBack, releaseInlineSheetBack } from '../../ui/sheet/sheet';
import { StaggerEntrance } from '../../ui/animation/motion';
import { confirm } from '../../ui/feedback/Confirm';
import { ManagedImage } from '../common/ManagedImage';
import { SheetHeader } from '../common/SheetHeader';
interface EntryOwner {
    id: string;
    name: string;
}

@ComponentV2
export struct EntryCollection {
    @Param embedded: boolean = false;
    @Event editingChanged: (editing: boolean) => void = () => {};
    private backOwner: string = 'entry:' + String(Date.now()) + ':' + String(Math.random());
    @Monitor('editing')
    private editorChanged(): void {
        this.editingChanged(this.editing);
        if (this.embedded && this.editing) {
            registerInlineSheetBack(this.backOwner, (): Promise<void> => this.closeEditor());
            this.sheetEntrance.play(this.getUIContext(), 3);
        } else {
            releaseInlineSheetBack(this.backOwner);
        }
    }

    aboutToDisappear(): void {
        releaseInlineSheetBack(this.backOwner);
        this.sheetEntrance.reset();
    }

    @Require @Param state: AppState;
    @Param route: InboxRoute = new InboxRoute();
    @Event open: (kind: string, id: string) => void = () => {};
    @Local captureError: string = '';
    @Local actionError: string = '';
    @Local editing: boolean = false;
    @Local entry: CollectedEntry = new CollectedEntry();
    @Local title: string = '';
    @Local text: string = '';
    @Local url: string = '';
    @Local entryKind: string = 'note';
    @Local pinned: boolean = false;
    @Local assigning: boolean = false;
    @Local targetKind: string = 'event';
    @Local targetId: string = '';
    @Local conversion: string = '';
    @Local amount: string = '';
    @Local date: string = today();
    @Local ownerQuery: string = '';
    @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
    @Computed
    private get visible(): CollectedEntry[] {
        return filterCollectedEntries(this.state.entries, this.route);
    }

    private ownerName(entry: CollectedEntry): string {
        if (entry.scopeKind === 'project') {
            return this.state.projectName(entry.scopeId);
        }
        if (entry.scopeKind === 'character') {
            return this.state.characterName(entry.scopeId);
        }
        if (entry.scopeKind === 'event') {
            return this.state.events.find((event) => event.id === entry.scopeId)?.name || '活动已不存在';
        }
        if (entry.scopeKind === 'asset') {
            return this.state.assets.find((asset) => asset.id === entry.scopeId)?.name || '装备已不存在';
        }
        return '未归位';
    }

    private assignmentScopes(): string[] {
        return this.conversion === 'reference' ? ['project', 'character'] : ENTRY_SCOPES;
    }

    private owners(): EntryOwner[] {
        let owners: EntryOwner[] = [];
        if (this.targetKind === 'event') {
            owners = this.state.events.map((item): EntryOwner => ({ id: item.id, name: item.name }));
        }
        if (this.targetKind === 'project') {
            owners = this.state.projects.map((item): EntryOwner => ({ id: item.id, name: item.name }));
        }
        if (this.targetKind === 'character') {
            owners = this.state.characters.map((item): EntryOwner => ({ id: item.id, name: item.name }));
        }
        if (this.targetKind === 'asset') {
            owners = this.state.assets.map((item): EntryOwner => ({ id: item.id, name: item.name }));
        }
        return owners.filter((owner: EntryOwner) => owner.name.toLocaleLowerCase().includes(this.ownerQuery.toLocaleLowerCase()));
    }

    private async capture(value: string): Promise<void> {
        this.captureError = '';
        const result = await this.state.captureEntry(value, this.route.scopeKind, this.route.scopeId);
        if (operationCommitted(result)) {
            if (value === this.route.content) {
                this.route.content = '';
            }
        } else {
            this.captureError = result.detail || '收录未保存，请重试';
        }
    }

    private async captureImage(): Promise<void> {
        this.captureError = '';
        const result = await this.state.captureEntryImage(this.route.scopeKind, this.route.scopeId);
        if (!operationCommitted(result)) {
            this.captureError = result.detail || '图片未收录，请重试';
        }
    }

    private async paste(): Promise<void> {
        if (this.state.busy) {
            return;
        }
        try {
            const data = await pasteboard.getSystemPasteboard().getData();
            await this.capture(data.getPrimaryText());
        } catch (error) {
            this.captureError = '未能读取剪贴板，可以在输入框中手动粘贴后收录';
            this.state.reportError(this.captureError);
        }
    }

    private begin(entry: CollectedEntry): void {
        this.route.anchorId = entry.id;
        if (this.route.scopeKind === 'global' && entry.scopeKind !== 'global') {
            this.open('inbox', entry.scopeKind + '|' + entry.scopeId);
            return;
        }
        this.actionError = '';
        this.entry = entry;
        this.title = entry.title;
        this.text = entry.text;
        this.url = entry.url;
        this.entryKind = entry.kind;
        this.pinned = entry.pinned;
        this.assigning = false;
        this.conversion = '';
        this.targetId = '';
        this.ownerQuery = '';
        this.editing = true;
    }

    private editedEntry(): CollectedEntry {
        const entry = JSON.parse(JSON.stringify(this.entry)) as CollectedEntry;
        entry.title = this.title;
        entry.text = this.text;
        entry.url = this.url;
        entry.kind = this.entryKind;
        entry.pinned = this.pinned;
        return entry;
    }

    private hasChanges(): boolean {
        return this.title !== this.entry.title || this.text !== this.entry.text || this.url !== this.entry.url || this.entryKind !== this.entry.kind || this.pinned !== this.entry.pinned || (this.assigning && (Boolean(this.targetId) || Boolean(this.amount)));
    }

    private async canClose(): Promise<boolean> {
        if (this.state.busy) {
            return false;
        }
        return !this.hasChanges() || await confirm(this.getUIContext(), '放弃本次修改？', '已保存的收录会保留，本次未保存的修改将放弃。取消可继续编辑。', '放弃修改');
    }

    private async closeEditor(): Promise<void> {
        if (await this.canClose()) {
            this.editing = false;
            if (this.embedded) {
                HapticService.back(this.state.settings.haptic);
            }
        }
    }

    private sheetOptions(): SheetOptions {
        const options = appSheetOptions((): void => {
            this.editing = false;
        }, this.sheetEntrance, this.getUIContext(), SheetSize.LARGE, (): Promise<boolean> => this.canClose(), (): void => {
            this.editing = false;
        });
        options.onWillDismiss = (action: DismissSheetAction): void => {
            void dismissSheet(action, (): Promise<boolean> => this.canClose());
        };
        return options;
    }

    private async save(): Promise<void> {
        this.actionError = '';
        const result = await this.state.saveEntry(this.editedEntry());
        if (operationCommitted(result)) {
            this.editing = false;
        } else {
            this.actionError = result.detail || '修改未保存，请重试';
        }
    }

    private async assign(): Promise<void> {
        this.actionError = '';
        const entry = this.editedEntry();
        if (!this.conversion) {
            entry.scopeKind = this.targetKind;
            entry.scopeId = this.targetKind === 'global' ? '' : this.targetId;
        }
        const result = this.conversion ? await this.state.convertEntry(entry, this.conversion, this.targetKind, this.targetId, this.amount, this.date) : await this.state.saveEntry(entry);
        if (operationCommitted(result)) {
            this.editing = false;
        } else {
            this.actionError = result.detail || '整理未保存，请重试';
        }
    }

    private async remove(): Promise<void> {
        if (!await confirm(this.getUIContext(), '删除这条收录？', entryTitle(this.entry).slice(0, 80) + ' 的记录与应用内图片副本将删除，系统相册原图保留。', '删除')) {
            return;
        }
        this.actionError = '';
        const result = await this.state.removeEntry(this.entry);
        if (operationCommitted(result)) {
            this.editing = false;
        } else {
            this.actionError = result.detail || '收录未删除，原条目保留';
        }
    }

    private async repair(): Promise<void> {
        if (this.state.busy) {
            return;
        }
        this.actionError = '';
        if (await this.state.repairEntryImage(this.editedEntry())) {
            this.editing = false;
        } else if (this.state.error) {
            this.actionError = this.state.error;
        }
    }

    @Builder failure() {
        if (this.actionError) {
            Text(this.actionError).id('entry-action-error').fontSize(14).fontColor(Theme.danger).accessibilityText(this.actionError)
        }
    }

    private async openLink(): Promise<void> {
        try {
            await (this.getUIContext().getHostContext() as common.UIAbilityContext).openLink(this.entry.url, { appLinkingOnly: false });
        } catch (error) {
            this.state.reportError('未能打开链接，可复制链接后在浏览器打开');
        }
    }

    @Builder assignment() {
        Select([{ value: '归位到对象' }, { value: '转为准备任务' }, { value: '转为花费' }, { value: '转为参考图' }])
            .value(this.conversion === 'task' ? '转为准备任务' : this.conversion === 'expense' ? '转为花费' : this.conversion === 'reference' ? '转为参考图' : '归位到对象')
            .enabled(!this.state.busy)
            .onSelect((index: number): void => {
                this.conversion = ['', 'task', 'expense', 'reference'][index];
                this.targetKind = this.conversion ? 'project' : 'event';
                this.targetId = '';
            })
        if (!this.conversion || this.conversion === 'reference') {
            Select(this.assignmentScopes().map((scope: string): SelectOption => ({ value: ENTRY_SCOPE_LABELS[ENTRY_SCOPES.indexOf(scope)] })))
                .value(ENTRY_SCOPE_LABELS[ENTRY_SCOPES.indexOf(this.targetKind)]).enabled(!this.state.busy)
                .onSelect((index: number): void => {
                    this.targetKind = this.assignmentScopes()[index];
                    this.targetId = '';
                })
        }
        if (this.targetKind !== 'global') {
            TextInput({ placeholder: '搜索归属对象', text: this.ownerQuery }).enabled(!this.state.busy).onChange((value: string): void => {
                this.ownerQuery = value;
            }).accessibilityText('搜索归属对象')
            ForEach(this.owners(), (owner: EntryOwner) => {
                Button((this.targetId === owner.id ? '✓ ' : '') + owner.name).width('100%').constraintSize({ minHeight: 48 })
                    .backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy)
                    .onClick((): void => {
                        this.targetId = owner.id;
                    }).accessibilitySelected(this.targetId === owner.id)
            }, (owner: EntryOwner) => owner.id)
            if (this.owners().length === 0) {
                Text('没有匹配的对象，请更换搜索或先创建对象。').fontColor(Theme.muted)
            }
        }
        if (this.conversion === 'expense') {
            Field({ label: '金额（元）', value: this.amount, change: (value: string): void => {
                    this.amount = value;
                }
            }).enabled(!this.state.busy)
            Field({ label: '记账日期（YYYY-MM-DD）', value: this.date, change: (value: string): void => {
                    this.date = value;
                }
            }).enabled(!this.state.busy)
        }
        if (this.conversion) {
            Text('转换成功后，这条收录会移至目标功能；失败时原条目保留。').fontSize(13).fontColor(Theme.muted)
        }
        this.failure()
        Button(this.state.busy ? '保存中…' : this.conversion ? '确认转换' : '确认归位')
            .width('100%').backgroundColor(Theme.brand).fontColor(Theme.onAccent)
            .enabled(!this.state.busy && (this.targetKind === 'global' || Boolean(this.targetId)))
            .onClick((): void => {
                this.assign();
            })
    }

    @Builder editorBody() {
        Column({ space: 16 }) {
            SheetHeader({ title: this.assigning ? '整理收录' : '收录', hint: this.ownerName(this.entry), close: (): void => {
                    this.closeEditor();
                }
            })
            if (this.assigning) {
                this.assignment()
            } else {
                if (this.entry.localPath) {
                    ManagedImage({ sourcePath: this.entry.localPath, large: true, label: entryTitle(this.entry), ratio: 1 }).width('100%').aspectRatio(1)
                } else if (['image','ticket','map'].includes(this.entry.kind) && !this.entry.text && !this.entry.url) {
                    Text('图片副本缺失：元数据备份不包含图片。').fontColor(Theme.muted)
                }
                if (['image','ticket','map'].includes(this.entry.kind)) {
                    Button('重新选图').enabled(!this.state.busy).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => {
                        this.repair();
                    })
                }
                Select(ENTRY_KIND_LABELS.map((label: string): SelectOption => ({ value: label })))
                    .value(ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(this.entryKind)])
                    .enabled(!this.state.busy).onSelect((index: number): void => {
                        this.entryKind = ENTRY_KINDS[index];
                    })
                Field({ label: '标题（可选）', value: this.title, change: (value: string): void => {
                        this.title = value;
                    }
                }).enabled(!this.state.busy)
                Field({ componentId: 'entry-input:url', label: '链接（可选）', value: this.url, change: (value: string): void => {
                        this.url = value;
                    }
                }).enabled(!this.state.busy)
                TextArea({ text: this.text, placeholder: '正文或想法（可选）' }).height(120).enabled(!this.state.busy).onChange((value: string): void => {
                    this.text = value;
                })
                if (this.entry.url) {
                    Text(this.entry.url).fontColor(Theme.accent).copyOption(CopyOptions.LocalDevice)
                    Button('打开链接').onClick((): void => {
                        this.openLink();
                    }).fontColor(Theme.accent).backgroundColor(Theme.tint)
                }
                Row({ space: 12 }) {
                    Text('置顶').fontColor(Theme.ink);
                    Toggle({ type: ToggleType.Switch, isOn: this.pinned }).enabled(!this.state.busy).onChange((value: boolean): void => {
                        this.pinned = value;
                    })
                }
                this.failure()
                Button(this.state.busy ? '保存中…' : '保存修改')
                    .width('100%')
                    .backgroundColor(Theme.brand)
                    .fontColor(Theme.onAccent)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        this.save();
                    })
                Button('归位或转换').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => {
                    this.assigning = true;
                    this.targetKind = 'event';
                    this.targetId = '';
                    this.conversion = '';
                })
                Button('删除收录')
                    .width('100%')
                    .fontColor(Theme.danger)
                    .backgroundColor(Theme.surface)
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        this.remove();
                    })
            }
        }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
    }

    @Builder editor() {
        if (this.embedded) {
            this.editorBody()
        } else {
            Scroll() {
                this.editorBody()
            }.id('entry-editor-scroll').height('100%').width('100%').backgroundColor(Theme.surface)
        }
    }

    @Builder collection() {
        Column({ space: 16 }) {
            TextArea({ text: this.route.content, placeholder: '粘贴链接或写一句话，直接收录' })
                .height(100)
                .enabled(!this.state.busy)
                .onChange((value: string): void => {
                    this.route.content = value;
                }).accessibilityText('收录内容')
            Flex({ wrap: FlexWrap.Wrap }) {
                Button(this.state.busy ? '收录中…' : '收录')
                    .enabled(!this.state.busy && this.route.content.trim().length > 0)
                    .backgroundColor(Theme.brand)
                    .fontColor(Theme.onAccent)
                    .onClick((): void => {
                        this.capture(this.route.content);
                    }).margin({ right: 8, bottom: 8 })
                PasteButton().onClick((_event: ClickEvent, result: PasteButtonOnClickResult): void => {
                    if (result === PasteButtonOnClickResult.SUCCESS) {
                        this.paste();
                    } else {
                        this.captureError = '未获粘贴授权，可以手动粘贴到输入框';
                        this.state.reportError(this.captureError);
                    }
                })
                Button('存一张图').enabled(!this.state.busy).backgroundColor(Theme.tint).fontColor(Theme.accent)
                    .onClick((): void => {
                        void this.captureImage();
                    }).margin({ bottom: 8 })
            }.width('100%')
            if (this.captureError) {
                Text(this.captureError).id('entry-capture-error').fontSize(14).fontColor(Theme.danger).accessibilityText(this.captureError)
            }
            if (this.route.scopeKind === 'global') {
                Select([{ value: '未归位' }, { value: '全部收录' }]).value(this.route.untriagedOnly ? '未归位' : '全部收录').id('entry-scope-filter')
                    .onSelect((index: number): void => {
                        this.route.setUntriagedOnly(index === 0);
                    })
                ContextRow({ label: '未归位', text: this.state.untriagedEntries.length + ' 条' })
            }
            Select(new Array<SelectOption>({ value: '所有类型' }).concat(ENTRY_KIND_LABELS.map((label: string): SelectOption => ({ value: label }))))
                .value(this.route.kind ? ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(this.route.kind)] : '所有类型').id('entry-kind-filter')
                .onSelect((index: number): void => {
                    this.route.setKind(index === 0 ? '' : ENTRY_KINDS[index - 1]);
                })
            if (this.route.feedback) {
                Text(this.route.feedback).fontSize(14).fontColor(Theme.muted)
            }
            ForEach(this.visible, (entry: CollectedEntry) => {
                Button() {
                    Row({ space: 12 }) {
                        if (entry.thumbnailPath) {
                            ManagedImage({ sourcePath: entry.thumbnailPath, label: entryTitle(entry) }).width(56).height(56)
                        }
                        Column({ space: 6 }) {
                            Row({ space: 8 }) {
                                if (entry.pinned) {
                                    StatusPill({ label: '置顶' })
                                }
                                Text(displayName(entryTitle(entry)))
                                    .fontSize(16)
                                    .fontColor(Theme.ink)
                                    .maxLines(2)
                                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                                    .layoutWeight(1)
                            }.width('100%')
                            ContextRow({ label: ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(entry.kind)], text: displayName(this.ownerName(entry)) })
                        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                        Text('›').fontColor(Theme.muted)
                    }.width('100%').padding(14)
                }.id('entry-row:' + entry.id).width('100%').backgroundColor(Theme.surface).constraintSize({ minHeight: 64 })
                    .onClick((): void => {
                        this.begin(entry);
                    }).accessibilityText(entryTitle(entry) + '，' + this.ownerName(entry))
            }, (entry: CollectedEntry) => entry.id)
            if (this.visible.length === 0) {
                EmptyState({ title: this.route.kind ? '没有匹配的收录' : '先存下，再慢慢整理', message: '上方可直接粘贴、写一句话或选择图片。', button: this.route.kind ? '清除类型筛选' : '存一张图', action: (): void => {
                        if (this.route.kind) {
                            this.route.setKind('');
                        } else {
                            void this.captureImage();
                        }
                    }
                })
            }
        }.width('100%').alignItems(HorizontalAlign.Start)
    }

    build() {
        if (this.embedded) {
            Column() {
                if (this.editing) {
                    this.editor()
                } else {
                    this.collection()
                }
            }.width('100%')
        } else {
            Column() {
                this.collection()
            }.width('100%')
                .bindSheet(this.editing, this.editor(), this.sheetOptions())
        }
    }
}
