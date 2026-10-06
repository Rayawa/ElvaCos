import { AppState } from '../../common/AppState';
import { Theme, formatTime } from '../../common/Theme';
import { DiaryEntry, PhotoAsset, PhotoStatus, CosProject, ProjectStatus } from '../../model/Entities';
import { SectionHeading, EmptyState } from '../../components/Surfaces';
import { PhotoGrid } from '../photo/PhotoGrid';

@ComponentV2
export struct MePage {
  @Param scroller: Scroller = new Scroller();
  @Param topInset: number = 100;
  @Param bottomInset: number = 110;
  @Param state: AppState = new AppState();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event destructive: (kind: string) => void = () => {};
  @Param section: number = 0;
  @Builder portfolioHeader() {
    Column({ space: 14 }) {
          SectionHeading({ title: '属于你的舞台', subtitle: '最终作品与已发布照片，在这里汇成作品集' })
          Row({ space: 12 }) {
            Column({ space: 5 }) { Text(String(this.state.projects.filter((p: CosProject) => p.status === ProjectStatus.COMPLETED).length)).fontSize(26).fontColor(Theme.accent); Text('已完成计划').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
            Column({ space: 5 }) { Text(String(this.state.photos.length)).fontSize(26).fontColor(Theme.accent); Text('照片记录').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
            Column({ space: 5 }) { Text(String(this.state.assets.length)).fontSize(26).fontColor(Theme.accent); Text('衣柜装备').fontSize(12).fontColor(Theme.muted) }.layoutWeight(1)
          }.padding(18).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Column({ space: 12 }) {
      if (this.section === 0) {
        PhotoGrid({ scroller: this.scroller, state: this.state, photos: this.state.photos.filter((p: PhotoAsset) => p.status === PhotoStatus.FINAL || p.status === PhotoStatus.PUBLISHED), open: this.open, topInset: this.topInset, bottomInset: this.bottomInset, sidePadding: Theme.pagePadding, header: (): void => { this.portfolioHeader(); } }).layoutWeight(1)
      } else {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            Blank().height(this.topInset).width('100%')
            if (this.section === 1) {
              SectionHeading({ title: '热爱的轨迹', subtitle: '计划建立与状态变化，留下可回顾的时间轴' })
              ForEach(this.state.diary, (d: DiaryEntry) => {
                Column({ space: 8 }) { Text(formatTime(d.createdAt)).fontSize(12).fontColor(Theme.accent); Text(d.text).fontSize(17).fontColor(Theme.ink) }.padding(20).width('100%').backgroundColor(Theme.surface).borderRadius(20).alignItems(HorizontalAlign.Start).onClick(() => { if (d.projectId) { this.open('project', d.projectId); } })
              }, (d: DiaryEntry) => d.id)
              if (this.state.diary.length === 0) { EmptyState({ title: '故事从现在开始', message: '建立第一个计划后，准备过程会慢慢留在这里。' }) }
            }
          }.padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: this.bottomInset }).width('100%')
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%')
  }
}
