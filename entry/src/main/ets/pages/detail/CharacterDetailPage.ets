import { DetailLink } from '../../component/DetailLink';
import { Icons } from '../../common/Icons';
import { ContextRow } from '../../component/ContextRow';
import { EntryCollectionView } from '../../component/EntryCollectionView';
import { SheetHeader } from '../../component/SheetHeader';
import { appSheetOptions } from '../../common/sheet';
import { StaggerEntrance, pageTransition } from '../../common/motion';
import { ReferenceGallery } from '../../component/ReferenceGallery';
import { ReferenceImage } from '../../model/Planning';
import { ManagedImage } from '../../component/ManagedImage';
import { WorkCard } from '../../component/WorkCard';
import { ProjectWork } from '../../model/ProjectWork';
import { CharacterRoute } from '../../model/CharacterRoute';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { Character, CharacterVariant } from '../../model/Entities';
import { SectionHeading, EmptyState } from '../../component/Surfaces';

@ComponentV2
export struct CharacterDetail {
  @Require @Param state: AppState;
  @Require @Param character: Character;
  @Require @Param route: CharacterRoute;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event createPlan: (characterId: string, variantId: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  private scroller: Scroller = new Scroller();
  private measured: boolean = false;
  private restoring: boolean = true;
  private restoreTimer: number = -1;
  private displayedSection: number = 0;
  aboutToAppear(): void { this.displayedSection = this.route.section; if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } if (!this.entrance.managed) { this.entrance.reset(); } }
  @Monitor('route.section', 'route.restoreVersion')
  viewChanged(): void { this.displayedSection = this.route.section; this.restoreOffset(); }
  private restoreOffset(): void {
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); } this.restoring = true;
    this.restoreTimer = setTimeout((): void => { this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false }); this.restoring = false; }, 0);
  }
  private writable(): boolean { return !this.state.busy && !this.state.staleScopes.length; }
  private async favorite(): Promise<void> { const c = JSON.parse(JSON.stringify(this.character)) as Character; c.favorite = !c.favorite; await this.state.saveCharacter(c); }
  private variants(): CharacterVariant[] { return this.state.variants.filter((v: CharacterVariant) => v.characterId === this.character.id); }
  private works(): ProjectWork[] { return this.state.workCards.filter((work: ProjectWork) => work.value.characterId === this.character.id); }
  private validVersion(): boolean { return !this.route.variantId || this.variants().some((variant: CharacterVariant) => variant.id === this.route.variantId); }
  @Builder header() {
    Select(new Array<SelectOption>({ value: '不指定版本' }).concat(this.variants().map((variant: CharacterVariant): SelectOption => { return { value: variant.name }; })))
      .value(this.route.variantId ? this.variants().find((variant: CharacterVariant) => variant.id === this.route.variantId)?.name || '版本已不存在' : '不指定版本')
      .constraintSize({ minHeight: 48 }).accessibilityText('新建计划使用的角色版本').id('character-plan-version')
      .onSelect((index: number): void => { this.route.variantId = index === 0 ? '' : this.variants()[index - 1].id; })
    if (!this.validVersion()) { Text('所选版本已不存在，请重新选择后新建计划。').fontSize(14).fontColor(Theme.danger) }
    Button('用这个角色新建计划').constraintSize({ minHeight: 48 }).width('100%').backgroundColor(Theme.brand).fontColor(Theme.onAccent)
      .enabled(this.writable() && this.validVersion()).onClick((): void => { this.createPlan(this.character.id, this.route.variantId); })
    if (this.state.error) { Text(this.state.error).fontSize(14).fontColor(Theme.danger) }
  }
  @Builder profile() {
    if (this.character.cover) { ManagedImage({ large: true, sourcePath: this.character.cover, label: this.character.name + '角色封面（不改变计划照片）', ratio: 1.3, radius: Theme.cardRadius }).width('100%').aspectRatio(1.3) }
    Row({ space: 12 }) {
      if (this.character.workName) { Text(this.character.workName).fontSize(15).fontColor(Theme.muted).layoutWeight(1) } else { Blank().layoutWeight(1) }
      Button(this.character.favorite ? '★ 已收藏' : '☆ 收藏').type(ButtonType.Normal).constraintSize({ minHeight: 48 }).enabled(this.writable()).backgroundColor(Color.Transparent).fontColor(Theme.accent)
        .onClick((): void => { void this.favorite(); }).accessibilityText(this.character.favorite ? '取消收藏 ' + this.character.name : '收藏 ' + this.character.name)
    }.width('100%')
    if (this.character.description) { Text(this.character.description).fontSize(15).fontColor(Theme.muted) }
    Column({ space: 12 }) { this.header() }.padding(20).width('100%').alignItems(HorizontalAlign.Start).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    Row() {
      SectionHeading({ title: '角色版本', trailing: this.variants().length + ' 个' }).layoutWeight(1)
      Button('添加版本').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(this.writable()).onClick((): void => { this.edit('variant', '', this.character.id); })
    }.width('100%')
    ForEach(this.variants(), (variant: CharacterVariant) => {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(variant.name).fontSize(20).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1)
          Select([{ value: '编辑版本' }, { value: '删除版本' }]).value('更多').constraintSize({ minHeight: 48 }).enabled(this.writable())
            .onSelect((index: number): void => { if (index === 0) { this.edit('variant', variant.id, this.character.id); } else { this.remove('variant', variant.id); } }).accessibilityText(variant.name + '，编辑或删除版本')
        }.width('100%')
        if (variant.notes) { Text(variant.notes).fontSize(14).fontColor(Theme.muted) }
        Button('用此版本新建计划').type(ButtonType.Normal).constraintSize({ minHeight: 48 }).backgroundColor(Color.Transparent).fontColor(Theme.accent).enabled(this.writable())
          .onClick((): void => { this.route.variantId = variant.id; this.createPlan(this.character.id, variant.id); }).accessibilityText('使用版本 ' + variant.name + ' 新建计划')
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
    }, (variant: CharacterVariant) => variant.id)
    if (!this.variants().length) { Text('可选：添加服装或造型版本，下次创建计划时复用。').fontSize(14).fontColor(Theme.muted) }
    Column() {
      DetailLink({ title: '收录', value: this.state.entries.filter((entry) => entry.scopeKind === 'character' && entry.scopeId === this.character.id).length + ' 条', icon: Icons.library,
        componentId: 'character-entry-link', action: (): void => { this.route.entriesOpen = true; } })
    }.width('100%').padding({ left: 16, right: 16 }).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
  }
  @Builder history() {
    SectionHeading({ title: '角色履历', trailing: this.works().length + ' 份计划' })
    Text('按计划 / 活动日期倒序，日期待定列在末尾；卡片反映当前记录。').fontSize(14).fontColor(Theme.muted)
    ForEach(this.works(), (work: ProjectWork) => { WorkCard({ work: work, open: (): void => { this.open('project', work.value.projectId); } }) }, (work: ProjectWork) => work.value.projectId)
    if (!this.works().length) { EmptyState({ title: '从喜欢到登场', message: '创建一份计划，留下场次、作品和一起完成的人。', button: '用这个角色新建计划', action: (): void => { if (this.writable() && this.validVersion()) { this.createPlan(this.character.id, this.route.variantId); } } }) }
  }
  @Builder references() {
    Text('角色参考图用于视觉准备，不计入成片或照片处理数量。').fontSize(14).fontColor(Theme.muted)
    ReferenceGallery({ state: this.state, images: this.state.references.filter((reference: ReferenceImage) => reference.characterId === this.character.id),
      add: (): void => { void this.state.importReferences('', this.character.id); }, open: (id: string): void => { this.open('reference', id); } })
  }
  @Builder entriesSheet() {
    Column({ space: 14 }) {
      SheetHeader({ title: '角色收录', hint: this.character.name, haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, close: (): void => { this.route.entriesOpen = false; } })
      EntryCollectionView({ state: this.state, route: this.route.entries, componentId: 'character-entries-scroll', active: this.route.entriesOpen,
        restoreVersion: this.route.restoreVersion, open: (kind: string, id: string): void => { this.open(kind, id); } }).layoutWeight(1)
    }.width('100%').height('100%').padding(Theme.pagePadding).backgroundColor(Theme.surface)
  }
  build() {
    Column({ space: 12 }) {
      Scroll(this.scroller) {
        Column({ space: Theme.sectionSpacing }) {
          Blank().height(Theme.detailTop).width('100%')
          if (this.route.section === 0) { this.profile() } else if (this.route.section === 1) { this.history() } else { this.references() }
          Blank().height(Theme.detailFloatingBottom).width('100%')
        }.constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding })
      }.id('character-detail-scroll').width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
        .onAreaChange((_, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); } })
        .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.displayedSection] = this.scroller.currentOffset().yOffset; } })
    }.width('100%').height('100%').transition(pageTransition())
      .bindSheet(this.route.entriesOpen, this.entriesSheet(), appSheetOptions((): void => { this.route.entriesOpen = false; }, this.sheetEntrance, this.getUIContext()))
  }
}
