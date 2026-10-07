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
import { EditDraft } from '../model/EditDraft';
import { Character, CharacterVariant, CosEvent, ProjectStatus, AssetType, AssetStatus } from '../model/Entities';
import { SheetHeader } from './SheetHeader';
import { Field } from './Surfaces';
import { PreparationCategory } from '../model/Preparation';
import { PreparationTemplatePicker } from './PreparationTemplatePicker';

@ComponentV2
export struct FormEditor {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Require @Param state: AppState;
  @Param draft: EditDraft = new EditDraft();
  @Event saved: (kind: string, id: string, created: boolean) => void = () => {};
  @Event done: () => void = () => {};
  private async save(): Promise<void> {
    const created = !this.draft.id;
    try { if (await this.draft.save(this.state)) {
      this.done(); this.saved(this.draft.kind, this.draft.id, created);
      if (this.draft.kind === 'event' && this.draft.deviceCalendar) {
        const event = this.state.events.find((event: CosEvent) => event.id === this.draft.id);
        if (event) { await this.state.addEventToCalendar(event); }
      }
    } }
    catch (error) { this.state.reportError((error as Error).message); }
  }
  private nameHint(): string {
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
  build() {
    Column({ space: 12 }) {
      SheetHeader({
        title: this.draft.title(), hint: '内容只保存在本机',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { if (!this.state.busy) { this.done(); } },
      }).attributeModifier(this.entrance.group(1))
      Scroll() {
        Column({ space: 18 }) {
          if (this.draft.kind !== 'project' && this.draft.kind !== 'reference') { Field({
              label: this.draft.kind === 'team' ? '姓名 / 称呼 *' : this.draft.kind === 'expense' ? '花费用途 *' : '名称 *',
              value: this.draft.name,
              placeholder: this.nameHint(),
              change: (v: string) => { this.draft.name = v; }
            }) }
          if (this.draft.kind === 'character') { 
          Field({ label: '所属作品', value: this.draft.work, change: (v: string) => { 
            this.draft.work = v; } }) }
          if (this.draft.kind === 'project') {
            Text('这次想出谁？ *').fontColor(Theme.muted).fontSize(13)
            Select((this.draft.id ? new Array<SelectOption>() : new Array<SelectOption>({ value: '＋ 创建新角色' }))
              .concat(this.state.characters.map((c: Character): SelectOption => { return { value: c.name }; })))
              .value(this.draft.newCharacter ? '＋ 创建新角色' : this.state.characterName(this.draft.characterId))
              .onSelect((index: number) => {
                vibration.dotVibration();
                const previous = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId);
                const automatic = !this.draft.name || this.draft.name === previous + ' · Cos 计划';
                this.draft.newCharacter = !this.draft.id && index === 0; 
            this.draft.characterId = this.draft.newCharacter ? '' : this.state.characters[index - (this.draft.id ? 0 : 1)].id; 
            this.draft.variantId = '';
                if (automatic && !this.draft.id) { 
              const role = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId); 
              this.draft.name = role ? role + ' · Cos 计划' : ''; 
            }
              }).accessibilityText('计划角色').attributeModifier(this.feedback.control('select-1'))
            if (this.draft.newCharacter) {
              Field({ label: '角色名称 *', value: this.draft.characterName, placeholder: '例如：初音未来', change: (v: string) => {
                const automatic = !this.draft.name || this.draft.name === this.draft.characterName + ' · Cos 计划';
                this.draft.characterName = v; if (automatic) { this.draft.name = v ? v + ' · Cos 计划' : ''; }
              } })
              Field({ label: '所属作品（可选）', value: this.draft.work, change: (v: string) => { this.draft.work = v; } })
            }
            Field({
              label: '计划名称 *',
              value: this.draft.name,
              placeholder: '例如：初音未来 · 秋日漫展',
              change: (v: string) => { this.draft.name = v; }
            })
            DateField({
              label: '目标日期（可选）',
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
                  .attributeModifier(this.feedback.control('button-2'))
              if (this.draft.preparationExpanded) { PreparationTemplatePicker({
                  keys: this.draft.preparationKeys,
                  mode: this.draft.preparationMode,
                  change: (keys: string[], mode: number): void => { this.draft.preparationKeys = keys; this.draft.preparationMode = mode; }
                }) }
            }
            Button(this.draft.advanced ? '收起更多设置' : '更多设置 · 版本、活动、预算')
              .accessibilityText(this.draft.advanced ? '收起更多设置' : '展开角色版本、活动与预算设置')
              .backgroundColor(Theme.tint)
              .fontColor(Theme.accent)
              .onClick(() => { vibration.dotVibration(); this.draft.advanced = !this.draft.advanced; })
              .attributeModifier(this.feedback.control('button-3'))
            if (this.draft.advanced) {
            Text('角色版本').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不指定版本' })
              .concat(this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)
              .map((v: CharacterVariant): SelectOption => { return { value: v.name }; })))
              .value(this.state.variants.find((v: CharacterVariant) => v.id === this.draft.variantId)?.name || '不指定版本')
              .onSelect((index: number) => { 
              vibration.dotVibration(); 
              this.draft.variantId = index === 0 ? '' : this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)[index - 1].id; 
            })
                .accessibilityText('角色版本')
                .attributeModifier(this.feedback.control('select-4'))
            Text('关联活动').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不关联活动' }).concat(this.state.events.map((e: CosEvent): SelectOption => { 
              return { value: e.name }; })))
              .value(this.state.events.find((e: CosEvent) => e.id === this.draft.eventId)?.name || '不关联活动')
              .onSelect((index: number) => { 
              vibration.dotVibration(); 
              this.draft.eventId = index === 0 ? '' : this.state.events[index - 1].id; })
                .accessibilityText('关联活动')
                .attributeModifier(this.feedback.control('select-5'))
            Select(PROJECT_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.draft.status as ProjectStatus)])
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.status = PROJECT_STATUSES[index]; })
                .accessibilityText('计划状态')
                .attributeModifier(this.feedback.control('select-6'))
            Field({ label: '预计预算（元）', value: this.draft.money, change: (v: string) => { this.draft.money = v; } })
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
                .attributeModifier(this.feedback.control('select-7'))
            Select(ASSET_STATUS_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.draft.status as AssetStatus)])
              .onSelect((index: number) => { vibration.dotVibration(); this.draft.status = ASSET_STATUSES[index]; })
                .accessibilityText('装备状态')
                .attributeModifier(this.feedback.control('select-8'))
            Field({ label: '存放位置', value: this.draft.location, change: (v: string) => { this.draft.location = v; } })
            Field({ label: '品牌 / 店铺', value: this.draft.brand, change: (v: string) => { this.draft.brand = v; } })
            Field({ label: '尺码', value: this.draft.size, change: (v: string) => { this.draft.size = v; } })
            Field({ label: '购买价格（元）', value: this.draft.money, change: (v: string) => { this.draft.money = v; } })
            Field({
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
              .attributeModifier(this.feedback.control('select-9'))
            Select(DATE_MODE_LABELS.map((label: string): SelectOption => { return { value: label }; }))
              .value(DATE_MODE_LABELS[DATE_MODES.indexOf(this.draft.dateMode)])
              .onSelect((i: number): void => {
                vibration.dotVibration(); this.draft.dateMode = DATE_MODES[i];
                if (i === 0) { 
              this.draft.date = ''; 
              this.draft.endDate = ''; 
              this.draft.timeMode = 'none'; 
              this.draft.startTime = ''; 
              this.draft.endTime = ''; 
              this.draft.reminderMinutes = -1; 
              this.draft.deviceCalendar = false; 
            }
                else { 
              if (!this.draft.date) { 
                this.draft.date = today(); } 
              this.draft.endDate = i === 2 ? this.draft.endDate || this.draft.date : ''; }
              }).id('event-date-mode').accessibilityText('活动日期模式').attributeModifier(this.feedback.control('select-10'))
            if (this.draft.dateMode !== 'pending') {
              DateField({
                label: this.draft.dateMode === 'multiple' ? '开始日期 *' : '日期 *',
                value: this.draft.date,
                change: (v: string): void => { this.draft.date = v; }
              })
              if (this.draft.dateMode === 'multiple') { DateField({
                  label: '结束日期 *',
                  value: this.draft.endDate,
                  change: (v: string): void => { this.draft.endDate = v; }
                }) }
              Select(TIME_MODE_LABELS.map((label: string): SelectOption => { return { value: label }; }))
                .value(TIME_MODE_LABELS[TIME_MODES.indexOf(this.draft.timeMode)])
                .onSelect((i: number): void => { 
              vibration.dotVibration(); 
              this.draft.timeMode = TIME_MODES[i]; 
              if (i === 0) { 
                this.draft.startTime = ''; 
                this.draft.endTime = ''; } else { 
                this.draft.startTime = this.draft.startTime || '09:00'; 
                this.draft.endTime = i === 2 ? this.draft.endTime || '18:00' : ''; } 
            })
                  .accessibilityText('活动时间模式')
                  .attributeModifier(this.feedback.control('select-11'))
              if (this.draft.timeMode !== 'none') { DateField({
                  label: '开始时间 *',
                  value: this.draft.startTime,
                  time: true,
                  change: (v: string): void => { this.draft.startTime = v; }
                }) }
              if (this.draft.timeMode === 'range') { DateField({
                  label: '结束时间 *',
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
                  .attributeModifier(this.feedback.control('toggle-12'))
              }.width('100%')
              if (this.draft.deviceCalendar) { Text('保存活动后打开系统确认页；日历提醒默认提前 30 分钟，可修改。取消不影响应用内记录。').fontSize(12).fontColor(Theme.muted) }
              Text('应用内提醒').fontSize(13).fontColor(Theme.muted)
              Select([{ value: '不提醒' }, { value: '开始时' }, { value: '提前 30 分钟' }, { value: '提前 1 小时' }, { value: '提前 1 天' }])
                .value(['不提醒', '开始时', '提前 30 分钟', '提前 1 小时', '提前 1 天'][[-1, 0, 30, 60, 1440].indexOf(this.draft.reminderMinutes)])
                .onSelect((i: number): void => { vibration.dotVibration(); this.draft.reminderMinutes = [-1, 0, 30, 60, 1440][i]; })
                  .accessibilityText('活动提醒')
                  .attributeModifier(this.feedback.control('select-13'))
              if (this.draft.reminderMinutes >= 0) { Text('保存时申请通知授权；未标记时间的活动按当天 09:00 提醒。').fontSize(12).fontColor(Theme.muted) }
            }
            Field({ label: '城市', value: this.draft.city, change: (v: string) => { this.draft.city = v; } })
            Field({ label: '场馆', value: this.draft.venue, change: (v: string) => { this.draft.venue = v; } })
            Field({
              label: '官方 / 售票链接',
              value: this.draft.url,
              placeholder: 'https://',
              change: (v: string) => { this.draft.url = v; }
            })
            Select([{ value: '想去' }, { value: '计划参加' }, { value: '已参加' }])
              .value(this.draft.status === 'Wishlist' ? '想去' : this.draft.status === 'Attended' ? '已参加' : '计划参加')
              .onSelect((i: number) => { vibration.dotVibration(); this.draft.status = ['Wishlist','Planned','Attended'][i]; })
                .accessibilityText('活动参与状态')
                .attributeModifier(this.feedback.control('select-14'))
            Row() { Text('已购票')
              .fontColor(Theme.ink)
              .layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.draft.ticket })
              .onChange((v: boolean) => { vibration.dotVibration(); this.draft.ticket = v; })
              .accessibilityText('已购票')
              .attributeModifier(this.feedback.control('toggle-15')) }.width('100%')
          }
          if (this.draft.kind === 'team') {
            Text('分工').fontSize(13).fontColor(Theme.muted)
            Select(TEAM_ROLES.map((role: string): SelectOption => { return { value: role }; })).value(this.draft.type)
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.type = TEAM_ROLES[index]; })
                .accessibilityText('团队分工')
                .attributeModifier(this.feedback.control('select-16'))
            Field({
              label: '分工（可自定义） *',
              value: this.draft.type,
              placeholder: '例如：道具师、同行伙伴',
              change: (value: string): void => { this.draft.type = value; }
            })
            Text('填写本机称呼和联络备注，不会访问通讯录或向对方发送消息。').fontSize(12).fontColor(Theme.muted)
          }
          if (this.draft.kind === 'expense') {
            Text('所属计划 *').fontSize(13).fontColor(Theme.muted)
            Select(this.state.projects.map((p: CosProject): SelectOption => { 
            return { value: p.name }; })).value(this.state.projectName(this.draft.parentId))
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.parentId = this.state.projects[index].id; })
                .enabled(!this.draft.id)
                .accessibilityText('花费计划')
                .attributeModifier(this.feedback.control('select-17'))
            Select(EXPENSE_CATEGORIES.map((category: string): SelectOption => { return { value: category }; })).value(this.draft.type)
              .onSelect((index: number): void => { vibration.dotVibration(); this.draft.type = EXPENSE_CATEGORIES[index]; })
                .accessibilityText('花费分类')
                .attributeModifier(this.feedback.control('select-18'))
            Field({
              label: '实际花费（元） *',
              value: this.draft.money,
              placeholder: '例如：129.90',
              change: (v: string): void => { this.draft.money = v; }
            })
            DateField({ label: '付款日期 *', value: this.draft.date, change: (v: string): void => { this.draft.date = v; } })
          }
          if (this.draft.kind === 'preparation') {
            Text('准备分类 *').fontColor(Theme.muted).fontSize(13)
            Select(this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId)
              .map((c: PreparationCategory): SelectOption => { return { value: c.name }; }))
              .value(this.state.preparationCategories.find((c: PreparationCategory) => c.id === this.draft.categoryId)?.name || '请选择分类')
              .onSelect((index: number): void => { 
            vibration.dotVibration(); 
            this.draft.categoryId = this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.draft.parentId)[index].id; 
          })
                .accessibilityText('任务分类')
                .attributeModifier(this.feedback.control('select-19'))
            DateField({
              label: '截止日期（可选）',
              value: this.draft.date,
              optional: true,
              change: (v: string): void => { this.draft.date = v; }
            })
          }
          if (this.draft.kind !== 'category' && this.draft.kind !== 'checklist' && (this.draft.kind !== 'project' || this.draft.advanced)) { 
          Field({
              label: this.draft.kind === 'reference' ? '图片说明' : '备注',
              value: this.draft.notes,
              multiline: true,
              change: (v: string) => { this.draft.notes = v; }
            }) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top).enabled(!this.state.busy).attributeModifier(this.entrance.group(2))
      Button(this.state.busy ? '保存中…' : this.draft.kind === 'project' && !this.draft.id ? '创建计划并开始准备' : '保存')
        .accessibilityText(this.state.busy ? '正在保存' : this.draft.kind === 'project' && !this.draft.id ? '创建计划并开始准备' : '保存表单')
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .backgroundColor(Theme.accent)
        .fontColor(Theme.onAccent)
        .enabled(!this.state.busy)
        .onClick(() => { vibration.dotVibration(); this.save(); })
        .attributeModifier(this.feedback.control('button-20'))
        .opacity(this.entrance.step >= 3 ? 1 : 0)
        .translate({ y: this.entrance.step >= 3 ? 0 : 20 })
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
  }
}
