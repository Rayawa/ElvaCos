import { ProjectWork } from '../model/ProjectWork';
import { Theme } from '../common/Theme';
import { ManagedImage } from './ManagedImage';

@ComponentV2
export struct WorkCard {
  @Require @Param work: ProjectWork;
  @Param compact: boolean = false;
  @Param hint: string = '双击查看计划概览';
  @Event open: () => void = () => {};
  build() {
    Button() {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          if (this.work.coverPath) { ManagedImage({ sourcePath: this.work.coverPath, label: this.work.coverLabel }).width(this.compact ? 56 : 72).height(this.compact ? 64 : 90) }
          Column({ space: 5 }) {
            Text(this.work.value.character + ' / ' + this.work.value.variant).fontSize(this.compact ? 16 : 18).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.work.value.event + ' · ' + (this.work.value.date || '日期待定') + (this.work.value.dateFromEvent ? ' · 来自活动' : '')).fontSize(14).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('成片 ' + this.work.value.finalCount + ' 张 · 已记录支出 ¥' + (this.work.value.spentCents / 100).toFixed(2)).fontSize(14).fontColor(Theme.ink)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
        if (this.compact && !this.work.value.coverPhotoId && this.work.coverPath) { Text('角色封面 · 非本场成片').fontSize(14).fontColor(Theme.muted) }
        if (!this.compact) {
          Text(this.work.value.name + ' · ' + this.work.value.status).fontSize(14).fontColor(Theme.muted)
          if (!this.work.value.coverPhotoId) { Text(this.work.coverPath ? '当前使用角色封面，尚无本场成片封面' : '尚无作品封面，可在本计划照片中整理成片').fontSize(14).fontColor(Theme.muted) }
        }
        Text('团队署名：' + (this.work.value.credits.join('；') || '未记录')).fontSize(14).fontColor(Theme.muted).maxLines(this.compact ? 1 : 20).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('衣柜复用 ' + this.work.value.reusedEquipmentCount + ' 件 · 资料原值 ¥' + (this.work.value.equipmentValueCents / 100).toFixed(2) + '（未计入支出）').fontSize(14).fontColor(Theme.muted).maxLines(this.compact ? 2 : 20).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(this.compact ? 10 : 16)
    }.type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
      .id('work-card:' + this.work.value.projectId).onClick((): void => { this.open(); })
      .accessibilityText((this.compact ? '最近作品 · ' : '作品卡 · ') + this.work.value.name + '，' + this.work.value.character + '，' + this.work.value.variant + '，' + this.work.value.event + '，' + (this.work.value.date || '日期待定') + '，成片 ' + this.work.value.finalCount + ' 张，已记录支出 ¥' + (this.work.value.spentCents / 100).toFixed(2) + '，团队署名 ' + (this.work.value.credits.join('，') || '未记录') + '，衣柜复用 ' + this.work.value.reusedEquipmentCount + ' 件，资料原值 ¥' + (this.work.value.equipmentValueCents / 100).toFixed(2) + '，未计入支出')
      .accessibilityDescription(this.hint)
  }
}
