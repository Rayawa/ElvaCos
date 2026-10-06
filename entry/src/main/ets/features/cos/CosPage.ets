import { DashboardSearch } from '../../components/DashboardSearch';
import { ManagedImage } from '../../components/ManagedImage';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Character, CosProject, ProjectStatus } from '../../model/Entities';
import { ProjectCard } from '../../components/ProjectCard';
import { InteractiveCard, EmptyState, SectionHeading } from '../../components/Surfaces';
import { vibration } from '../../common/vibration';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';

@ComponentV2
export struct CosPage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param projects: boolean = true;
  @Event selection: (value: boolean) => void = () => {};
  @Param active: boolean = false;
  @Local query: string = '';
  @Local statusFilter: number = 0;
  @Local animStep: number = 0;
  private enterPlayed: boolean = false;
  private enterTimers: number[] = [];
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.enterPlayed) { return; }
    this.enterPlayed = true;
    this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 2; }
  private plans(): CosProject[] { return this.state.projects.filter((p: CosProject) => (p.name + this.state.characterName(p.characterId)).includes(this.query) && (this.statusFilter === 2 || (this.statusFilter === 1 ? p.status === ProjectStatus.COMPLETED : p.status !== ProjectStatus.COMPLETED && p.status !== ProjectStatus.ARCHIVED))); }
  private characters(): Character[] { return this.state.characters.filter((c: Character) => (c.name + c.workName).includes(this.query)); }
  @Builder characterBody(character: Character) {
    Row({ space: 16 }) {
      if (character.cover) { ManagedImage({ sourcePath: character.cover, label: character.name + '封面' }).width(72).height(90).borderRadius(14).accessibilityText(character.name + '封面') }
      else { Text(character.name.slice(0, 1)).width(72).height(90).textAlign(TextAlign.Center).fontSize(30).fontColor(Theme.accent).backgroundColor(Theme.tint).borderRadius(14).accessibilityLevel('no') }
      Column({ space: 6 }) {
        Text(character.name + (character.favorite ? ' ★' : '')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        Text(character.workName || '所属作品待补充').fontSize(13).fontColor(Theme.muted)
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
            DashboardSearch({ value: this.query, placeholder: this.projects ? '搜索计划 / 角色' : '搜索角色 / 作品', label: '搜索 Cos', changed: (v: string): void => { this.query = v; } })
            SectionHeading({ title: this.projects ? '我的计划' : '角色资料', trailing: this.projects ? `${this.plans().length} 份计划` : `${this.characters().length} 位角色` })
          }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
          Column({ space: 12 }) {
          if (this.projects) {
            Select([{ value: '进行中' }, { value: '已完成' }, { value: '全部' }]).value(['进行中', '已完成', '全部'][this.statusFilter]).onSelect((index: number) => { vibration.dotVibration(); this.statusFilter = index; }).accessibilityText('计划状态筛选')
            ForEach(this.plans(), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
            if (this.plans().length === 0) { EmptyState({ title: '没有符合条件的计划', message: '切换筛选，或新建一份 Cos 计划。', button: '＋ 新建 Cos 计划', action: () => this.add('project', '') }) }
          } else {
            ForEach(this.characters(), (c: Character) => { InteractiveCard({ label: c.name, hint: '双击打开角色详情', effects: this.state.settings.effects, action: () => this.open('character', c.id), content: (): void => this.characterBody(c) }) }, (c: Character) => c.id)
            if (this.characters().length === 0) { EmptyState({ title: this.query ? '没有找到角色' : '让喜欢有迹可循', message: this.query ? '换个角色名或作品名试试。' : '添加一个角色，开始你的 Cos 记录。' }) }
          }
          }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
        }.padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: this.bottomInset }).width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%')
  }
}
