import { AppState } from '../../../../main/ets/common/AppState';
import { SettingsPage } from '../../../../main/ets/features/settings/SettingsPage';
import { HomePage } from '../../../../main/ets/features/home/HomePage';
import { Character, CosProject, CosEvent, ChecklistItem, PhotoAsset } from '../../../../main/ets/model/Entities';
import { PreparationCategory, PreparationTask } from '../../../../main/ets/model/Preparation';
import { Theme } from '../../../../main/ets/common/Theme';
import { common } from '@kit.AbilityKit';

function homeFixture(): AppState {
  const state = new AppState();
  state.settings.username = '布局验证';
  const character = new Character(); character.name = '布局验证角色';
  const project = new CosProject(); project.characterId = character.id; project.name = '布局验证计划';
  const event = new CosEvent(); event.name = '布局验证活动'; event.date = '2099-10-07'; event.city = '测试城市';
  const category = new PreparationCategory(); category.projectId = project.id; category.name = '服装';
  state.characters = [character]; state.projects = [project]; state.events = [event];
  state.preparationCategories = [category];
  for (let index = 0; index < 3; index++) {
    const task = new PreparationTask(); task.projectId = project.id; task.categoryId = category.id;
    task.label = '准备任务 ' + index; task.sortOrder = index;
    state.preparationTasks.push(task);
    const item = new ChecklistItem(); item.projectId = project.id; item.label = '打包物品 ' + index; item.sortOrder = index;
    state.checklist.push(item);
    const photo = new PhotoAsset(); photo.id = 'layout-photo-' + index; photo.projectId = project.id;
    state.photos.push(photo);
  }
  return state;
}

// Layout fixtures use the production component with in-memory state only.
// Scaling fits a 920vp canvas on the phone; it does not claim tablet safe-area validation.
@Entry
@ComponentV2
struct SettingsLayout {
  @Local state: AppState = new AppState();
  @Local homeState: AppState = homeFixture();
  @Local home: boolean = false;
  @Local routeResult: string = '';
  @Local requestedWidth: number = 378;
  @Local hostWidth: number = 378;
  @Local hostHeight: number = 700;
  private setFontScale(scale: number): void {
    (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext().setFontSizeScale(scale);
  }
  private scaleRatio(): number { return Math.min(1, this.hostWidth / this.requestedWidth); }
  private canvasHeight(): number { return this.requestedWidth >= 840 ? 680 : Math.min(760, this.hostHeight); }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('窄屏').id('layout-width-narrow').onClick((): void => { this.requestedWidth = 320; })
        Button('手机').id('layout-width-phone').onClick((): void => { this.requestedWidth = 378; })
        Button('宽屏').id('layout-width-wide').onClick((): void => { this.requestedWidth = 920; })
      }.height(48).width('100%').justifyContent(FlexAlign.Center)
      Row({ space: 8 }) {
        Button('设置').id('layout-page-settings').onClick((): void => { this.home = false; })
        Button('首页').id('layout-page-home').onClick((): void => { this.home = true; })
      }.height(40).width('100%').justifyContent(FlexAlign.Center)
      Row({ space: 8 }) {
        Button('默认字').id('layout-font-default').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(1))
        Button('大字体').id('layout-font-large').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(2))
        Text('字号验证').id('layout-font-probe').fontSize(16)
      }.height(40).width('100%').justifyContent(FlexAlign.Center)
      Text(this.routeResult || '未打开任务').id('layout-route-result').height(24).fontSize(12).fontColor(Theme.muted)
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          if (this.home) {
            HomePage({
              state: this.homeState, active: true, bottomInset: Theme.homeContentBottom,
              open: (kind: string, id: string): void => { this.routeResult = kind + ':' + id; },
            })
          } else {
            SettingsPage({ state: this.state })
          }
        }
          .width(this.requestedWidth).height(this.canvasHeight())
          .scale({ x: this.scaleRatio(), y: this.scaleRatio(), centerX: 0, centerY: 0 })
          .id('settings-layout-canvas')
      }.layoutWeight(1).width('100%').clip(true)
        .onAreaChange((_, area: Area): void => { this.hostWidth = Number(area.width); this.hostHeight = Number(area.height); })
    }.width('100%').height('100%').backgroundColor(Theme.bg)
  }
}
