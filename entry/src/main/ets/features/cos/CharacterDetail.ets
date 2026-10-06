import { ManagedImage } from '../../components/ManagedImage';
import { pageTransition, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { vibration } from '../../common/vibration';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { Character, CharacterVariant, CosProject } from '../../model/Entities';
import { SectionHeading, EmptyState } from '../../components/Surfaces';
import { ProjectCard } from '../../components/ProjectCard';

@ComponentV2
export struct CharacterDetail {
  @Param state: AppState = new AppState();
  @Param character: Character = new Character();
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local animStep: number = 0;
  private enterTimers: number[] = [];
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }
  private async favorite(): Promise<void> { const c = JSON.parse(JSON.stringify(this.character)) as Character; c.favorite = !c.favorite; await this.state.saveCharacter(c); }
  private variants(): CharacterVariant[] { return this.state.variants.filter((v: CharacterVariant) => v.characterId === this.character.id); }
  private projects(): CosProject[] { return this.state.projects.filter((p: CosProject) => p.characterId === this.character.id); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.detailTop).width('100%')
        Column({ space: 12 }) {
          if (this.character.cover) { ManagedImage({ sourcePath: this.character.cover, label: this.character.name + '角色封面', ratio: 1.3, radius: Theme.cardRadius }).width('100%').aspectRatio(1.3).borderRadius(Theme.cardRadius).accessibilityText(this.character.name + '角色封面') }
          Row({ space: 8 }) {
            Text(this.character.name).fontSize(20).fontWeight(FontWeight.Medium).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (this.character.workName) { Text(this.character.workName).fontSize(13).fontColor(Theme.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }
            Button(this.character.favorite ? '★ 已收藏' : '☆ 收藏').fontSize(13).constraintSize({ minHeight: 36 }).backgroundColor(Theme.tint).fontColor(Theme.accent)
              .onClick((): void => { vibration.dotVibration(); this.favorite(); })
              .accessibilityText(this.character.favorite ? '取消收藏 ' + this.character.name : '收藏 ' + this.character.name)
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.character.description) { Text(this.character.description).fontSize(14).fontColor(Theme.muted) }
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          Text('在关联计划的照片详情中，可将照片设为角色封面。').fontSize(12).fontColor(Theme.muted)
          SectionHeading({ title: '角色版本', trailing: this.variants().length + ' 个' })
          ForEach(this.variants(), (v: CharacterVariant) => {
            Row({ space: 10 }) {
              Column({ space: 6 }) { Text(v.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink); if (v.notes) { Text(v.notes).fontSize(13).fontColor(Theme.muted) } }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Button('编辑').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.edit('variant', v.id, this.character.id); }).accessibilityText('编辑版本 ' + v.name)
              Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).onClick((): void => { vibration.dotVibration(); this.remove('variant', v.id); }).accessibilityText('删除版本 ' + v.name)
            }.width('100%').padding(16).backgroundColor(Theme.surface).borderRadius(18)
          }, (v: CharacterVariant) => v.id)
          SectionHeading({ title: '登场计划', trailing: this.projects().length + ' 份' })
          ForEach(this.projects(), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
          if (this.projects().length === 0) { EmptyState({ title: '从喜欢到登场', message: '为这个角色创建一份计划，把准备过程留存下来。' }) }
        }.width('100%').alignItems(HorizontalAlign.Start).opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
