import { ManagedImage } from './ManagedImage';
import { AppState } from '../common/AppState';
import { Theme } from '../common/Theme';
import { CosProject, Character, PROJECT_LABELS, PROJECT_STATUSES } from '../model/Entities';
import { InteractiveCard, StatusPill } from './Surfaces';
import { preparationProgress } from '../model/Preparation';

@ComponentV2
export struct ProjectCard {
  @Param state: AppState = new AppState();
  @Param project: CosProject = new CosProject();
  @Param hero: boolean = false;
  @Event open: () => void = () => {};
  private character(): Character | undefined { return this.state.characters.find((c: Character) => c.id === this.project.characterId); }
  @Builder body() {
    Row({ space: 16 }) {
      if (this.character()?.cover) {
        ManagedImage({ sourcePath: this.character()?.cover || '', label: this.state.characterName(this.project.characterId) + '角色封面' }).width(76).height(96).borderRadius(14).accessibilityText(this.state.characterName(this.project.characterId) + '角色封面')
      } else {
        Text(this.state.characterName(this.project.characterId).slice(0, 1)).width(76).height(96).fontSize(32).fontWeight(FontWeight.Lighter).fontColor(Theme.accent).textAlign(TextAlign.Center).backgroundColor(Theme.tint).borderRadius(14).accessibilityLevel('no')
      }
      Column({ space: 8 }) {
        StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
        Text(this.project.name).fontSize(this.hero ? 23 : 19).fontWeight(FontWeight.Bold).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.state.characterName(this.project.characterId)).fontSize(13).fontColor(Theme.muted)
        Text(preparationProgress(this.project.id, this.state.preparationTasks).total === 0 ? '尚未添加准备任务' : preparationProgress(this.project.id, this.state.preparationTasks).ready + ' / ' + preparationProgress(this.project.id, this.state.preparationTasks).total + ' 项准备完成').fontSize(12).fontColor(Theme.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) { Text(preparationProgress(this.project.id, this.state.preparationTasks).total === 0 ? '待设置' : this.state.preparationPercent(this.project.id) + '%').fontSize(25).fontWeight(FontWeight.Lighter).fontColor(Theme.accent); Text('准备进度').fontSize(10).fontColor(Theme.muted) }
    }.width('100%')
    Progress({ value: this.state.preparationPercent(this.project.id), total: 100, type: ProgressType.Linear }).color(Theme.accent).backgroundColor(Theme.tint).width('100%').margin({ top: 16 }).accessibilityText('准备进度 ' + this.state.preparationPercent(this.project.id) + '%')
  }
  build() { InteractiveCard({ label: this.project.name, hint: '双击打开计划详情', hero: this.hero, effects: this.state.settings.effects, action: () => this.open(), content: (): void => this.body() }) }
}
