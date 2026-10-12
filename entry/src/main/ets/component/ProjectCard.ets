import { displayName } from '../common/format';
import { PROJECT_LABELS, PROJECT_STATUSES } from '../common/constants';
import { ManagedImage } from './ManagedImage';
import { AppState } from '../model/ApplicationState';
import { Theme } from '../common/Theme';
import { CosProject, Character } from '../model/Entities';
import { InteractiveCard, StatusPill } from './Surfaces';
import { ContextRow } from './ContextRow';

@ComponentV2
export struct ProjectCard {
  @Require @Param state: AppState;
  @Param hero: boolean = false;
  @Param project: CosProject = new CosProject();
  @Event open: () => void = () => {};
  private character(): Character | undefined { return this.state.characters.find((c: Character) => c.id === this.project.characterId); }
  @Builder body() {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        if (this.character()?.cover) {
          ManagedImage({ sourcePath: this.character()?.cover || '', label: this.state.characterName(this.project.characterId) + '角色封面' })
            .width(68).height(88).borderRadius(12)
        } else {
          Text(this.state.characterName(this.project.characterId).slice(0, 1))
            .width(68).height(88).fontSize(30).fontColor(Theme.accent).textAlign(TextAlign.Center)
            .backgroundColor(Theme.tint).borderRadius(12).accessibilityLevel('no')
        }
        Column({ space: 6 }) {
          Text(displayName(this.project.name)).fontSize(this.hero ? 23 : 19).fontWeight(FontWeight.Medium).fontColor(Theme.ink)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(displayName(this.state.characterName(this.project.characterId) + (this.project.variantId ? ' / ' + (this.state.variants.find((variant) => variant.id === this.project.variantId)?.name || '版本已不存在') : '')))
            .fontSize(14).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 8 }) {
            StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
            Text(this.state.readiness(this.project.id).date || '日期待定').fontSize(14).fontColor(Theme.muted)
            if (this.state.readiness(this.project.id).prep.total) { Text(this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total).fontSize(13).fontColor(Theme.muted).accessibilityText('准备完成 ' + this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total + ' 项') }
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (this.state.readiness(this.project.id).hint) {
        ContextRow({ label: this.state.readiness(this.project.id).hint!.label, text: displayName(this.state.readiness(this.project.id).hint!.text) })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() { InteractiveCard({
      label: this.project.name,
      hint: '双击打开计划详情',
      effects: this.state.settings.effects, contentPadding: 16,
      action: () => this.open(),
      content: (): void => this.body()
    }) }
}
