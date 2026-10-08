import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppState } from '../model/ApplicationState';
import { CollectedEntry, ENTRY_KINDS, ENTRY_KIND_LABELS, ENTRY_SCOPES, ENTRY_SCOPE_LABELS, entryTitle } from '../model/CollectedEntry';
import { operationCommitted } from '../model/OperationResult';
import { Theme } from '../common/Theme';
import { today } from '../common/format';
import { appSheetOptions } from '../common/sheet';
import { StaggerEntrance } from '../common/motion';
import { confirm } from '../common/Confirm';
import { ManagedImage } from './ManagedImage';
import { SheetHeader } from './SheetHeader';
import { Field, EmptyState } from './Surfaces';

interface EntryOwner { id: string; name: string; }
@ComponentV2
export struct EntryCollection {
  @Require @Param state: AppState;
  @Param scopeKind: string = 'global';
  @Param initialKind: string = '';
  @Param untriagedOnly: boolean = true;
  @Param scopeId: string = '';
  @Event open: (kind: string, id: string) => void = () => {};
  @Local content: string = '';
  @Local kindFilter: string = '';
  @Local includeFiled: boolean = false;
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

  aboutToAppear(): void { this.kindFilter = this.initialKind; this.includeFiled = !this.untriagedOnly; }
  @Computed
  private get visible(): CollectedEntry[] {
    return this.state.entries.filter((entry: CollectedEntry) =>
      (this.scopeKind === 'global' ? this.includeFiled || entry.scopeKind === 'global' : entry.scopeKind === this.scopeKind && entry.scopeId === this.scopeId) && (!this.kindFilter || entry.kind === this.kindFilter));
  }
  private ownerName(entry: CollectedEntry): string {
    if (entry.scopeKind === 'project') { return this.state.projectName(entry.scopeId); }
    if (entry.scopeKind === 'character') { return this.state.characterName(entry.scopeId); }
    if (entry.scopeKind === 'event') { return this.state.events.find((event) => event.id === entry.scopeId)?.name || '活动已不存在'; }
    if (entry.scopeKind === 'asset') { return this.state.assets.find((asset) => asset.id === entry.scopeId)?.name || '装备已不存在'; }
    return '未归位';
  }
  private assignmentScopes(): string[] { return this.conversion === 'reference' ? ['project', 'character'] : ENTRY_SCOPES; }
  private owners(): EntryOwner[] {
    let owners: EntryOwner[] = [];
    if (this.targetKind === 'event') { owners = this.state.events.map((item): EntryOwner => ({ id: item.id, name: item.name })); }
    if (this.targetKind === 'project') { owners = this.state.projects.map((item): EntryOwner => ({ id: item.id, name: item.name })); }
    if (this.targetKind === 'character') { owners = this.state.characters.map((item): EntryOwner => ({ id: item.id, name: item.name })); }
    if (this.targetKind === 'asset') { owners = this.state.assets.map((item): EntryOwner => ({ id: item.id, name: item.name })); }
    return owners.filter((owner: EntryOwner) => owner.name.toLocaleLowerCase().includes(this.ownerQuery.toLocaleLowerCase()));
  }
  private async capture(value: string): Promise<void> {
    if (operationCommitted(await this.state.captureEntry(value, this.scopeKind, this.scopeId))) { if (value === this.content) { this.content = ''; } }
  }
  private async paste(): Promise<void> {
    if (this.state.busy) { return; }
    try { const data = await pasteboard.getSystemPasteboard().getData(); await this.capture(data.getPrimaryText()); }
    catch (error) { this.state.reportError('未能读取剪贴板，可以在输入框中手动粘贴后收录'); }
  }
  private begin(entry: CollectedEntry): void {
    if (this.scopeKind === 'global' && entry.scopeKind !== 'global') { this.open(entry.scopeKind, entry.scopeId); return; }
    this.entry = entry; this.title = entry.title; this.text = entry.text; this.url = entry.url; this.entryKind = entry.kind;
    this.pinned = entry.pinned; this.assigning = false; this.conversion = ''; this.targetId = ''; this.ownerQuery = ''; this.editing = true;
  }
  private editedEntry(): CollectedEntry {
    const entry = JSON.parse(JSON.stringify(this.entry)) as CollectedEntry;
    entry.title = this.title; entry.text = this.text; entry.url = this.url; entry.kind = this.entryKind; entry.pinned = this.pinned;
    return entry;
  }
  private hasChanges(): boolean {
    return this.title !== this.entry.title || this.text !== this.entry.text || this.url !== this.entry.url || this.entryKind !== this.entry.kind || this.pinned !== this.entry.pinned || (this.assigning && (Boolean(this.targetId) || Boolean(this.amount)));
  }
  private async canClose(): Promise<boolean> {
    if (this.state.busy) { return false; }
    return !this.hasChanges() || await confirm(this.getUIContext(), '放弃本次修改？', '已保存的收录会保留，本次未保存的修改将放弃。取消可继续编辑。', '放弃修改');
  }
  private async closeEditor(): Promise<void> { if (await this.canClose()) { this.editing = false; } }
  private sheetOptions(): SheetOptions {
    const options = appSheetOptions((): void => { this.editing = false; }, this.sheetEntrance, this.getUIContext());
    options.onWillDismiss = (action: DismissSheetAction): void => { this.canClose().then((allowed: boolean): void => { if (allowed) { action.dismiss(); } }); };
    return options;
  }
  private async save(): Promise<void> {
    if (operationCommitted(await this.state.saveEntry(this.editedEntry()))) { this.editing = false; }
  }
  private async assign(): Promise<void> {
    if (this.conversion) {
      if (operationCommitted(await this.state.convertEntry(this.editedEntry(), this.conversion, this.targetKind, this.targetId, this.amount, this.date))) { this.editing = false; }
    } else {
      const entry = this.editedEntry(); entry.scopeKind = this.targetKind; entry.scopeId = this.targetKind === 'global' ? '' : this.targetId;
      if (operationCommitted(await this.state.saveEntry(entry))) { this.editing = false; }
    }
  }
  private async remove(): Promise<void> {
    if (!await confirm(this.getUIContext(), '删除这条收录？', entryTitle(this.entry).slice(0, 80) + ' 的记录与应用内图片副本将删除，系统相册原图保留。', '删除')) { return; }
    if (operationCommitted(await this.state.removeEntry(this.entry))) { this.editing = false; }
  }
  private async repair(): Promise<void> {
    if (operationCommitted(await this.state.repairEntryImage(this.editedEntry()))) { this.editing = false; }
  }
  private async openLink(): Promise<void> {
    try { await (this.getUIContext().getHostContext() as common.UIAbilityContext).openLink(this.entry.url, { appLinkingOnly: false }); }
    catch (error) { this.state.reportError('未能打开链接，可复制链接后在浏览器打开'); }
  }
  @Builder assignment() {
    Select([{ value: '归位到对象' }, { value: '转为准备任务' }, { value: '转为花费' }, { value: '转为参考图' }])
      .value(this.conversion === 'task' ? '转为准备任务' : this.conversion === 'expense' ? '转为花费' : this.conversion === 'reference' ? '转为参考图' : '归位到对象')
      .enabled(!this.state.busy)
      .onSelect((index: number): void => { this.conversion = ['', 'task', 'expense', 'reference'][index]; this.targetKind = this.conversion ? 'project' : 'event'; this.targetId = ''; })
    if (!this.conversion || this.conversion === 'reference') {
      Select(this.assignmentScopes().map((scope: string): SelectOption => ({ value: ENTRY_SCOPE_LABELS[ENTRY_SCOPES.indexOf(scope)] })))
        .value(ENTRY_SCOPE_LABELS[ENTRY_SCOPES.indexOf(this.targetKind)]).enabled(!this.state.busy)
        .onSelect((index: number): void => { this.targetKind = this.assignmentScopes()[index]; this.targetId = ''; })
    }
    if (this.targetKind !== 'global') {
      TextInput({ placeholder: '搜索归属对象', text: this.ownerQuery }).onChange((value: string): void => { this.ownerQuery = value; }).accessibilityText('搜索归属对象')
      ForEach(this.owners(), (owner: EntryOwner) => {
        Button((this.targetId === owner.id ? '✓ ' : '') + owner.name).width('100%').constraintSize({ minHeight: 48 })
          .backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy)
          .onClick((): void => { this.targetId = owner.id; }).accessibilitySelected(this.targetId === owner.id)
      }, (owner: EntryOwner) => owner.id)
      if (this.owners().length === 0) { Text('没有匹配的对象，请更换搜索或先创建对象。').fontColor(Theme.muted) }
    }
    if (this.conversion === 'expense') {
      Field({ label: '金额（元）', value: this.amount, change: (value: string): void => { this.amount = value; } })
      Field({ label: '记账日期（YYYY-MM-DD）', value: this.date, change: (value: string): void => { this.date = value; } })
    }
    if (this.conversion) { Text('转换成功后，这条收录会移至目标功能；失败时原条目保留。').fontSize(13).fontColor(Theme.muted) }
    Button(this.state.busy ? '保存中…' : this.conversion ? '确认转换' : '确认归位')
      .width('100%').backgroundColor(Theme.brand).fontColor(Theme.onAccent)
      .enabled(!this.state.busy && (this.targetKind === 'global' || Boolean(this.targetId)))
      .onClick((): void => { this.assign(); })
  }
  @Builder editor() {
    Scroll() {
      Column({ space: 16 }) {
        SheetHeader({ title: this.assigning ? '整理收录' : '收录', hint: this.ownerName(this.entry), close: (): void => { this.closeEditor(); } })
        if (this.assigning) { this.assignment() }
        else {
          if (this.entry.localPath) { ManagedImage({ sourcePath: this.entry.localPath, large: true, label: entryTitle(this.entry), ratio: 1 }).width('100%').aspectRatio(1) }
          else if (['image','ticket','map'].includes(this.entry.kind) && !this.entry.text && !this.entry.url) { Text('图片副本缺失：元数据备份不包含图片。').fontColor(Theme.muted) }
          if (['image','ticket','map'].includes(this.entry.kind)) {
            Button('重新选图').enabled(!this.state.busy).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.repair(); })
          }
          Select(ENTRY_KIND_LABELS.map((label: string): SelectOption => ({ value: label }))).value(ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(this.entryKind)])
            .enabled(!this.state.busy).onSelect((index: number): void => { this.entryKind = ENTRY_KINDS[index]; })
          Field({ label: '标题（可选）', value: this.title, change: (value: string): void => { this.title = value; } })
          Field({ label: '链接（可选）', value: this.url, change: (value: string): void => { this.url = value; } })
          TextArea({ text: this.text, placeholder: '正文或想法（可选）' }).height(120).onChange((value: string): void => { this.text = value; })
          if (this.entry.url) {
            Text(this.entry.url).fontColor(Theme.accent).copyOption(CopyOptions.LocalDevice)
            Button('打开链接').onClick((): void => { this.openLink(); }).fontColor(Theme.accent).backgroundColor(Theme.tint)
          }
          Row({ space: 12 }) { Text('置顶').fontColor(Theme.ink); Toggle({ type: ToggleType.Switch, isOn: this.pinned }).enabled(!this.state.busy).onChange((value: boolean): void => { this.pinned = value; }) }
          Button(this.state.busy ? '保存中…' : '保存修改').width('100%').backgroundColor(Theme.brand).fontColor(Theme.onAccent).enabled(!this.state.busy).onClick((): void => { this.save(); })
          Button('归位或转换').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { this.assigning = true; this.targetKind = 'event'; this.targetId = ''; this.conversion = ''; })
          Button('删除收录').width('100%').fontColor(Theme.danger).backgroundColor(Theme.surface).enabled(!this.state.busy).onClick((): void => { this.remove(); })
        }
      }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
    }.height('100%').width('100%').backgroundColor(Theme.surface)
  }
  build() {
    Column({ space: 16 }) {
      TextArea({ text: this.content, placeholder: '粘贴链接或写一句话，直接收录' }).height(100).onChange((value: string): void => { this.content = value; }).accessibilityText('收录内容')
      Flex({ wrap: FlexWrap.Wrap }) {
        Button(this.state.busy ? '收录中…' : '收录').enabled(!this.state.busy && this.content.trim().length > 0).backgroundColor(Theme.brand).fontColor(Theme.onAccent)
          .onClick((): void => { this.capture(this.content); }).margin({ right: 8, bottom: 8 })
        PasteButton().onClick((_event: ClickEvent, result: PasteButtonOnClickResult): void => {
          if (result === PasteButtonOnClickResult.SUCCESS) { this.paste(); }
          else { this.state.reportError('未获粘贴授权，可以手动粘贴到输入框'); }
        })
        Button('存一张图').enabled(!this.state.busy).backgroundColor(Theme.tint).fontColor(Theme.accent)
          .onClick((): void => { this.state.captureEntryImage(this.scopeKind, this.scopeId); }).margin({ bottom: 8 })
      }.width('100%')
      if (this.scopeKind === 'global') {
        Select([{ value: '未归位' }, { value: '全部收录' }]).value(this.includeFiled ? '全部收录' : '未归位')
          .onSelect((index: number): void => { this.includeFiled = index === 1; })
        Text('未归位 ' + this.state.untriagedEntries.length + ' 条 · 归位可稍后处理').fontSize(13).fontColor(Theme.muted)
      }
      Select(new Array<SelectOption>({ value: '所有类型' }).concat(ENTRY_KIND_LABELS.map((label: string): SelectOption => ({ value: label }))))
        .value(this.kindFilter ? ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(this.kindFilter)] : '所有类型')
        .onSelect((index: number): void => { this.kindFilter = index === 0 ? '' : ENTRY_KINDS[index - 1]; })
      ForEach(this.visible, (entry: CollectedEntry) => {
        Button() {
          Row({ space: 12 }) {
            if (entry.thumbnailPath) { ManagedImage({ sourcePath: entry.thumbnailPath, label: entryTitle(entry) }).width(56).height(56) }
            Column({ space: 6 }) {
              Text((entry.pinned ? '置顶 · ' : '') + entryTitle(entry)).fontSize(16).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(ENTRY_KIND_LABELS[ENTRY_KINDS.indexOf(entry.kind)] + ' · ' + this.ownerName(entry)).fontSize(12).fontColor(Theme.muted)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('›').fontColor(Theme.muted)
          }.width('100%').padding(14)
        }.width('100%').backgroundColor(Theme.surface).constraintSize({ minHeight: 64 })
          .onClick((): void => { this.begin(entry); }).accessibilityText(entryTitle(entry) + '，' + this.ownerName(entry))
      }, (entry: CollectedEntry) => entry.id)
      if (this.visible.length === 0) { EmptyState({ title: this.kindFilter ? '没有匹配的收录' : '先存下，再慢慢整理', message: '上方可直接粘贴、写一句话或选择图片。', button: this.kindFilter ? '清除类型筛选' : '存一张图', action: (): void => { if (this.kindFilter) { this.kindFilter = ''; } else { this.state.captureEntryImage(this.scopeKind, this.scopeId); } } }) }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .bindSheet(this.editing, this.editor(), this.sheetOptions())
  }
}
