import { HdsNavigation } from '@kit.UIDesignKit';
import { PressFeedback } from '../../../../main/ets/common/pressFeedback';
import { StaggerEntrance } from '../../../../main/ets/common/motion';
import { DetailDestination } from '../../../../main/ets/component/DetailDestination';
import { SheetHeader } from '../../../../main/ets/component/SheetHeader';
import { SystemCapability } from '../../../../main/ets/common/SystemCapability';
import { appSheetOptions } from '../../../../main/ets/common/sheet';
import { AppState } from '../../../../main/ets/model/ApplicationState';
import { SettingsPage } from '../../../../main/ets/pages/more/SettingsPage';
import { ExpenseSummary } from '../../../../main/ets/pages/more/ExpenseSummaryPage';
import { Expense } from '../../../../main/ets/model/Planning';
import { HomePage } from '../../../../main/ets/pages/main/HomePage';
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

function expenseFixture(): AppState {
  const state = new AppState();
  const project = new CosProject(); project.name = '统计验证计划'; project.budgetCents = 500;
  const second = new CosProject(); second.name = '第二份统计计划';
  state.projects = [project, second];
  const clothing = new Expense(); clothing.id = 'chart-clothing'; clothing.projectId = project.id;
  clothing.name = '服装记录'; clothing.category = '服装'; clothing.amountCents = 300;
  const photo = new Expense(); photo.id = 'chart-photo'; photo.projectId = second.id;
  photo.name = '摄影记录'; photo.category = '摄影'; photo.amountCents = 100;
  const zero = new Expense(); zero.id = 'chart-zero'; zero.projectId = project.id;
  zero.name = '零值记录'; zero.category = '其他'; zero.amountCents = 0;
  state.expenses = [clothing, photo, zero];
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
  @Local statistics: boolean = false;
  @Local statisticsState: AppState = expenseFixture();
  @Local shortWindow: boolean = false;
  @Local feedbackFixture: boolean = false;
  @Local routeResult: string = '';
  @Local requestedWidth: number = 378;
  @Local hostWidth: number = 378;
  @Local hostHeight: number = 700;
  private setFontScale(scale: number): void {
    (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext().setFontSizeScale(scale);
  }
  private scaleRatio(): number { return Math.min(1, this.hostWidth / this.requestedWidth); }
  private canvasHeight(): number { return this.shortWindow ? 420 : this.requestedWidth >= 840 ? 680 : Math.min(760, this.hostHeight); }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('窄屏').id('layout-width-narrow').fontSize(12).maxFontScale(1).onClick((): void => { this.requestedWidth = 320; this.shortWindow = false; })
        Button('手机').id('layout-width-phone').fontSize(12).maxFontScale(1).onClick((): void => { this.requestedWidth = 378; this.shortWindow = false; })
        Button('宽屏').id('layout-width-wide').fontSize(12).maxFontScale(1).onClick((): void => { this.requestedWidth = 920; this.shortWindow = false; })
        Button('横屏').id('layout-width-short').fontSize(12).maxFontScale(1).onClick((): void => { this.requestedWidth = 920; this.shortWindow = true; })
      }.height(48).width('100%').justifyContent(FlexAlign.Center)
      Row({ space: 8 }) {
        Button('设置').id('layout-page-settings').fontSize(12).maxFontScale(1).onClick((): void => { this.home = false; this.feedbackFixture = false; this.statistics = false; })
        Button('首页').id('layout-page-home').fontSize(12).maxFontScale(1).onClick((): void => { this.home = true; this.feedbackFixture = false; this.statistics = false; })
        Button('动效').id('layout-page-feedback').fontSize(12).maxFontScale(1).onClick((): void => { this.feedbackFixture = true; this.statistics = false; })
        Button('统计').id('layout-page-statistics').fontSize(12).maxFontScale(1).onClick((): void => { this.statistics = true; this.feedbackFixture = false; this.statisticsState = expenseFixture(); })
      }.height(40).width('100%').justifyContent(FlexAlign.Center)
      Row({ space: 8 }) {
        Button('默认字').id('layout-font-default').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(1))
        Button('大字体').id('layout-font-large').fontSize(12).maxFontScale(1).onClick((): void => this.setFontScale(2))
        Text('字号验证').id('layout-font-probe').fontSize(16)
      }.height(40).width('100%').justifyContent(FlexAlign.Center)
      Text(this.routeResult || '未打开任务').id('layout-route-result').height(24).fontSize(12).fontColor(Theme.muted)
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          if (this.statistics) { ExpenseSummary({ state: this.statisticsState }) } else if (this.feedbackFixture) { FeedbackMotionFixture() } else if (this.home) {
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

// Native navigation / sheet lifecycle fixture; no application services or persistence.
@ComponentV2
struct MotionProbe {
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  @Param name: string = 'first';
  @Event next: () => void = () => {};
  @Local runs: number = 0;
  @Monitor('entrance.step')
  private changed(): void { if (this.entrance.step === 1) { this.runs++; } }
  build() {
    Column({ space: 16 }) {
      Text(this.name + ':' + this.runs + ':' + this.entrance.step).id('motion-' + this.name + '-probe')
      Button('下一级').id('motion-next').onClick((): void => this.next())
    }.width('100%').height('100%').padding({ top: 100 }).attributeModifier(this.entrance.group(1))
  }
}

@ComponentV2
struct FeedbackMotionFixture {
  private stack: NavPathStack = new NavPathStack();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  @Local sheetOpen: boolean = false;
  @Local sheetRuns: number = 0;
  @Local clicks: number = 0;
  @Local slider: number = 0;
  @Monitor('sheetEntrance.step')
  private changed(): void { if (this.sheetEntrance.step === 1) { this.sheetRuns++; } }
  @Builder destinationBody(name: string, entrance: StaggerEntrance) {
    MotionProbe({ entrance: entrance, name: name, next: (): void => { this.stack.pushPathByName('second', ''); } })
  }
  @Builder destination(name: string) {
    DetailDestination({
      titleOptions: SystemCapability.titleBar('动效验证', true),
      back: (): void => { this.stack.pop(); },
      content: this.destinationBody.bind(this, name),
    })
  }
  @Builder sheet() {
    Column({ space: 24 }) {
      SheetHeader({ title: '动效验证弹层', close: (): void => { this.sheetOpen = false; } })
      Text(this.sheetRuns + ':' + this.sheetEntrance.step).id('motion-sheet-probe')
    }.width('100%').height('100%').padding(24).attributeModifier(this.sheetEntrance.group(1))
  }
  build() {
    HdsNavigation(this.stack) {
      Column({ space: 16 }) {
        Button('测试按压').width(180).height(52).id('feedback-button').backgroundColor(Theme.accent)
          .onClick((): void => { this.clicks++; }).attributeModifier(this.feedback.control('button'))
        Text('点击 ' + this.clicks).id('feedback-clicks')
        Slider({ value: $$this.slider, min: 0, max: 2, step: 1 }).width(240).id('feedback-slider')
          .attributeModifier(this.feedback.control('slider'))
        Text('滑块 ' + this.slider).id('feedback-slider-value')
        Button('打开详情').id('motion-open-detail').onClick((): void => { this.stack.pushPathByName('first', ''); })
        Button('打开弹层').id('motion-open-sheet').onClick((): void => { this.sheetOpen = true; })
      }.padding(16).width('100%').height('100%').backgroundColor(Theme.surface)
        .bindSheet(this.sheetOpen, this.sheet(), appSheetOptions((): void => { this.sheetOpen = false; }, this.sheetEntrance, this.getUIContext()))
    }.mode(NavigationMode.Stack).hideTitleBar(true).navDestination(this.destination).width('100%').height('100%')
  }
}
