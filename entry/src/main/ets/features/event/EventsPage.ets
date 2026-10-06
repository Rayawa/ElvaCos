import { AppState } from '../../common/AppState';
import { Theme, today, daysUntil } from '../../common/Theme';
import { CosEvent } from '../../model/Entities';
import { EmptyState, InteractiveCard, SectionHeading, StatusPill } from '../../components/Surfaces';

@ComponentV2
export struct EventsPage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Param filter: number = 0;
  private events(): CosEvent[] { return this.state.events.filter((e: CosEvent) => this.filter === 2 ? e.status === 'Wishlist' : this.filter === 1 ? e.status === 'Attended' || (e.date < today() && e.status !== 'Wishlist') : e.status === 'Planned' && e.date >= today()).sort((a: CosEvent, b: CosEvent) => this.filter === 1 ? b.date.localeCompare(a.date) : a.date.localeCompare(b.date)); }
  @Builder content(e: CosEvent) {
    Row({ space: 18 }) {
      Column({ space: 4 }) { Text(e.date.slice(5, 7) + '月').fontSize(13).fontColor(Theme.accent); Text(e.date.slice(8)).fontSize(32).fontWeight(FontWeight.Lighter).fontColor(Theme.ink) }.width(55)
      Column({ space: 6 }) { Text(e.name).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.ink); Text(e.date + ' · ' + (e.city || e.venue || '地点待定')).fontSize(13).fontColor(Theme.muted); StatusPill({ label: e.ticketPurchased ? '已购票' : e.status === 'Wishlist' ? '想去' : daysUntil(e.date) >= 0 ? daysUntil(e.date) + ' 天后' : '留在回忆里' }) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%')
  }
  build() {
    Column({ space: 12 }) {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
            Blank().height(this.topInset).width('100%')
          SectionHeading({ title: '和热爱见面', subtitle: '漫展计划、角色与随身清单，都在这里' })
          ForEach(this.events(), (e: CosEvent) => { InteractiveCard({ label: e.name, effects: this.state.settings.effects, action: () => this.open('event', e.id), content: (): void => this.content(e) }) }, (e: CosEvent) => e.id)
          if (this.events().length === 0) { EmptyState({ title: '下一场见面，值得期待', message: '记录漫展日期，关联准备中的计划。' }) }
        }.padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: this.bottomInset }).width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%')
  }
}
