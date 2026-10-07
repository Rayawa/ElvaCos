import { PressFeedback } from '../../common/pressFeedback';
import { StaggerEntrance } from '../../common/motion';
import { ReferenceGallery } from '../../component/ReferenceGallery';
import { ReferenceImage } from '../../model/Planning';
import { ManagedImage } from '../../component/ManagedImage';
import { pageTransition } from '../../common/motion';
import { vibration } from '../../common/vibration';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { Character, CharacterVariant, CosProject } from '../../model/Entities';
import { SectionHeading, EmptyState } from '../../component/Surfaces';
import { ProjectCard } from '../../component/ProjectCard';

@ComponentV2
export struct CharacterDetail {
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Param character: Character = new Character();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  aboutToAppear(): void { if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (!this.entrance.managed) { this.entrance.reset(); } }
  private async favorite(): Promise<void> { const c = JSON.parse(JSON.stringify(this.character)) as Character; c.favorite = !c.favorite; await this.state.saveCharacter(c); }
  private variants(): CharacterVariant[] { return this.state.variants.filter((v: CharacterVariant) => v.characterId === this.character.id); }
  private projects(): CosProject[] { return this.state.projects.filter((p: CosProject) => p.characterId === this.character.id); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 12 }) {
          if (this.character.cover) { ManagedImage({
              large: true,
              sourcePath: this.character.cover,
              label: this.character.name + '角色封面',
              ratio: 1.3,
              radius: Theme.cardRadius
            }).width('100%').aspectRatio(1.3).borderRadius(Theme.cardRadius).accessibilityText(this.character.name + '角色封面') }
          Row({ space: 8 }) {
            Text(this.character.name)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.ink)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.character.workName) { Text(this.character.workName)
              .fontSize(13)
              .fontColor(Theme.muted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }) }
            Button(this.character.favorite ? '★ 已收藏' : '☆ 收藏')
              .fontSize(13)
              .constraintSize({ minHeight: 36 })
              .backgroundColor(Theme.tint)
              .fontColor(Theme.accent)
              .onClick((): void => { vibration.dotVibration(); this.favorite(); })
              .accessibilityText(this.character.favorite ? '取消收藏 ' + this.character.name : '收藏 ' + this.character.name)
                .visualEffect(this.feedback.effect('button-1'))
                .compositingFilter(this.feedback.filter('button-1'))
                .attributeModifier(this.feedback.control('button-1'))
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.character.description) { Text(this.character.description).fontSize(14).fontColor(Theme.muted) }
        }.
      width('100%').alignItems(HorizontalAlign.Start).opacity(this.entrance.step >= 1 ? 1 : 0).translate({ y: this.entrance.step >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          ReferenceGallery({
            state: this.state,
            images: this.state.references.filter((r: ReferenceImage) => r.characterId === this.character.id),
            add: (): void => { this.state.importReferences('', this.character.id); },
            open: (id: string): void => this.open('reference', id)
          })
          SectionHeading({ title: '角色版本', trailing: this.variants().length + ' 个' })
          ForEach(this.variants(), (v: CharacterVariant) => {
            Row({ space: 10 }) {
              Column({ space: 6 }) { Text(v.name)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink); if (v.notes) { Text(v.notes)
                .fontSize(13)
                .fontColor(Theme.muted) } }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              Button('编辑')
                .backgroundColor(Theme.tint)
                .fontColor(Theme.accent)
                .onClick((): void => { vibration.dotVibration(); this.edit('variant', v.id, this.character.id); })
                .accessibilityText('编辑版本 ' + v.name)
                .visualEffect(this.feedback.effect('button-3' + ":" + v.id))
                .compositingFilter(this.feedback.filter('button-3' + ":" + v.id))
                .attributeModifier(this.feedback.control('button-3' + ":" + v.id))
              Button('−')
                .backgroundColor(Theme.bg)
                .fontColor(Theme.muted)
                .onClick((): void => { vibration.dotVibration(); this.remove('variant', v.id); })
                .accessibilityText('删除版本 ' + v.name)
                .visualEffect(this.feedback.effect('button-4' + ":" + v.id))
                .compositingFilter(this.feedback.filter('button-4' + ":" + v.id))
                .attributeModifier(this.feedback.control('button-4' + ":" + v.id))
            }.
          width('100%').padding(16).backgroundColor(Theme.surface).borderRadius(18).visualEffect(this.feedback.effect('row-2' + ":" + v.id, true)).compositingFilter(this.feedback.filter('row-2' + ":" + v.id, true)).attributeModifier(this.feedback.control('row-2' + ":" + v.id, true))
          }, (v: CharacterVariant) => v.id)
          SectionHeading({ title: '登场计划', trailing: this.projects().length + ' 份' })
          ForEach(this.projects(), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
          if (this.projects().length === 0) { EmptyState({ title: '从喜欢到登场', message: '为这个角色创建一份计划，把准备过程留存下来。' }) }
        }.
      width('100%').alignItems(HorizontalAlign.Start).opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.
    constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
