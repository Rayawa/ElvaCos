import { ReferenceImage } from '../model/Planning';
import { shotReferences } from '../model/Shot';
import { today } from '../common/format';
import {
  ASSET_STATUSES,
  ASSET_STATUS_LABELS,
  ASSET_TYPES,
  ASSET_TYPE_LABELS,
  DATE_MODES,
  DATE_MODE_LABELS,
  EVENT_TYPES,
  EXPENSE_CATEGORIES,
  PROJECT_LABELS,
  PROJECT_STATUSES,
  TEAM_ROLES,
  TIME_MODES,
  TIME_MODE_LABELS,
} from '../common/constants';
import { PressFeedback } from '../common/pressFeedback';
import { DateField } from './DateField';

import { CosProject } from '../model/Entities';
import { StaggerEntrance } from '../common/motion';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { formatTime } from '../common/format';
import { FormSession } from '../model/FormSession';
import { EditDraft, FormIssue } from '../model/EditDraft';
import { Character, CharacterVariant, CosEvent, ProjectStatus, AssetType, AssetStatus } from '../model/Entities';
import { SheetHeader } from './SheetHeader';
import { Field } from './Surfaces';
import { PreparationCategory } from '../model/Preparation';
import { PreparationTemplatePicker } from './PreparationTemplatePicker';

@ComponentV2
export struct FormEditor {
  @Param creationAction: string = '创建计划并开始准备';
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Require @Param state: AppState;
  @Require @Param draft: EditDraft;
  @Require @Param session: FormSession;
  @Event close: () => void = () => {};
  @Local issues: FormIssue[] = [];
  @Local formError: string = '';
  private scroller: Scroller = new Scroller();
  private positions: Map<string, number> = new Map();
  private viewportTop: number = 0;
  private viewportHeight: number = 0;
  private focusedField: string = '';
  private focusTimer: number = -1;
  private attempted: boolean = false;
  @Computed
  get draftValue(): string { return this.draft.fingerprint(); }
  @Monitor('draftValue')
  changed(): void {
    if (this.attempted) { this.issues = this.draft.issues(this.state); }
    if (!this.session.submitting) { this.session.changed(); }
  }
  aboutToDisappear(): void {
    if (this.focusTimer >= 0) { clearTimeout(this.focusTimer); this.focusTimer = -1; }
    void this.session.flush();
  }
  private issue(field: string): string { return this.issues.find((issue: FormIssue) => issue.field === field)?.message || ''; }
  private fieldArea(field: string, area: Area): void {
    try { this.positions.set(field, Number(area.globalPosition.y) - this.viewportTop + this.scroller.currentOffset().yOffset); } catch (error) {}
  }
  private reveal(field: string, requestFocus: boolean = false): void {
    const offset = this.positions.get(field);
    this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, (offset || 0) - 12), animation: false });
    if (requestFocus && field !== 'object') { try { this.getUIContext().getFocusController().requestFocus('form-input:' + field); } catch (error) {} }
  }
  private focus(field: string): void { this.focusedField = field; this.reveal(field); }
  private locateFirstError(): void {
    const field = this.issues[0]?.field || 'object';
    if (['variantId', 'eventId', 'shootingTime', 'money'].includes(field) && this.draft.kind === 'project') { this.draft.advanced = true; }
    if (this.focusTimer >= 0) { clearTimeout(this.focusTimer); }
    this.focusTimer = setTimeout((): void => { this.focusTimer = -1; this.reveal(field, true); }, 60);
  }
  @Builder fieldIssue(field: string) { if (this.issue(field)) { Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field)) } }
  private draftTime(value: number): string { const date = new Date(value); return formatTime(value) + ' ' + String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0'); }
  @Builder draftStatus() {
    if (!this.draft.exists(this.state)) { Text('记录已不存在，请关闭表单后返回有效页面。').fontSize(16).fontColor(Theme.danger) }
    if (this.session.loading) { Text('正在读取本地草稿…').fontSize(14).fontColor(Theme.muted) }
    if (this.session.pendingRestore) {
      Text('有 ' + this.draftTime(this.session.pendingRestore.savedAt) + ' 的未保存草稿').fontSize(16).fontColor(Theme.ink)
      Row({ space: 8 }) {
        Button('恢复草稿').id('form-restore-draft').constraintSize({ minHeight: 48 }).onClick((): void => { this.session.restore(); })
        Button('放弃草稿').id('form-discard-draft').constraintSize({ minHeight: 48 }).onClick((): void => { this.session.discardRecovery(); })
      }
    }
    if (this.session.recoveredAt) { Text('已恢复 ' + this.draftTime(this.session.recoveredAt) + ' 的草稿，尚未写入正式记录').fontSize(14).fontColor(Theme.muted) }
    if (this.session.sourceChanged) { Text('原记录已变更，请核对恢复内容后保存。').fontSize(14).fontColor(Theme.accent) }
    if (this.session.error) { Text(this.session.error).id('form-draft-error').fontSize(14).fontColor(Theme.danger) }
    else if (!this.session.pendingRestore && this.session.savedAt) { Text(this.session.saving ? '正在保存本地草稿…' : '本地草稿已保存').id('form-draft-status').fontSize(14).fontColor(Theme.muted) }
    if (!this.session.loading && !this.session.recoveryChecked) {
      Row({ space: 8 }) {
        Button('重试读取草稿').constraintSize({ minHeight: 48 }).onClick((): void => { this.session.initialize(this.state); })
        Button('跳过草稿，继续编辑').constraintSize({ minHeight: 48 }).onClick((): void => { this.session.ignoreRecovery(); })
      }
    }
  }
  @Event saved: (kind: string, id: string, created: boolean) => void = () => {};
  @Event done: () => void = () => {};
  private async save(): Promise<void> {
    if (this.state.busy || this.session.submitting || this.session.loading || !this.session.recoveryChecked || this.session.pendingRestore || this.state.staleScopes.length) { return; }
    this.attempted = true; this.formError = ''; this.issues = this.draft.issues(this.state);
    if (this.issues.length) { this.locateFirstError(); return; }
    const created = !this.draft.id; this.session.submitting = true;
    try {
      await this.session.flush();
      if (await this.draft.save(this.state)) {
        const cleaned = await this.session.finish(true, true);
        if (!cleaned) { this.state.reportNotice('记录已保存；对应草稿清理失败，下次打开会核对已保存记录。'); }
        this.done(); this.saved(this.draft.kind, this.draft.id, created);
        if (this.draft.kind === 'event' && this.draft.deviceCalendar) {
          const event = this.state.events.find((event: CosEvent) => event.id === this.draft.id);
          if (event && !this.state.staleScopes.length) { await this.state.addEventToCalendar(event); }
        }
      } else { this.formError = this.state.error || '记录未保存，请重试'; }
    } catch (error) { this.formError = (error as Error).message || '记录未保存，请重试'; this.state.reportError(this.formError); }
    finally { this.session.submitting = false; }
  }
  private nameHint(): string {
    if (this.draft.kind === 'shot') { return '例如：桥边回头、合影、道具特写'; }
    if (this.draft.kind === 'event') { return '例如：秋日漫展、外景拍摄'; }
    if (this.draft.kind === 'team') { return '例如：摄影小林'; }
    if (this.draft.kind === 'expense') { return '例如：摄影定金'; }
    if (this.draft.kind === 'variant') { return '例如：雪初音'; }
    if (this.draft.kind === 'asset') { return '例如：蓝色长假发'; }
    if (this.draft.kind === 'checklist') { return '例如：美瞳护理液'; }
    if (this.draft.kind === 'category') { return '例如：道具制作'; }
    if (this.draft.kind === 'preparation') { return '例如：试穿并确认尺寸'; }
    return '例如：初音未来';
  }
  private references(): ReferenceImage[] { const project = this.state.projects.find((item: CosProject) => item.id === this.draft.parentId); return project ? shotReferences(this.state.references, project) : []; }
  build() {
    Column({ space: 12 }) {
      SheetHeader({
        title: this.draft.title(), hint: '内容只保存在本机',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { if (!this.state.busy && !this.session.submitting) { this.close(); } },
      }).attributeModifier(this.entrance.group(1))
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.draftStatus()
          Column({ space: 18 }) {
          if (this.draft.kind !== 'project' && this.draft.kind !== 'reference' && this.draft.kind !== 'photo') { Field({ componentId: 'form-input:name', error: this.issue('name'), area: (area: Area): void => { this.fieldArea('name', area); }, focused: (): void => { this.focus('name'); },
              label: this.draft.kind === 'team' ? '姓名 / 称呼 *' : this.draft.kind === 'expense' ? '花费用途 *' : this.draft.kind === 'shot' ? '拍摄事项 *' : '名称 *',
              value: this.draft.name,
              placeholder: this.nameHint(),
              change: (v: string) => { this.draft.name = v; }
            }) }
          if (this.draft.kind === 'character') { Field({ componentId: 'form-input:work', error: this.issue('work'), area: (area: Area): void => { this.fieldArea('work', area); }, focused: (): void => { this.focus('work'); }, label: '所属作品', value: this.draft.work, change: (v: string) => { this.draft.work = v; } }) }
          if (this.draft.kind === 'project') {
            Text('这次想出谁？ *').fontColor(Theme.muted).fontSize(13)
            Select((this.draft.id ? new Array<SelectOption>() : new Array<SelectOption>({ value: '＋ 创建新角色' }))
              .concat(this.state.characters.map((c: Character): SelectOption => { return { value: c.name }; })))
              .value(this.draft.newCharacter ? '＋ 创建新角色' : this.state.characterName(this.draft.characterId))
              .onSelect((index: number) => {
                vibration.dotVibration();
                const previous = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId);
                const automatic = !this.draft.name || this.draft.name === previous + ' · 计划';
                this.draft.newCharacter = !this.draft.id && index === 0; this.draft.characterId = this.draft.newCharacter ? '' : this.state.characters[index - (this.draft.id ? 0 : 1)].id; this.draft.variantId = '';
                if (automatic && !this.draft.id) { const role = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId); this.draft.name = role ? role + ' · 计划' : ''; }
              }).accessibilityText('计划角色').visualEffect(this.feedback.effect('select-1')).compositingFilter(this.feedback.filter('select-1')).attributeModifier(this.feedback.control('select-1'))
              .id('form-input:characterId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('characterId', area); })
            this.fieldIssue('characterId')
            if (this.draft.newCharacter) {
              Field({ componentId: 'form-input:characterName', error: this.issue('characterName'), area: (area: Area): void => { this.fieldArea('characterName', area); }, focused: (): void => { this.focus('characterName'); }, label: '角色名称 *', value: this.draft.characterName, placeholder: '例如：初音未来', change: (v: string) => {
                const automatic = !this.draft.name || this.draft.name === this.draft.characterName + ' · 计划';
                this.draft.characterName = v; if (automatic) { this.draft.name = v ? v + ' · 计划' : ''; }
              } })
              Field({ componentId: 'form-input:work', error: this.issue('work'), area: (area: Area): void => { this.fieldArea('work', area); }, focused: (): void => { this.focus('work'); }, label: '所属作品（可选）', value: this.draft.work, change: (v: string) => { this.draft.work = v; } })
            }
            Field({ componentId: 'form-input:name', error: this.issue('name'), area: (area: Area): void => { this.fieldArea('name', area); }, focused: (): void => { this.focus('name'); },
              label: '计划名称 *',
              value: this.draft.name,
              placeholder: '例如：初音未来 · 秋日漫展',
              change: (v: string) => { this.draft.name = v; }
            })
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => { this.fieldArea('date', area); }, label: '目标日期（可选）',
              value: this.draft.date,
              optional: true,
              change: (v: string) => { this.draft.date = v; }
            })
            if (!this.draft.id) {
              Button(this.draft.preparationExpanded ? '收起准备模板' : '准备模板 · 已选 ' + this.draft.preparationKeys.length + ' 项')
                .accessibilityText(this.draft.preparationExpanded ? '收起准备模板' : '展开准备模板，已选择 ' + this.draft.preparationKeys.length + ' 项')
                .backgroundColor(Theme.tint)
                .fontColor(Theme.accent)
                .onClick((): void => { vibration.dotVibration(); this.draft.preparationExpanded = !this.draft.preparationExpanded; })
                  .visualEffect(this.feedback.effect('button-2'))
                  .compositingFilter(this.feedback.filter('button-2'))
                  .attributeModifier(this.feedback.control('button-2'))
              if (this.draft.preparationExpanded) { PreparationTemplatePicker({
                  keys: this.draft.preparationKeys,
                  mode: this.draft.preparationMode,
                  change: (keys: string[], mode: number): void => { this.draft.preparationKeys = keys; this.draft.preparationMode = mode; }
                }) }
            }
            Button(this.draft.advanced ? '收起更多设置' : '更多设置 · 版本、活动、拍摄、预算')
              .id('form-project-more').accessibilityText(this.draft.advanced ? '收起更多设置' : '展开角色版本、活动、拍摄时间与预算设置')
              .backgroundColor(Theme.tint)
              .fontColor(Theme.accent)
              .onClick(() => { vibration.dotVibration(); this.draft.advanced = !this.draft.advanced; })
              .visualEffect(this.feedback.effect('button-3'))
              .compositingFilter(this.feedback.filter('button-3'))
              .attributeModifier(this.feedback.control('button-3'))
            if (this.draft.advanced) {
            Text('角色版本').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不指定版本' })
              .concat(this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)
              .map((v: CharacterVariant): SelectOption => { return { value: v.name }; })))
              .value(this.draft.variantId ? this.state.variants.find((v: CharacterVariant) => v.id === this.draft.variantId && v.characterId === this.draft.characterId)?.name || '版本已不存在，请重新选择' : '不指定版本')
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.variantId = index === 0 ? '' : this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)[index - 1].id; })
                .accessibilityText('角色版本')
                .visualEffect(this.feedback.effect('select-4'))
                .compositingFilter(this.feedback.filter('select-4'))
                .attributeModifier(this.feedback.control('select-4'))
              .id('form-input:variantId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('variantId', area); })
            this.fieldIssue('variantId')
            Text('关联活动').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不关联活动' }).concat(this.state.events.map((e: CosEvent): SelectOption => { return { value: e.name }; })))
              .value(this.state.events.find((e: CosEvent) => e.id === this.draft.eventId)?.name || '不关联活动')
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.eventId = index === 0 ? '' : this.state.events[index - 1].id; })
                .accessibilityText('关联活动')
                .visualEffect(this.feedback.effect('select-5'))
                .compositingFilter(this.feedback.filter('select-5'))
                .attributeModifier(this.feedback.control('select-5'))
              .id('form-input:eventId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('eventId', area); })
            this.fieldIssue('eventId')
            Select(PROJECT_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.draft.status as ProjectStatus)])
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.status = PROJECT_STATUSES[index]; })
                .accessibilityText('计划状态')
                .visualEffect(this.feedback.effect('select-6'))
                .compositingFilter(this.feedback.filter('select-6'))
                .attributeModifier(this.feedback.control('select-6'))
            DateField({ componentId: 'form-input:shootingTime', error: this.issue('shootingTime'), area: (area: Area): void => { this.fieldArea('shootingTime', area); }, label: '拍摄 / 约拍开始时间（可选）', value: this.draft.shootingTime, time: true, optional: true, change: (value: string): void => { this.draft.shootingTime = value; } })
            Text('日期使用目标日期，否则使用活动开始日期；跨日拍摄请指定目标日期。日期未定时仅记录时刻。').fontSize(14).fontColor(Theme.muted)
            Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => { this.fieldArea('money', area); }, focused: (): void => { this.focus('money'); }, label: '预算（元，可留空；填 0 表示零预算）', value: this.draft.money, change: (v: string) => { this.draft.money = v; this.draft.budgetEdited = true; } })
            }
          }
          if (this.draft.kind === 'asset') {
            if (this.draft.parentId && !this.draft.id) { Text('保存后自动加入「' + this.state.projectName(this.draft.parentId) + '」和打包清单')
              .fontSize(13)
              .fontColor(Theme.accent) }
            Select(ASSET_TYPE_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.draft.type as AssetType)])
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.type = ASSET_TYPES[index]; })
                .accessibilityText('装备类型')
                .visualEffect(this.feedback.effect('select-7'))
                .compositingFilter(this.feedback.filter('select-7'))
                .attributeModifier(this.feedback.control('select-7'))
            Select(ASSET_STATUS_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.draft.status as AssetStatus)])
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.status = ASSET_STATUSES[index]; })
                .accessibilityText('装备状态')
                .visualEffect(this.feedback.effect('select-8'))
                .compositingFilter(this.feedback.filter('select-8'))
                .attributeModifier(this.feedback.control('select-8'))
            Field({ componentId: 'form-input:location', error: this.issue('location'), area: (area: Area): void => { this.fieldArea('location', area); }, focused: (): void => { this.focus('location'); }, label: '存放位置', value: this.draft.location, change: (v: string) => { this.draft.location = v; } })
            Field({ componentId: 'form-input:brand', error: this.issue('brand'), area: (area: Area): void => { this.fieldArea('brand', area); }, focused: (): void => { this.focus('brand'); }, label: '品牌 / 店铺', value: this.draft.brand, change: (v: string) => { this.draft.brand = v; } })
            Field({ componentId: 'form-input:size', error: this.issue('size'), area: (area: Area): void => { this.fieldArea('size', area); }, focused: (): void => { this.focus('size'); }, label: '尺码', value: this.draft.size, change: (v: string) => { this.draft.size = v; } })
            Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => { this.fieldArea('money', area); }, focused: (): void => { this.focus('money'); }, label: '购买价格（元）', value: this.draft.money, change: (v: string) => { this.draft.money = v; } })
            Field({ componentId: 'form-input:url', error: this.issue('url'), area: (area: Area): void => { this.fieldArea('url', area); }, focused: (): void => { this.focus('url'); },
              label: '购买链接',
              value: this.draft.url,
              placeholder: 'https://',
              change: (v: string) => { this.draft.url = v; }
            })
          }
          if (this.draft.kind === 'event') {
            Select(EVENT_TYPES.map((type: string): SelectOption => { return { value: type }; }))
              .value(this.draft.type)
              .onSelect((i: number): void => { vibration.dotVibration(); this.draft.type = EVENT_TYPES[i]; })
              .accessibilityText('活动类型')
              .visualEffect(this.feedback.effect('select-9'))
              .compositingFilter(this.feedback.filter('select-9'))
              .attributeModifier(this.feedback.control('select-9'))
              .id('form-input:type').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('type', area); })
            this.fieldIssue('type')
            Select(DATE_MODE_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(DATE_MODE_LABELS[DATE_MODES.indexOf(this.draft.dateMode)])
              .onSelect((i: number): void => {
                vibration.dotVibration(); this.draft.dateMode = DATE_MODES[i];
                if (i === 0) { this.draft.date = ''; this.draft.endDate = ''; this.draft.timeMode = 'none'; this.draft.startTime = ''; this.draft.endTime = ''; this.draft.reminderMinutes = -1; this.draft.deviceCalendar = false; }
                else { if (!this.draft.date) { this.draft.date = today(); } this.draft.endDate = i === 2 ? this.draft.endDate || this.draft.date : ''; }
              }).accessibilityText('活动日期模式').visualEffect(this.feedback.effect('select-10')).compositingFilter(this.feedback.filter('select-10')).attributeModifier(this.feedback.control('select-10'))
              .id('form-input:dateMode').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('dateMode', area); })
            this.fieldIssue('dateMode')
            if (this.draft.dateMode !== 'pending') {
              DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => { this.fieldArea('date', area); }, label: this.draft.dateMode === 'multiple' ? '开始日期 *' : '日期 *',
                value: this.draft.date,
                change: (v: string): void => { this.draft.date = v; }
              })
              if (this.draft.dateMode === 'multiple') { DateField({ componentId: 'form-input:endDate', error: this.issue('endDate'), area: (area: Area): void => { this.fieldArea('endDate', area); }, label: '结束日期 *',
                  value: this.draft.endDate,
                  change: (v: string): void => { this.draft.endDate = v; }
                }) }
              Select(TIME_MODE_LABELS.map((label: string): SelectOption => { return { value: label }; }))
                .value(TIME_MODE_LABELS[TIME_MODES.indexOf(this.draft.timeMode)])
                .onSelect((i: number): void => { vibration.dotVibration(); this.draft.timeMode = TIME_MODES[i]; if (i === 0) { this.draft.startTime = ''; this.draft.endTime = ''; } else { this.draft.startTime = this.draft.startTime || '09:00'; this.draft.endTime = i === 2 ? this.draft.endTime || '18:00' : ''; } })
                  .accessibilityText('活动时间模式')
                  .visualEffect(this.feedback.effect('select-11'))
                  .compositingFilter(this.feedback.filter('select-11'))
                  .attributeModifier(this.feedback.control('select-11'))
              .id('form-input:timeMode').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('timeMode', area); })
            this.fieldIssue('timeMode')
              if (this.draft.timeMode !== 'none') { DateField({ componentId: 'form-input:startTime', error: this.issue('startTime'), area: (area: Area): void => { this.fieldArea('startTime', area); }, label: '开始时间 *',
                  value: this.draft.startTime,
                  time: true,
                  change: (v: string): void => { this.draft.startTime = v; }
                }) }
              if (this.draft.timeMode === 'range') { DateField({ componentId: 'form-input:endTime', error: this.issue('endTime'), area: (area: Area): void => { this.fieldArea('endTime', area); }, label: '结束时间 *',
                  value: this.draft.endTime,
                  time: true,
                  change: (v: string): void => { this.draft.endTime = v; }
                }) }
              Row() {
                Text('同时添加到设备日历').fontColor(Theme.ink).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.draft.deviceCalendar })
                  .onChange((value: boolean): void => { vibration.dotVibration(); this.draft.deviceCalendar = value; })
                  .id('event-device-calendar')
                  .accessibilityText('保存后打开设备日历确认页')
                  .visualEffect(this.feedback.effect('toggle-12'))
                  .compositingFilter(this.feedback.filter('toggle-12'))
                  .attributeModifier(this.feedback.control('toggle-12'))
              }.width('100%')
              if (this.draft.deviceCalendar) { Text('保存活动后打开系统确认页；日历提醒默认提前 30 分钟，可修改。取消不影响应用内记录。').fontSize(12).fontColor(Theme.muted) }
              Text('应用内提醒').fontSize(13).fontColor(Theme.muted)
              Select([{ value: '不提醒' }, { value: '开始时' }, { value: '提前 30 分钟' }, { value: '提前 1 小时' }, { value: '提前 1 天' }])
                .value(['不提醒', '开始时', '提前 30 分钟', '提前 1 小时', '提前 1 天'][[-1, 0, 30, 60, 1440].indexOf(this.draft.reminderMinutes)])
                .onSelect((i: number): void => { vibration.dotVibration(); this.draft.reminderMinutes = [-1, 0, 30, 60, 1440][i]; })
                  .accessibilityText('活动提醒')
                  .visualEffect(this.feedback.effect('select-13'))
                  .compositingFilter(this.feedback.filter('select-13'))
                  .attributeModifier(this.feedback.control('select-13'))
              .id('form-input:reminderMinutes').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('reminderMinutes', area); })
            this.fieldIssue('reminderMinutes')
              if (this.draft.reminderMinutes >= 0) { Text('保存时申请通知授权；未标记时间的活动按当天 09:00 提醒。').fontSize(12).fontColor(Theme.muted) }
            }
            Field({ componentId: 'form-input:city', error: this.issue('city'), area: (area: Area): void => { this.fieldArea('city', area); }, focused: (): void => { this.focus('city'); }, label: '城市', value: this.draft.city, change: (v: string) => { this.draft.city = v; } })
            Field({ componentId: 'form-input:venue', error: this.issue('venue'), area: (area: Area): void => { this.fieldArea('venue', area); }, focused: (): void => { this.focus('venue'); }, label: '场馆', value: this.draft.venue, change: (v: string) => { this.draft.venue = v; } })
            Field({ componentId: 'form-input:url', error: this.issue('url'), area: (area: Area): void => { this.fieldArea('url', area); }, focused: (): void => { this.focus('url'); },
              label: '官方 / 售票链接',
              value: this.draft.url,
              placeholder: 'https://',
              change: (v: string) => { this.draft.url = v; }
            })
            Select([{ value: '想去' }, { value: '计划参加' }, { value: '已参加' }])
              .value(this.draft.status === 'Wishlist' ? '想去' : this.draft.status === 'Attended' ? '已参加' : '计划参加')
              .onSelect((i: number) => { vibration.dotVibration(); this.draft.status = ['Wishlist','Planned','Attended'][i]; })
                .accessibilityText('活动参与状态')
                .visualEffect(this.feedback.effect('select-14'))
                .compositingFilter(this.feedback.filter('select-14'))
                .attributeModifier(this.feedback.control('select-14'))
            Row() { Text('已购票')
              .fontColor(Theme.ink)
              .layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.draft.ticket })
              .onChange((v: boolean) => { vibration.dotVibration(); this.draft.ticket = v; })
              .accessibilityText('已购票')
              .visualEffect(this.feedback.effect('toggle-15'))
              .compositingFilter(this.feedback.filter('toggle-15'))
              .attributeModifier(this.feedback.control('toggle-15')) }.width('100%')
          }
          if (this.draft.kind === 'team') {
            Text('分工').fontSize(13).fontColor(Theme.muted)
            Select(TEAM_ROLES.map((role: string): SelectOption => { return { value: role }; })).value(this.draft.type)
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.type = TEAM_ROLES[index]; })
                .accessibilityText('团队分工')
                .visualEffect(this.feedback.effect('select-16'))
                .compositingFilter(this.feedback.filter('select-16'))
                .attributeModifier(this.feedback.control('select-16'))
            Field({ componentId: 'form-input:type', error: this.issue('type'), area: (area: Area): void => { this.fieldArea('type', area); }, focused: (): void => { this.focus('type'); },
              label: '分工（可自定义） *',
              value: this.draft.type,
              placeholder: '例如：道具师、同行伙伴',
              change: (value: string): void => { this.draft.type = value; }
            })
            Text('填写本机称呼和联络备注，不会访问通讯录或向对方发送消息。').fontSize(12).fontColor(Theme.muted)
          }
          if (this.draft.kind === 'expense') {
            Text('所属计划 *').fontSize(13).fontColor(Theme.muted)
            Select(this.state.projects.map((p: CosProject): SelectOption => { return { value: p.name }; })).value(this.draft.parentId ? this.state.projectName(this.draft.parentId) : '请选择计划')
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.parentId = this.state.projects[index].id; })
                .enabled(!this.draft.id)
                .accessibilityText('花费计划')
                .visualEffect(this.feedback.effect('select-17'))
                .compositingFilter(this.feedback.filter('select-17'))
                .attributeModifier(this.feedback.control('select-17'))
              .id('form-input:parentId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('parentId', area); })
            this.fieldIssue('parentId')
            Select(EXPENSE_CATEGORIES.map((category: string): SelectOption => { return { value: category }; })).value(this.draft.type)
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.type = EXPENSE_CATEGORIES[index]; })
                .accessibilityText('花费分类')
                .visualEffect(this.feedback.effect('select-18'))
                .compositingFilter(this.feedback.filter('select-18'))
                .attributeModifier(this.feedback.control('select-18'))
            Field({ componentId: 'form-input:money', error: this.issue('money'), area: (area: Area): void => { this.fieldArea('money', area); }, focused: (): void => { this.focus('money'); },
              label: '实际花费（元） *',
              value: this.draft.money,
              placeholder: '例如：129.90',
              change: (v: string): void => { this.draft.money = v; }
            })
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => { this.fieldArea('date', area); }, label: '付款日期 *', value: this.draft.date, change: (v: string): void => { this.draft.date = v; } })
          }
          if (this.draft.kind === 'preparation') {
            Text('准备分类 *').fontColor(Theme.muted).fontSize(13)
            Select(this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId)
              .map((c: PreparationCategory): SelectOption => { return { value: c.name }; }))
              .value(this.state.preparationCategories.find((c: PreparationCategory) => c.id === this.draft.categoryId)?.name || '请选择分类')
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.categoryId = this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId)[index].id; })
                .accessibilityText('任务分类')
                .visualEffect(this.feedback.effect('select-19'))
                .compositingFilter(this.feedback.filter('select-19'))
                .attributeModifier(this.feedback.control('select-19'))
              .id('form-input:categoryId').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => { this.fieldArea('categoryId', area); })
            this.fieldIssue('categoryId')
            DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => { this.fieldArea('date', area); }, label: '截止日期（可选）',
              value: this.draft.date,
              optional: true,
              change: (v: string): void => { this.draft.date = v; }
            })
            Field({ componentId: 'form-input:waitingOn', error: this.issue('waitingOn'), area: (area: Area): void => { this.fieldArea('waitingOn', area); }, focused: (): void => { this.focus('waitingOn'); }, label: '等待对象（可选）', value: this.draft.waitingOn, placeholder: '例如：快递、妆娘排期、摄影师返图', change: (value: string): void => { this.draft.waitingOn = value; } })
            DateField({ componentId: 'form-input:waitingUntil', error: this.issue('waitingUntil'), area: (area: Area): void => { this.fieldArea('waitingUntil', area); }, label: '等待至（可选）', value: this.draft.waitingUntil, optional: true, change: (value: string): void => { this.draft.waitingUntil = value; } })
            Text('填写任一等待字段后，未完成任务会归入「在途」，不计入逾期。清空两项可回到待办。').fontSize(13).fontColor(Theme.muted)
          }
          if (this.draft.kind === 'shot') {
            Text('参考图（可选）').fontSize(14).fontColor(Theme.muted)
            Select(new Array<SelectOption>({ value: '不关联参考图' }).concat(this.references().map((reference: ReferenceImage): SelectOption => { return { value: (reference.caption || '参考图') + (reference.projectId ? ' · 此计划' : ' · 此角色') }; })))
              .value(this.draft.referenceId ? (this.references().find((reference: ReferenceImage) => reference.id === this.draft.referenceId)?.caption || (this.references().some((reference: ReferenceImage) => reference.id === this.draft.referenceId) ? '参考图' : '参考图已不存在，请重新选择')) : '不关联参考图')
              .constraintSize({ minHeight: 48 }).id('form-input:referenceId').accessibilityText('拍摄参考图')
              .onSelect((index: number): void => { this.draft.referenceId = index === 0 ? '' : this.references()[index - 1].id; })
              .onAreaChange((_, area: Area): void => { this.fieldArea('referenceId', area); })
            this.fieldIssue('referenceId')
            Text('拍摄勾选独立于准备任务、装包与照片处理状态。').fontSize(14).fontColor(Theme.muted)
          }
          if (this.draft.kind !== 'shot' && this.draft.kind !== 'category' && this.draft.kind !== 'checklist' && (this.draft.kind !== 'project' || this.draft.advanced)) { Field({ componentId: 'form-input:notes', error: this.issue('notes'), area: (area: Area): void => { this.fieldArea('notes', area); }, focused: (): void => { this.focus('notes'); },
              multilineLimit: this.draft.kind === 'photo' ? 20000 : 2000, label: this.draft.kind === 'photo' ? '照片说明' : this.draft.kind === 'reference' ? '图片说明' : '备注',
              value: this.draft.notes,
              multiline: true,
              change: (v: string) => { this.draft.notes = v; }
            }) }
          }.width('100%').alignItems(HorizontalAlign.Start).enabled(!this.session.loading && this.session.recoveryChecked && !this.session.pendingRestore && this.draft.exists(this.state))
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }.id('form-scroll').layoutWeight(1).width('100%').align(Alignment.Top).enabled(!this.state.busy && !this.session.submitting).attributeModifier(this.entrance.group(2))
        .onAreaChange((_, area: Area): void => {
          this.viewportTop = Number(area.globalPosition.y); const height = Number(area.height);
          if (this.viewportHeight && height !== this.viewportHeight && this.focusedField) { this.reveal(this.focusedField); }
          this.viewportHeight = height;
        })
      if (this.formError || this.issues.length) {
        Text(this.formError || this.issues[0].message).id('form-error').fontSize(14).fontColor(Theme.danger)
          .accessibilityText(this.formError || this.issues[0].message)
      }
      Button(this.state.busy || this.session.submitting ? '保存中…' : this.draft.kind === 'project' && !this.draft.id ? this.creationAction : '保存')
        .accessibilityText(this.state.busy || this.session.submitting ? '正在保存' : this.draft.kind === 'project' && !this.draft.id ? this.creationAction : '保存表单')
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .backgroundColor(Theme.brand)
        .fontColor(Theme.onAccent)
        .enabled(!this.state.busy && !this.session.submitting && !this.session.loading && this.session.recoveryChecked && !this.session.pendingRestore && !this.state.staleScopes.length && this.draft.exists(this.state))
        .id('form-submit').onClick(() => { vibration.dotVibration(); this.save(); })
        .visualEffect(this.feedback.effect('button-20'))
        .compositingFilter(this.feedback.filter('button-20'))
        .attributeModifier(this.feedback.control('button-20'))
        .opacity(this.entrance.step >= 3 ? 1 : 0)
        .translate({ y: this.entrance.step >= 3 ? 0 : 20 })
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
  }
}
