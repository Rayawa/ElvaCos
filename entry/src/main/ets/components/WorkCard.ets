import { displayName } from '../utils/format';
import { ContextRow } from './ContextRow';
import { DetailTag } from './DetailTag';
import { MetaRow } from './MetaRow';
import { InteractiveCard, StatusPill } from './Surfaces';
import { ProjectWork } from '../models/ProjectWork';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { ManagedImage } from './ManagedImage';

@ComponentV2
export struct WorkCard {
    @Require @Param work: ProjectWork;
    @Param compact: boolean = false;
    @Param effects: boolean = true;
    @Param hint: string = '双击查看计划概览';
    @Event open: () => void = () => {};

    @Builder body() {
        Column({ space: 10 }) {
            Row({ space: 12 }) {
                if (this.work.coverPath) {
                    ManagedImage({ sourcePath: this.work.coverPath, label: this.work.coverLabel, radius: 12 })
                        .width(this.compact ? 58 : 72)
                        .height(this.compact ? 72 : 92)
                }
                Column({ space: 5 }) {
                    Row({ space: 8 }) {
                        Text(displayName(this.work.value.name))
                            .fontSize(this.compact ? 16 : 18)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.ink)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        StatusPill({
                            label: '成片 ' + this.work.value.finalCount + ' 张',
                            tone: this.work.value.finalCount > 0 ? 'success' : 'neutral',
                            compact: true,
                        })
                    }.width('100%')
                        .alignItems(VerticalAlign.Top)
                    if (this.work.value.event) {
                        Text(displayName(this.work.value.event))
                            .fontSize(13)
                            .fontColor(Theme.muted)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    Row({ space: 12 }) {
                        MetaRow({
                            icon: Icons.event,
                            text: this.work.value.date || '日期待定',
                        })
                        if (this.compact) {
                            MetaRow({
                                icon: Icons.profile,
                                text: displayName(this.work.value.character),
                            })
                        }
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
            }.width('100%')
            if (this.compact && !this.work.value.coverPhotoId && this.work.coverPath) {
                ContextRow({ label: '角色封面', text: '尚无本场成片封面', tone: 'neutral' })
            }
            if (!this.compact) {
                Row({ space: 8 }) {
                    DetailTag({
                        label: '状态',
                        value: this.work.value.status,
                        tone: 'brand',
                    }).layoutWeight(1)
                    DetailTag({
                        label: '角色',
                        value: displayName(this.work.value.character + (this.work.value.variant ? ' / ' + this.work.value.variant : '')),
                    }).layoutWeight(1)
                }.width('100%')
                Row({ space: 8 }) {
                    DetailTag({
                        label: '支出',
                        value: '¥' + (this.work.value.spentCents / 100).toFixed(2),
                        tone: 'brand',
                    }).layoutWeight(1)
                    DetailTag({
                        label: '衣柜复用',
                        value: this.work.value.reusedEquipmentCount + ' 件',
                    }).layoutWeight(1)
                }.width('100%')
                if (this.work.value.equipmentValueCents > 0 || this.work.value.credits.length > 0) {
                    Row({ space: 12 }) {
                        if (this.work.value.credits.length > 0) {
                            MetaRow({
                                icon: Icons.profile,
                                text: '团队：' + this.work.value.credits.join('；'),
                            })
                        }
                        if (this.work.value.equipmentValueCents > 0) {
                            MetaRow({
                                icon: Icons.library,
                                text: '资料原值 ¥' + (this.work.value.equipmentValueCents / 100).toFixed(2),
                            })
                        }
                    }
                }
                if (!this.work.value.coverPhotoId) {
                    Text(this.work.coverPath ? '当前使用角色封面，尚无本场成片封面' : '尚无作品封面，可在本计划照片中整理成片')
                        .fontSize(12)
                        .fontColor(Theme.muted)
                }
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    build() {
        InteractiveCard({
            label: (this.compact ? '最近作品，' : '作品卡，') + this.work.value.name + '，' + this.work.value.character + '，' + this.work.value.variant + '，' + this.work.value.event + '，' + (this.work.value.date || '日期待定') + '，成片 ' + this.work.value.finalCount + ' 张' + (this.compact ? '' : '，已记录支出 ¥' + (this.work.value.spentCents / 100).toFixed(2) + '，团队署名 ' + (this.work.value.credits.join('，') || '未记录') + '，衣柜复用 ' + this.work.value.reusedEquipmentCount + ' 件，资料原值 ¥' + (this.work.value.equipmentValueCents / 100).toFixed(2) + '，未计入支出'),
            hint: this.hint,
            effects: this.effects,
            contentPadding: 14,
            action: (): void => {
                this.open();
            },
            content: (): void => this.body(),
        }).id('work-card:' + this.work.value.projectId)
    }
}
