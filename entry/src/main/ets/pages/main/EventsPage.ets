import { today, daysUntil } from '../../common/format';
import { PressFeedback } from '../../common/pressFeedback';
import { MainEntranceSession } from '../../common/motion';
import { scrollByAxis } from '../../common/scroll';
import { EventCalendar } from '../../component/EventCalendar';
import { eventEnd, eventDateLabel, eventTimeLabel, scheduleGroups, ScheduleGroup } from '../../model/Schedule';
import { vibration } from '../../common/vibration';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { CosEvent } from '../../model/Entities';
import { EmptyState, InteractiveCard, SectionHeading, StatusPill } from '../../component/Surfaces';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';

@ComponentV2
export struct EventsPage {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Require @Param state: AppState;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event add: (kind: string, parent: string) => void = () => {};
  @Event filterChanged: (filter: number) => void = () => {};
  @Param filter: number = 0;
  @Param entranceSession: MainEntranceSession = new MainEntranceSession();
  @Param active: boolean = false;
  @Param calendar: boolean = false;
  @Local typeFilter: string = '';
  @Local animStep: number = 0;
  private enterPlayed: boolean = false;
  private enterTimers: number[] = [];
  aboutToAppear(): void { if (this.active) { this.enter(); } }
  @Monitor('active')
  activeChanged(): void { if (this.active) { this.enter(); } }
  private enter(): void {
    if (this.enterPlayed) { return; }
    this.enterPlayed = true;
    if (!this.entranceSession.claim('EventsPage')) { this.animStep = 2; return; }
    this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; });
  }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 2; }
  private groups(): ScheduleGroup[] {
    const groups = scheduleGroups(this.state.events.filter((event: CosEvent) => !this.typeFilter || event.eventType === this.typeFilter), this.state.localDate);
    if (this.filter === 1) { return [groups[3]]; }
    if (this.filter === 2) { return [groups[2]]; }
    if (this.filter === 3) { return [groups[0]]; }
    if (this.filter === 4) { return [groups[1]]; }
    return groups;
  }
  private events(): CosEvent[] { return this.groups().reduce((events: CosEvent[], group: ScheduleGroup) => events.concat(group.events), []); }
  private typeOptions(): SelectOption[] { const options: SelectOption[] = [{ value: '全部类型' }]; return options.concat(this.types().map((type: string): SelectOption => { return { value: type }; })); }
  private types(): string[] { return Array.from(new Set(this.state.events.map((event: CosEvent) => event.eventType))); }
  @Builder content(e: CosEvent) {
    Row({ space: 18 }) {
      Column({ space: 4 }) { Text(e.dateMode === 'pending' ? '日期' : e.date.slice(5, 7) + '月')
        .fontSize(13)
        .fontColor(Theme.accent); Text(e.dateMode === 'pending' ? '待定' : e.date.slice(8))
        .fontSize(32)
        .fontWeight(FontWeight.Lighter)
        .fontColor(Theme.ink) }.width(55)
      Column({ space: 6 }) { Text(e.name)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink); Text(eventDateLabel(e) + ' · ' + (e.city || e.venue || '地点待定'))
        .fontSize(13)
        .fontColor(Theme.muted); StatusPill({
          label: e.ticketPurchased ? '已购票' : e.dateMode === 'pending' ? '日期待定' : daysUntil(e.date) >= 0 ? daysUntil(e.date) + ' 天后' : eventEnd(e) >= today() ? '进行中' : '已结束'
        }) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%')
  }
  build() {
    Column({ space: 12 }) {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          Column({ space: 14 }) {
            Blank().height(this.topInset).width('100%')
            Row({ space: 8 }) {
              SectionHeading({ title: '活动安排', trailing: this.calendar ? '' : this.events().length + ' 场' }).layoutWeight(1)
              if (!this.calendar) {
                Select([{ value: '全部日期' }, { value: '已结束' }, { value: '日期待定' }, { value: '今天' }, { value: '即将到来' }])
                  .value(['全部日期', '已结束', '日期待定', '今天', '即将到来'][this.filter])
                  .onSelect((index: number): void => { vibration.dotVibration(); this.filterChanged(index); })
                  .id('event-list-filter')
                  .accessibilityText('活动日期筛选')
                  .visualEffect(this.feedback.effect('select-1'))
                  .compositingFilter(this.feedback.filter('select-1'))
                  .attributeModifier(this.feedback.control('select-1'))
              }
            }.width('100%')
            Select(this.typeOptions())
              .value(this.typeFilter || '全部类型').onSelect((index: number): void => { this.typeFilter = index === 0 ? '' : this.types()[index - 1]; }).accessibilityText('活动类型筛选')
          }.
        width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
          Column({ space: 14 }) {
            if (this.calendar) { EventCalendar({
                state: this.state, eventType: this.typeFilter,
                open: (kind: string, id: string): void => this.open(kind, id),
                add: (kind: string, parent: string): void => this.add(kind, parent)
              }) } else {
            ForEach(this.groups(), (group: ScheduleGroup) => {
              if (group.events.length > 0) { SectionHeading({ title: group.label, trailing: group.events.length + ' 场' }) }
              ForEach(group.events, (e: CosEvent) => { InteractiveCard({
                label: e.name,
                effects: this.state.settings.effects,
                action: () => this.open('event', e.id),
                content: (): void => this.content(e)
              }) }, (e: CosEvent) => e.id)
            }, (group: ScheduleGroup) => group.label)
            if (this.events().length === 0) { EmptyState({
                title: this.state.events.length ? '没有匹配的活动' : '下一场见面，值得期待',
                message: this.state.events.length ? '可以清除日期和类型筛选，查看全部活动。' : '记录活动日期，关联准备中的计划。',
                button: this.state.events.length ? '清除筛选' : '＋ 添加活动',
                action: (): void => { if (this.state.events.length) { this.typeFilter = ''; this.filterChanged(0); } else { this.add('event', ''); } }
              }) }
            }
          }.
        width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
          Blank().height(this.bottomInset).width('100%')
        }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%').constraintSize({ maxWidth: Theme.contentMaxWidth })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%')
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
