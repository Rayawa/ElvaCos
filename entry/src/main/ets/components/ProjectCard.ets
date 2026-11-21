import { displayName } from '../utils/format';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../models/constants';
import { ManagedImage } from './ManagedImage';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { CosProject, Character, ProjectStatus } from '../models/Entities';
import { InteractiveCard, PillTone, StatusPill } from './Surfaces';
import { ContextRow } from './ContextRow';
import { MetaRow } from './MetaRow';

@ComponentV2
export struct ProjectCard {
    @Require @Param state: AppState;
    @Param hero: boolean = false;
    @Param project: CosProject = new CosProject();
    @Event open: () => void = () => {};

    private character(): Character | undefined {
        return this.state.characters.find((c: Character) => c.id === this.project.characterId);
    }

    private statusTone(): PillTone {
        if (this.project.status === ProjectStatus.COMPLETED || this.project.status === ProjectStatus.READY) {
            return 'success';
        }
        if (this.project.status === ProjectStatus.SHOOTING || this.project.status === ProjectStatus.EVENT) {
            return 'warning';
        }
        if (this.project.status === ProjectStatus.ARCHIVED) {
            return 'neutral';
        }
        return 'brand';
    }

    private versionSummary(): string {
        const base = this.state.characterName(this.project.characterId);
        if (!this.project.variantId) {
            return base;
        }
        const variant = this.state.variants.find((item) => item.id === this.project.variantId)?.name || '版本已不存在';
        return base + ' / ' + variant;
    }

    @Builder body() {
        Column({ space: 12 }) {
            Row({ space: 14 }) {
                if (this.character()?.cover) {
                    ManagedImage({ sourcePath: this.character()?.cover || '', label: this.state.characterName(this.project.characterId) + '角色封面', radius: 12 })
                        .width(68)
                        .height(88)
                } else {
                    Stack({ alignContent: Alignment.Center }) {
                        Text(this.state.characterName(this.project.characterId).slice(0, 1))
                            .fontSize(26)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.accent)
                    }.width(68)
                        .height(88)
                        .backgroundColor(Theme.tint)
                        .borderRadius(12)
                        .accessibilityLevel('no')
                }
                Column({ space: 6 }) {
                    Row({ space: 8 }) {
                        Text(displayName(this.project.name))
                            .fontSize(this.hero ? 20 : 17)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.ink)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        StatusPill({
                            label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] || '筹备中',
                            tone: this.statusTone(),
                            compact: !this.hero,
                        })
                    }.width('100%')
                        .alignItems(VerticalAlign.Top)
                    Text(displayName(this.versionSummary()))
                        .fontSize(13)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 12 }) {
                        MetaRow({
                            icon: Icons.event,
                            text: this.state.readiness(this.project.id).date || '日期待定',
                        })
                        if (this.state.readiness(this.project.id).prep.total > 0) {
                            MetaRow({
                                icon: Icons.check,
                                text: '准备 ' + this.state.readiness(this.project.id).prep.done + '/' + this.state.readiness(this.project.id).prep.total,
                                color: this.state.readiness(this.project.id).prep.done >= this.state.readiness(this.project.id).prep.total ? Theme.success : Theme.accent,
                            })
                        }
                    }
                    if (this.state.readiness(this.project.id).prep.total > 0) {
                        Progress({
                            value: this.state.readiness(this.project.id).prep.done,
                            total: Math.max(1, this.state.readiness(this.project.id).prep.total),
                            type: ProgressType.Linear,
                        }).width('100%')
                            .color(this.state.readiness(this.project.id).prep.done >= this.state.readiness(this.project.id).prep.total ? Theme.success : Theme.brand)
                            .backgroundColor(Theme.tint)
                            .style({ strokeWidth: 4 })
                    }
                }.layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
            }.width('100%')
            if (this.state.readiness(this.project.id).hint) {
                ContextRow({
                    label: this.state.readiness(this.project.id).hint!.label,
                    text: displayName(this.state.readiness(this.project.id).hint!.text),
                })
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }

    build() {
        InteractiveCard({
            label: this.project.name,
            hint: '双击打开计划详情',
            effects: this.state.settings.effects,
            hero: this.hero,
            elevated: true,
            contentPadding: 14,
            action: () => this.open(),
            content: (): void => this.body(),
        }).id('project-card:' + this.project.id)
    }
}
