import { filterCharacters } from '../../model/CharacterLibrary';
import { PressFeedback } from '../../common/pressFeedback';
import { MainEntranceSession } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { PlanListRoute, filterPlanList } from '../../model/PlanListRoute';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../../common/constants';
import { DashboardSearch } from '../../component/DashboardSearch';
import { ManagedImage } from '../../component/ManagedImage';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { Character, CosProject, ProjectStatus } from '../../model/Entities';
import { ProjectCard } from '../../component/ProjectCard';
import { InteractiveCard, EmptyState, SectionHeading } from '../../component/Surfaces';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';

@ComponentV2
export struct CosPage {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Require @Param state: AppState;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param projects: boolean = true;
  @Param route: PlanListRoute = new PlanListRoute();
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  private displayedSection: number = 0;
  private restoring: boolean = true;
  private measured: boolean = false;
  private restoreTimer: number = -1;
  @Local animStep: number = 0;
  private enterPlayed: boolean = false;
  private enterTimers: number[] = [];
  aboutToAppear(): void { this.restore(); if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); this.restore(); } }
  private enter(): void {
    if (this.enterPlayed) { return; }
    this.enterPlayed = true;
    if (!this.entranceSession.claim('CosPage')) { this.animStep = 2; return; }
    this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void {
    cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 2;
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; }
  }
  @Monitor('route.section', 'route.restoreVersion')
  sectionChanged(): void { this.restore(); }
  private restore(): void {
    this.restoring = true; this.displayedSection = this.route.section;
    if (!this.measured) { return; }
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1;
      this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false });
      if (!this.projects && this.route.anchorId) { try { this.getUIContext().getFocusController().requestFocus('character-library:' + this.route.anchorId); } catch (error) {} }
      this.restoring = false;
    }, 0);
  }
  private resetPosition(): void {
    this.route.anchorId = ''; this.route.offsets[this.route.section] = 0;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }
  private plans(): CosProject[] { return filterPlanList(this.state.projects, this.state.readinessPlans, this.state.characters, this.route, this.state.localDate); }
  private characters(): Character[] { return filterCharacters(this.state.characters, this.route); }
  private statuses(): ProjectStatus[] {
    return PROJECT_STATUSES.filter((status: ProjectStatus): boolean => this.route.section === 2 || (this.route.section === 0 ? status !== ProjectStatus.COMPLETED && status !== ProjectStatus.ARCHIVED : status === ProjectStatus.COMPLETED));
  }
  private statusOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部状态' }];
    return options.concat(this.statuses().map((status: ProjectStatus): SelectOption => { return { value: PROJECT_LABELS[PROJECT_STATUSES.indexOf(status)] }; }));
  }
  private filtered(): boolean { return !!this.route.query.trim() || !!this.route.status || this.route.dateRange !== 'all'; }
  private clearFilters(): void { this.route.query = ''; this.route.status = ''; this.route.dateRange = 'all'; this.route.favoriteOnly = false; this.resetPosition(); }
  @Builder characterBody(character: Character) {
    Row({ space: 16 }) {
      if (character.cover) { ManagedImage({ sourcePath: character.cover, label: character.name + '封面' })
        .width(72)
        .height(90)
        .borderRadius(14)
        .accessibilityText(character.name + '封面') }
      else { Text(character.name.slice(0, 1))
        .width(72)
        .height(90)
        .textAlign(TextAlign.Center)
        .fontSize(30)
        .fontColor(Theme.accent)
        .backgroundColor(Theme.tint)
        .borderRadius(14)
        .accessibilityLevel('no')
        .visualEffect(this.feedback.effect('character-placeholder:' + character.id))
        .compositingFilter(this.feedback.filter('character-placeholder:' + character.id))
        .attributeModifier(this.feedback.control('character-placeholder:' + character.id)) }
      Column({ space: 6 }) {
        Text(character.name + (character.favorite ? ' ★' : '')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        Text(character.workName || '所属作品待补充').fontSize(13).fontColor(Theme.muted)
        Text('版本 ' + this.state.characterSummary(character.id).variants.length + ' 个 · 关联计划 ' + this.state.characterSummary(character.id).planCount + ' 份').fontSize(14).fontColor(Theme.muted)
        if (this.state.characterSummary(character.id).variants.length) { Text(this.state.characterSummary(character.id).variants.join(' / ')).fontSize(14).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontColor(Theme.muted).fontSize(26).accessibilityLevel('no')
    }.width('100%')
  }
  build() {
    Column({ space: 12 }) {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          Column({ space: 12 }) {
            Blank().height(this.topInset).width('100%')
            DashboardSearch({
              value: this.route.query,
              placeholder: this.projects ? '搜索计划 / 角色' : '搜索角色 / 作品',
              label: this.projects ? '搜索计划' : '搜索角色',
              changed: (v: string): void => { this.route.query = v; this.resetPosition(); }
            })
            SectionHeading({
              title: this.projects ? ['进行中计划', '已完成计划', '全部计划'][this.route.section] : '角色库',
              trailing: this.projects ? `${this.plans().length} 份计划` : `${this.characters().length} 位角色`
            })
          }.
        width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
          Column({ space: 12 }) {
          if (this.projects) {
            Button('角色库 · ' + this.state.characters.length + ' 位角色').width('100%').constraintSize({ minHeight: 48 })
              .fontColor(Theme.accent).backgroundColor(Theme.tint).id('plan-role-library')
              .onClick((): void => { this.open('characters', 'all'); }).accessibilityText('打开角色库')
            Select(this.statusOptions())
              .value(this.route.status ? PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.route.status as ProjectStatus)] : '全部状态')
              .onSelect((index: number): void => { this.route.status = index === 0 ? '' : this.statuses()[index - 1]; this.resetPosition(); })
              .accessibilityText('计划具体状态筛选')
            Select([{ value: '全部日期' }, { value: '日期待定' }, { value: '日期已过' }, { value: '今天' }, { value: '未来七天' }, { value: '今天及以后' }])
              .value(['全部日期', '日期待定', '日期已过', '今天', '未来七天', '今天及以后'][['all', 'undated', 'overdue', 'today', 'week', 'future'].indexOf(this.route.dateRange)])
              .onSelect((index: number): void => { this.route.dateRange = ['all', 'undated', 'overdue', 'today', 'week', 'future'][index]; this.resetPosition(); })
              .accessibilityText('计划日期筛选')
            if (this.filtered()) { Button('清除筛选').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { this.clearFilters(); }) }
            ForEach(this.plans(), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
            if (this.plans().length === 0) { EmptyState({
                title: this.filtered() ? '没有符合条件的计划' : '这里还没有计划',
                message: this.filtered() ? '调整日期或状态筛选，再查看已有计划。' : '新建计划后，可以添加准备任务和打包清单。',
                button: this.filtered() ? '清除筛选' : '＋ 新建计划',
                action: (): void => { if (this.filtered()) { this.clearFilters(); } else { this.add('project', ''); } }
              }) }
          } else {
            Select([{ value: '全部角色' }, { value: '已收藏角色' }]).value(this.route.favoriteOnly ? '已收藏角色' : '全部角色').constraintSize({ minHeight: 48 }).accessibilityText('角色收藏筛选')
              .onSelect((index: number): void => { this.route.favoriteOnly = index === 1; this.resetPosition(); })
            if (this.route.query.trim() || this.route.favoriteOnly) { Button('清除角色筛选').constraintSize({ minHeight: 48 }).onClick((): void => { this.clearFilters(); }) }
            ForEach(this.characters(), (c: Character) => { InteractiveCard({
                label: c.name,
                hint: '双击打开角色详情',
                effects: this.state.settings.effects,
                action: () => this.open('character', c.id),
                content: (): void => this.characterBody(c)
              }).id('character-library:' + c.id) }, (c: Character) => c.id)
            if (this.characters().length === 0) { EmptyState({
                title: this.route.query.trim() || this.route.favoriteOnly ? '没有找到角色' : '让喜欢有迹可循',
                message: this.route.query.trim() || this.route.favoriteOnly ? '调整搜索或收藏筛选，再查看已有角色。' : '添加一个角色，开始你的 Cos 记录。',
                button: this.route.query.trim() || this.route.favoriteOnly ? '清除角色筛选' : '＋ 添加角色',
                action: (): void => { if (this.route.query.trim() || this.route.favoriteOnly) { this.clearFilters(); } else { this.add('character', ''); } }
              }) }
          }
          }.
        width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
          Blank().height(this.bottomInset).width('100%')
        }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
        .onAreaChange((_, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restore(); } })
        .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.displayedSection] = this.scroller.currentOffset().yOffset; } })
    }.width('100%').height('100%')
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
