import { pageTransition } from '../../common/motion';
import { AppState } from '../../common/AppState';
import { Theme, daysUntil } from '../../common/Theme';
import { CosEvent, CosProject } from '../../model/Entities';
import { SectionHeading, StatusPill } from '../../components/Surfaces';
import { ProjectCard } from '../../components/ProjectCard';

@ComponentV2
export struct EventDetail {
  @Param state: AppState = new AppState();
  @Param event: CosEvent = new CosEvent();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local linking: boolean = false;
  private async associate(project: CosProject): Promise<void> {
    const copy = JSON.parse(JSON.stringify(project)) as CosProject; copy.eventId = this.event.id;
    if (await this.state.saveProject(copy)) { this.linking = false; }
  }
  @Builder linkSheet() {
    Column({ space: 16 }) {
      SectionHeading({ title: '关联已有计划', subtitle: '选择尚未关联漫展的计划' })
      List({ space: 10 }) {
        ForEach(this.state.projects.filter((p: CosProject) => !p.eventId), (p: CosProject) => {
          ListItem() { Button(p.name).width('100%').constraintSize({ minHeight: 56 }).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick(() => this.associate(p)) }
        }, (p: CosProject) => p.id)
      }.layoutWeight(1).width('100%')
      if (!this.state.projects.some((p: CosProject) => !p.eventId)) { Text('没有待关联的计划，可以为本场漫展新建计划。').fontColor(Theme.muted) }
      Button('完成').width('100%').backgroundColor(Theme.accent).fontColor(Theme.onAccent).onClick(() => { this.linking = false; })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.contentTop).width('100%')
        Text(daysUntil(this.event.date) >= 0 ? `还有 ${daysUntil(this.event.date)} 天` : '已留下的回忆').fontSize(14).fontColor(Theme.accent)
        Text(this.event.name).fontSize(32).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        Text(`${this.event.date} · ${this.event.city}`).fontSize(16).fontColor(Theme.muted)
        Text(this.event.venue || '场馆待确认').fontSize(16).fontColor(Theme.ink)
        StatusPill({ label: this.event.ticketPurchased ? '门票已准备' : '门票待确认' })

        if (this.event.url) { Text(this.event.url).fontSize(13).fontColor(Theme.accent).copyOption(CopyOptions.LocalDevice).accessibilityDescription('长按复制漫展链接') }
        if (this.event.notes) { Text(this.event.notes).fontSize(14).fontColor(Theme.muted) }
        Row() { SectionHeading({ title: '本场计划' }).layoutWeight(1); Button('关联已有').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => { this.linking = true; }) }.width('100%')
        if (!this.state.projects.some((p: CosProject) => p.eventId === this.event.id)) { Text('点击下方「新建计划」，本场漫展和日期会自动填入。').fontSize(14).fontColor(Theme.muted) }
        ForEach(this.state.projects.filter((p: CosProject) => p.eventId === this.event.id), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
      }.width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .bindSheet(this.linking, this.linkSheet(), { height: SheetSize.LARGE, showClose: true, onDisappear: () => { this.linking = false; } })
  }
}
