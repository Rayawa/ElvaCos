import { contentEnterTransition } from '../common/motion';
import { AppState } from '../common/AppState';
import { Theme } from '../common/Theme';
import { EditDraft } from '../model/EditDraft';
import { Character, CharacterVariant, CosEvent, ProjectStatus, AssetType, AssetStatus, ASSET_TYPES, ASSET_TYPE_LABELS, ASSET_STATUSES, ASSET_STATUS_LABELS, PROJECT_STATUSES, PROJECT_LABELS } from '../model/Entities';
import { Field } from './Surfaces';

@ComponentV2
export struct FormEditor {
  @Param state: AppState = new AppState();
  @Param draft: EditDraft = new EditDraft();
  @Event saved: (kind: string, id: string, created: boolean) => void = () => {};
  @Event done: () => void = () => {};
  private async save(): Promise<void> {
    const created = !this.draft.id;
    try { if (await this.draft.save(this.state)) { this.done(); this.saved(this.draft.kind, this.draft.id, created); } }
    catch (error) { this.state.reportError((error as Error).message); }
  }
  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.draft.title()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.ink).layoutWeight(1)
        Button('取消').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick(() => this.done())
      }.width('100%')
      Scroll() {
        Column({ space: 18 }) {
          if (this.draft.kind !== 'project') { Field({ label: '名称 *', value: this.draft.name, placeholder: this.draft.kind === 'asset' ? '例如：蓝色长假发' : this.draft.kind === 'checklist' ? '例如：美瞳护理液' : '例如：初音未来', change: (v: string) => { this.draft.name = v; } }) }
          if (this.draft.kind === 'character') { Field({ label: '所属作品', value: this.draft.work, change: (v: string) => { this.draft.work = v; } }) }
          if (this.draft.kind === 'project') {
            Text('这次想出谁？ *').fontColor(Theme.muted).fontSize(13)
            Select((this.draft.id ? new Array<SelectOption>() : new Array<SelectOption>({ value: '＋ 创建新角色' })).concat(this.state.characters.map((c: Character): SelectOption => { return { value: c.name }; })))
              .value(this.draft.newCharacter ? '＋ 创建新角色' : this.state.characterName(this.draft.characterId))
              .onSelect((index: number) => {
                const previous = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId);
                const automatic = !this.draft.name || this.draft.name === previous + ' · Cos 计划';
                this.draft.newCharacter = !this.draft.id && index === 0; this.draft.characterId = this.draft.newCharacter ? '' : this.state.characters[index - (this.draft.id ? 0 : 1)].id; this.draft.variantId = '';
                if (automatic && !this.draft.id) { const role = this.draft.newCharacter ? this.draft.characterName : this.state.characterName(this.draft.characterId); this.draft.name = role ? role + ' · Cos 计划' : ''; }
              }).accessibilityText('计划角色')
            if (this.draft.newCharacter) {
              Field({ label: '角色名称 *', value: this.draft.characterName, placeholder: '例如：初音未来', change: (v: string) => {
                const automatic = !this.draft.name || this.draft.name === this.draft.characterName + ' · Cos 计划';
                this.draft.characterName = v; if (automatic) { this.draft.name = v ? v + ' · Cos 计划' : ''; }
              } })
              Field({ label: '所属作品（可选）', value: this.draft.work, change: (v: string) => { this.draft.work = v; } })
            }
            Field({ label: '计划名称 *', value: this.draft.name, placeholder: '例如：初音未来 · 秋日漫展', change: (v: string) => { this.draft.name = v; } })
            Field({ label: '目标日期（可选）', value: this.draft.date, placeholder: 'YYYY-MM-DD，可以稍后补充', change: (v: string) => { this.draft.date = v; } })
            Button(this.draft.advanced ? '收起更多设置' : '更多设置 · 版本、漫展、预算').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => { this.draft.advanced = !this.draft.advanced; })
            if (this.draft.advanced) {
            Text('角色版本').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不指定版本' }).concat(this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId).map((v: CharacterVariant): SelectOption => { return { value: v.name }; })))
              .value(this.state.variants.find((v: CharacterVariant) => v.id === this.draft.variantId)?.name || '不指定版本')
              .onSelect((index: number) => { this.draft.variantId = index === 0 ? '' : this.state.variants.filter((v: CharacterVariant) => v.characterId === this.draft.characterId)[index - 1].id; }).accessibilityText('角色版本')
            Text('关联漫展').fontColor(Theme.muted).fontSize(13)
            Select(new Array<SelectOption>({ value: '不关联漫展' }).concat(this.state.events.map((e: CosEvent): SelectOption => { return { value: e.name }; })))
              .value(this.state.events.find((e: CosEvent) => e.id === this.draft.eventId)?.name || '不关联漫展')
              .onSelect((index: number) => { this.draft.eventId = index === 0 ? '' : this.state.events[index - 1].id; }).accessibilityText('关联漫展')
            Select(PROJECT_LABELS.map((label: string): SelectOption => { return { value: label }; })).value(PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.draft.status as ProjectStatus)])
              .onSelect((index: number) => { this.draft.status = PROJECT_STATUSES[index]; }).accessibilityText('计划状态')
            Field({ label: '预计预算（元）', value: this.draft.money, change: (v: string) => { this.draft.money = v; } })
            }
          }
          if (this.draft.kind === 'asset') {
            if (this.draft.parentId && !this.draft.id) { Text('保存后自动加入「' + this.state.projectName(this.draft.parentId) + '」和打包清单').fontSize(13).fontColor(Theme.accent) }
            Select(ASSET_TYPE_LABELS.map((label: string): SelectOption => { return { value: label }; })).value(ASSET_TYPE_LABELS[ASSET_TYPES.indexOf(this.draft.type as AssetType)])
              .onSelect((index: number) => { this.draft.type = ASSET_TYPES[index]; }).accessibilityText('装备类型')
            Select(ASSET_STATUS_LABELS.map((label: string): SelectOption => { return { value: label }; })).value(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(this.draft.status as AssetStatus)])
              .onSelect((index: number) => { this.draft.status = ASSET_STATUSES[index]; }).accessibilityText('装备状态')
            Field({ label: '存放位置', value: this.draft.location, change: (v: string) => { this.draft.location = v; } })
            Field({ label: '品牌 / 店铺', value: this.draft.brand, change: (v: string) => { this.draft.brand = v; } })
            Field({ label: '尺码', value: this.draft.size, change: (v: string) => { this.draft.size = v; } })
            Field({ label: '购买价格（元）', value: this.draft.money, change: (v: string) => { this.draft.money = v; } })
            Field({ label: '购买链接', value: this.draft.url, placeholder: 'https://', change: (v: string) => { this.draft.url = v; } })
          }
          if (this.draft.kind === 'event') {
            Field({ label: '日期 *', value: this.draft.date, placeholder: 'YYYY-MM-DD', change: (v: string) => { this.draft.date = v; } })
            Field({ label: '城市', value: this.draft.city, change: (v: string) => { this.draft.city = v; } })
            Field({ label: '场馆', value: this.draft.venue, change: (v: string) => { this.draft.venue = v; } })
            Field({ label: '官方 / 售票链接', value: this.draft.url, placeholder: 'https://', change: (v: string) => { this.draft.url = v; } })
            Select([{ value: '想去' }, { value: '计划参加' }, { value: '已参加' }]).value(this.draft.status === 'Wishlist' ? '想去' : this.draft.status === 'Attended' ? '已参加' : '计划参加')
              .onSelect((i: number) => { this.draft.status = ['Wishlist','Planned','Attended'][i]; }).accessibilityText('漫展状态')
            Row() { Text('已购票').fontColor(Theme.ink).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.draft.ticket }).onChange((v: boolean) => { this.draft.ticket = v; }).accessibilityText('已购票') }.width('100%')
          }
          if (this.draft.kind !== 'checklist' && (this.draft.kind !== 'project' || this.draft.advanced)) { Field({ label: '备注', value: this.draft.notes, multiline: true, change: (v: string) => { this.draft.notes = v; } }) }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      Button(this.state.busy ? '保存中…' : this.draft.kind === 'project' && !this.draft.id ? '创建计划并开始准备' : '保存').width('100%').constraintSize({ minHeight: 52 }).backgroundColor(Theme.accent).fontColor(Theme.onAccent).enabled(!this.state.busy).onClick(() => this.save())
    }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface).transition(contentEnterTransition())
  }
}
