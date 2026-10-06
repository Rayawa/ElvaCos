import { ManagedImage } from '../../components/ManagedImage';
import { pageTransition } from '../../common/motion';
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
  private async favorite(): Promise<void> { const c = JSON.parse(JSON.stringify(this.character)) as Character; c.favorite = !c.favorite; await this.state.saveCharacter(c); }
  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(Theme.contentTop).width('100%')
        if (this.character.cover) { ManagedImage({ sourcePath: this.character.cover, label: this.character.name + '角色封面', ratio: 1.3, radius: Theme.cardRadius }).width('100%').aspectRatio(1.3).borderRadius(Theme.cardRadius).accessibilityText(this.character.name + '角色封面') }
        Text(this.character.name).fontSize(32).fontWeight(FontWeight.Bold).fontColor(Theme.ink)
        Text(this.character.workName || '属于你的角色故事').fontSize(15).fontColor(Theme.muted)
        if (this.character.description) { Text(this.character.description).fontSize(14).fontColor(Theme.muted) }
        Row({ space: 10 }) {
          Button(this.character.favorite ? '★ 已收藏' : '☆ 收藏').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => this.favorite())
        }
        Text('在关联计划的照片详情中，可将照片设为角色封面。').fontSize(12).fontColor(Theme.muted)
        SectionHeading({ title: '角色版本' })
        ForEach(this.state.variants.filter((v: CharacterVariant) => v.characterId === this.character.id), (v: CharacterVariant) => {
          Row({ space: 10 }) { Column({ space: 6 }) { Text(v.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.ink); if (v.notes) { Text(v.notes).fontSize(13).fontColor(Theme.muted) } }.layoutWeight(1).alignItems(HorizontalAlign.Start); Button('编辑').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(() => this.edit('variant', v.id, this.character.id)); Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).onClick(() => this.remove('variant', v.id)).accessibilityText('删除版本 ' + v.name) }.width('100%').padding(16).backgroundColor(Theme.surface).borderRadius(18)
        }, (v: CharacterVariant) => v.id)
        SectionHeading({ title: '登场计划' })
        ForEach(this.state.projects.filter((p: CosProject) => p.characterId === this.character.id), (p: CosProject) => { ProjectCard({ state: this.state, project: p, open: () => this.open('project', p.id) }) }, (p: CosProject) => p.id)
        if (!this.state.projects.some((p: CosProject) => p.characterId === this.character.id)) { EmptyState({ title: '从喜欢到登场', message: '为这个角色创建一份计划，把准备过程留存下来。' }) }
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: Theme.pagePadding, right: Theme.pagePadding, bottom: Theme.contentBottom })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
  }
}
