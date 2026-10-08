import { PROJECT_LABELS, PROJECT_STATUSES } from '../common/constants';
import { PressFeedback } from '../common/pressFeedback';
import { ManagedImage } from './ManagedImage';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { CosProject, Character } from '../model/Entities';
import { InteractiveCard, StatusPill } from './Surfaces';

@ComponentV2
export struct ProjectCard {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Param hero: boolean = false;
  @Param project: CosProject = new CosProject();
  @Event open: () => void = () => {};
  private character(): Character | undefined { return this.state.characters.find((c: Character) => c.id === this.project.characterId); }
  @Builder body() {
    Row({ space: 16 }) {
      if (this.character()?.cover) {
        ManagedImage({
          sourcePath: this.character()?.cover || '',
          label: this.state.characterName(this.project.characterId) + '角色封面'
        }).width(76).height(96).borderRadius(14).accessibilityText(this.state.characterName(this.project.characterId) + '角色封面')
      } else {
        Text(this.state.characterName(this.project.characterId)
          .slice(0, 1))
          .width(76)
          .height(96)
          .fontSize(32)
          .fontWeight(FontWeight.Lighter)
          .fontColor(Theme.accent)
          .textAlign(TextAlign.Center)
          .backgroundColor(Theme.tint)
          .borderRadius(14)
          .accessibilityLevel('no')
          .visualEffect(this.feedback.effect('character-placeholder'))
          .compositingFilter(this.feedback.filter('character-placeholder'))
          .attributeModifier(this.feedback.control('character-placeholder'))
      }
      Column({ space: 8 }) {
        StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
        Text(this.project.name)
          .fontSize(this.hero ? 23 : 19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.state.characterName(this.project.characterId) + (this.project.variantId ? ' / ' + (this.state.variants.find((variant) => variant.id === this.project.variantId)?.name || '版本已不存在') : '')).fontSize(13).fontColor(Theme.muted)
        Text(this.state.readiness(this.project.id).prep
          .total === 0 ? '尚未添加准备任务' : this.state.readiness(this.project.id).prep
          .done + ' / ' + this.state.readiness(this.project.id).prep
          .total + ' 项准备完成')
          .fontSize(12)
          .fontColor(Theme.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%')
    Text((this.state.readiness(this.project.id).date || '日期待定') + (this.state.readiness(this.project.id).dateFromEvent ? ' · 来自活动' : '')).fontSize(14).fontColor(Theme.muted)
    if (this.state.readiness(this.project.id).blockers.length || this.state.readiness(this.project.id).prep.next) {
      Text(this.state.readiness(this.project.id).blockers[0] || '下一项 · ' + (this.state.readiness(this.project.id).prep.next?.label || '')).fontSize(14).fontColor(Theme.accent)
    }
    if (this.state.readiness(this.project.id).prep.total > 8) {
      Progress({ value: this.state.preparationPercent(this.project.id), total: 100, type: ProgressType.Linear }).color(Theme.brand).backgroundColor(Theme.tint).width('100%').margin({ top: 12 })
        .accessibilityText('准备任务完成 ' + this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total + ' 项')
    }
  }
  build() { InteractiveCard({
      label: this.project.name,
      hint: '双击打开计划详情',
      effects: this.state.settings.effects,
      action: () => this.open(),
      content: (): void => this.body()
    }) }
}
