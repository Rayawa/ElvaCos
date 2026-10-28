import { displayName } from '../../utils/format/format';
import { ContextRow } from '../common/ContextRow';
import { StatusPill } from '../common/Surfaces';
import { ProjectWork } from '../../domain/plans/ProjectWork';
import { Theme } from '../../ui/theme/Theme';
import { ManagedImage } from '../common/ManagedImage';

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
                    if (this.work.coverPath) {
                        ManagedImage({ sourcePath: this.work.coverPath, label: this.work.coverLabel })
                            .width(this.compact ? 56 : 72)
                            .height(this.compact ? 64 : 90)
                    }
                    Column({ space: 5 }) {
                        Text(displayName(this.work.value.name))
                            .fontSize(this.compact ? 16 : 18)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.ink)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(displayName(this.work.value.event))
                            .fontSize(14)
                            .fontColor(Theme.muted)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Row({ space: 8 }) {
                            StatusPill({ label: '成片 ' + this.work.value.finalCount + ' 张' })
                            Text(this.work.value.date || '日期待定').fontSize(14).fontColor(Theme.muted)
                        }
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%')
                if (this.compact && !this.work.value.coverPhotoId && this.work.coverPath) {
                    ContextRow({ label: '角色封面', text: '尚无本场成片封面' })
                }
                if (!this.compact) {
                    ContextRow({ label: this.work.value.status, text: displayName(this.work.value.character + ' / ' + this.work.value.variant) })
                    ContextRow({ label: '花费', text: '已记录支出 ¥' + (this.work.value.spentCents / 100).toFixed(2) })
                    if (!this.work.value.coverPhotoId) {
                        Text(this.work.coverPath ? '当前使用角色封面，尚无本场成片封面' : '尚无作品封面，可在本计划照片中整理成片').fontSize(14).fontColor(Theme.muted)
                    }
                    ContextRow({ label: '团队', text: this.work.value.credits.join('；') || '未记录' })
                    ContextRow({ label: '衣柜复用', text: this.work.value.reusedEquipmentCount + ' 件' })
                    ContextRow({ label: '资料原值', text: '¥' + (this.work.value.equipmentValueCents / 100).toFixed(2) + '（未计入支出）' })
                }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        }.type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            .id('work-card:' + this.work.value.projectId).onClick((): void => {
                this.open();
            })
            .accessibilityText((this.compact ? '最近作品，' : '作品卡，') + this.work.value.name + '，' + this.work.value.character + '，' + this.work.value.variant + '，' + this.work.value.event + '，' + (this.work.value.date || '日期待定') + '，成片 ' + this.work.value.finalCount + ' 张' + (this.compact ? '' : '，已记录支出 ¥' + (this.work.value.spentCents / 100).toFixed(2) + '，团队署名 ' + (this.work.value.credits.join('，') || '未记录') + '，衣柜复用 ' + this.work.value.reusedEquipmentCount + ' 件，资料原值 ¥' + (this.work.value.equipmentValueCents / 100).toFixed(2) + '，未计入支出'))
            .accessibilityDescription(this.hint)
    }
}
