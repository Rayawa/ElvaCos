import { scrollByAxis } from '../../common/scroll';
import { AppState } from '../../common/AppState';
import { Theme, formatTime } from '../../common/Theme';
import { DiaryEntry, PhotoAsset, PhotoStatus, CosProject, ProjectStatus } from '../../model/Entities';
import { SectionHeading, EmptyState, InteractiveCard } from '../../components/Surfaces';
import { PhotoGrid } from '../photo/PhotoGrid';
import { startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';

@ComponentV2
export struct MePage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event destructive: (kind: string) => void = () => {};
  @Param section: number = 0;
  @Param active: boolean = false;
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
  @Builder diaryBody(d: DiaryEntry) {
    Column({ space: 8 }) {
      Text(formatTime(d.createdAt)).fontSize(12).fontColor(Theme.accent)
      Text(d.text).fontSize(17).fontColor(Theme.ink)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder portfolioHeader() {
    Column({ space: 14 }) {
      SectionHeading({ title: '作品集' })
      Row({ space: 12 }) {
        Column({ space: 5 }) { Text(String(this.state.projects.filter((p: CosProject) => p.status === ProjectStatus.COMPLETED).length)).fontSize(26).fontColor(Theme.accent); Text('已完成计划').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
        Column({ space: 5 }) { Text(String(this.state.photos.length)).fontSize(26).fontColor(Theme.accent); Text('照片记录').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
        Column({ space: 5 }) { Text(String(this.state.assets.length)).fontSize(26).fontColor(Theme.accent); Text('衣柜装备').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
      }.padding(18).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder portfolioWithEnter() {
    Column() { this.portfolioHeader() }
      .width('100%')
      .opacity(this.animStep >= 1 ? 1 : 0)
      .translate({ y: this.animStep >= 1 ? 0 : 20 })
  }
  build() {
    Column({ space: 12 }) {
      if (this.section === 0) {
        PhotoGrid({ scroller: this.scroller, state: this.state, photos: this.state.photos.filter((p: PhotoAsset) => p.status === PhotoStatus.FINAL || p.status === PhotoStatus.PUBLISHED), open: this.open, topInset: this.topInset, bottomInset: this.bottomInset, sidePadding: Theme.pagePadding, header: (): void => { this.portfolioWithEnter(); } }).layoutWeight(1)
      } else {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            Blank().height(this.topInset).width('100%')
            if (this.section === 1) {
              Column({ space: 14 }) {
                SectionHeading({ title: '热爱的轨迹' })
                ForEach(this.state.diary, (d: DiaryEntry) => {
                  if (d.projectId) {
                    InteractiveCard({ label: formatTime(d.createdAt) + ' ' + d.text, hint: '双击打开关联计划', effects: this.state.settings.effects, contentPadding: 20, action: () => { if (d.projectId) { this.open('project', d.projectId); } }, content: (): void => this.diaryBody(d) })
                  } else {
                    this.diaryBody(d)
                  }
                }, (d: DiaryEntry) => d.id)
                if (this.state.diary.length === 0) { EmptyState({ title: '故事从现在开始', message: '建立第一个计划后，准备过程会慢慢留在这里。' }) }
              }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
            }
            Blank().height(this.bottomInset).width('100%')
          }.padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%')
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
