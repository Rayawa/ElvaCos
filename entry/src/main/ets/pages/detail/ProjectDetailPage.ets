import { WorkCard } from '../../component/WorkCard';
import { formatTimestamp } from '../../common/format';
import { DiaryEntry } from '../../model/Entities';
import { ProjectStatus } from '../../model/Entities';
import { EntryCollection } from '../../component/EntryCollection';
import { budgetLabel } from '../../model/PlanReadiness';
import { ASSET_STATUSES, ASSET_STATUS_LABELS, PROJECT_LABELS, PROJECT_STATUSES } from '../../common/constants';
import { PressFeedback } from '../../common/pressFeedback';
import { StaggerEntrance } from '../../common/motion';
import { TeamMember, Expense, ReferenceImage } from '../../model/Planning';
import { ReferenceGallery } from '../../component/ReferenceGallery';
import { PreparationCategory, PreparationTask, preparationKeys } from '../../model/Preparation';
import { PreparationTemplatePicker } from '../../component/PreparationTemplatePicker';
import { pageTransition } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../component/SheetHeader';
import { confirm } from '../../common/Confirm';
import { AppState } from '../../model/ApplicationState';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { Asset, AssetStatus, ChecklistItem, CosProject, CosEvent } from '../../model/Entities';
import { ProjectRoute } from '../../model/ProjectRoute';
import { SectionHeading, StatusPill, EmptyState } from '../../component/Surfaces';
import { planDate } from '../../model/Rules';
import { HapticService } from '../../common/HapticService';

@ComponentV2
export struct ProjectDetail {
  @Local sheetEntrance: StaggerEntrance = new StaggerEntrance();
  private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
  @Require @Param state: AppState;
  @Param project: CosProject = new CosProject();
  @Param route: ProjectRoute = new ProjectRoute('');
  @Param topInset: number = Theme.detailTop;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local templateKeys: string[] = preparationKeys(1);
  @Local templateMode: number = 1;
  @Param entrance: StaggerEntrance = new StaggerEntrance();
  private scroller: Scroller = new Scroller();
  private displayedSection: number = 0;
  private viewportTop: number = 0;
  private measured: boolean = false;
  private focusY: number | undefined = undefined;
  private scrollTimer: number = -1;
  private restoring: boolean = true;
  @Local focusFeedback: string = '';
  aboutToAppear(): void {
    this.displayedSection = this.route.section;
    const target = this.state.preparationTasks.find((task: PreparationTask) => task.id === this.route.focusTaskId && task.projectId === this.project.id);
    if (target && !this.route.expandedCategories.includes(target.categoryId)) { this.route.expandedCategories = this.route.expandedCategories.concat(target.categoryId); }
    if (target?.done) { this.route.showCompleted = true; }
    const packing = this.state.checklist.some((item: ChecklistItem) => item.id === this.route.focusPackingId && item.projectId === this.project.id);
    if (!this.route.focusHandled && (this.route.focusTaskId && !target || this.route.focusPackingId && !packing)) {
      this.route.focusHandled = true; this.focusFeedback = '原事项已不存在，保留当前计划与附近位置。';
    }
    this.restoreOffset();
    if (!this.entrance.managed) { this.entrance.play(this.getUIContext()); } }
  aboutToDisappear(): void { if (this.scrollTimer >= 0) { clearTimeout(this.scrollTimer); } if (!this.entrance.managed) { this.entrance.reset(); } }
  @Monitor('route.section', 'route.restoreVersion')
  private sectionChanged(): void { this.displayedSection = this.route.section; this.restoreOffset(); }
  private pendingFocus(): boolean {
    return !this.route.focusHandled && Boolean(this.route.section === 1 ? this.route.focusTaskId : this.route.section === 2 ? this.route.focusPackingId : '');
  }
  private restoreOffset(): void {
    if (!this.measured || this.pendingFocus()) { return; }
    if (this.scrollTimer >= 0) { clearTimeout(this.scrollTimer); } this.restoring = true;
    this.scrollTimer = setTimeout((): void => { this.scrollTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.displayedSection], animation: false }); this.restoring = false; }, 0);
  }
  private focusItem(id: string, area: Area): void {
    if (!this.pendingFocus() || id !== (this.route.section === 2 ? this.route.focusPackingId : this.route.focusTaskId)) { return; }
    this.focusY = Number(area.globalPosition.y); this.focusAfterMeasure();
  }
  private focusAfterMeasure(): void {
    if (!this.measured || this.focusY === undefined || !this.pendingFocus()) { return; }
    if (this.scrollTimer >= 0) { clearTimeout(this.scrollTimer); } this.restoring = true;
    this.scrollTimer = setTimeout((): void => {
      this.scrollTimer = -1;
      if (!this.pendingFocus() || this.focusY === undefined) { this.restoreOffset(); return; }
      const offset = Math.max(0, this.scroller.currentOffset().yOffset + this.focusY - this.viewportTop - this.topInset - 12);
      this.scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false }); this.route.offsets[this.displayedSection] = offset;
      this.route.focusHandled = true; this.focusY = undefined; this.restoring = false;
    }, 0);
  }

  private items(): ChecklistItem[] {
    const items = this.state.checklist.filter((item: ChecklistItem) => item.projectId === this.project.id).sort((a: ChecklistItem, b: ChecklistItem) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
    for (const item of items) { if (!this.route.packingOrder.includes(item.id)) { this.route.packingOrder.push(item.id); } }
    return items.sort((a: ChecklistItem, b: ChecklistItem) => this.route.packingOrder.indexOf(a.id) - this.route.packingOrder.indexOf(b.id));
  }
  private equipment(): Asset[] { return this.state.projectAssets(this.project.id)
    .sort((a: Asset, b: Asset) => Number(a.status === AssetStatus.OWNED) - Number(b.status === AssetStatus.OWNED) || a.name.localeCompare(b.name)); }
  private linked(asset: Asset): boolean { return this.state.projectAssets(this.project.id).some((a: Asset) => a.id === asset.id); }
  private location(item: ChecklistItem): string { return this.state.assets.find((a: Asset) => a.id === item.assetId)?.location || (item.assetId ? '存放位置待补充' : '随身物品'); }
  private packingAssetStatus(item: ChecklistItem): string { const asset = this.state.assets.find((value: Asset) => value.id === item.assetId); return asset ? ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] : '装备已不存在'; }
  private async unlink(asset: Asset): Promise<void> {
    const usage = this.state.assetUsage(asset.id); const ids = usage.checklist.filter((item: ChecklistItem) => item.projectId === this.project.id).map((item: ChecklistItem) => item.id);
    if (await confirm(this.getUIContext(), '解除装备关联？', usage.unlinkMessage(this.project), '解除关联')) { await this.state.unlinkAsset(this.project.id, asset.id, ids); }
  }

  @Builder linkSheet() {
    Column({ space: 14 }) {
      SheetHeader({
        title: '从衣柜添加', hint: '已有装备可以在多份计划里复用',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.route.linking = false; },
      }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
      List({ space: 8 }) {
        ForEach(this.state.assets, (asset: Asset) => {
          ListItem() {
            Button() {
              Row() {
                Column({ space: 5 }) { Text(asset.name)
                  .fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '位置待补充'))
                  .fontSize(12)
                  .fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                Text(this.linked(asset) ? '已添加' : '＋ 添加').fontColor(Theme.accent)
              }.padding(16).width('100%')
            }.width('100%')
              .backgroundColor(Theme.bg)
              .enabled(!this.state.busy && !this.linked(asset))
              .onClick((): void => { vibration.dotVibration(); this.state.linkAsset(this.project.id, asset); })
              .accessibilityText('关联 ' + asset.name)
              .visualEffect(this.feedback.effect('link-asset:' + asset.id, true))
              .compositingFilter(this.feedback.filter('link-asset:' + asset.id, true))
              .attributeModifier(this.feedback.control('link-asset:' + asset.id, true))
          }
        }, (asset: Asset) => asset.id)
      }.layoutWeight(1).width('100%').opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
      if (this.state.assets.length === 0) { Text('衣柜还是空的，先添加一件装备。').fontSize(13).fontColor(Theme.muted) }
      Button('＋ 新装备')
        .accessibilityText('新装备')
        .width('100%')
        .backgroundColor(Theme.tint)
        .fontColor(Theme.accent)
        .enabled(!this.state.busy)
        .onClick((): void => { vibration.dotVibration(); this.route.linking = false; this.edit('asset', '', this.project.id); })
        .visualEffect(this.feedback.effect('button-2'))
        .compositingFilter(this.feedback.filter('button-2'))
        .attributeModifier(this.feedback.control('button-2'))
        .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
        .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
      Button('完成')
        .accessibilityText('完成')
        .width('100%')
        .backgroundColor(Theme.brand)
        .fontColor(Theme.onAccent)
        .onClick((): void => { vibration.dotVibration(); this.route.linking = false; })
        .visualEffect(this.feedback.effect('button-3'))
        .compositingFilter(this.feedback.filter('button-3'))
        .attributeModifier(this.feedback.control('button-3'))
        .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
        .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder checkButton(item: ChecklistItem) {
    Button(item.done ? '✓ 已装包' : '装包')
      .constraintSize({ minWidth: 88, minHeight: this.route.outing ? 64 : 48 })
      .backgroundColor(item.done ? Theme.tint : Theme.brand)
      .fontColor(item.done ? Theme.accent : Theme.onAccent)
      .enabled(!this.state.busy)
      .onClick((): void => { vibration.dotVibration(); this.state.toggleChecklist(item); })
        .accessibilityText(item.label + (item.done ? '，已装包，点击取消' : '，点击确认装包'))
        .visualEffect(this.feedback.effect('packing-confirm:' + item.id))
        .compositingFilter(this.feedback.filter('packing-confirm:' + item.id))
        .attributeModifier(this.feedback.control('packing-confirm:' + item.id))
  }

  @Builder activeSheet() {
    if (this.route.contextSheet) { this.contextSheet() }
    else if (this.route.sheetKind === 0) { this.preparationSheet() } else { this.linkSheet() }
  }

  /** 计划头：名称 + 状态 + 日期，替代原先的 26vp 大标题。 */
  @Builder header() {
    Row({ space: 10 }) {
      Text(this.project.name)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.ink)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
    }.width('100%').alignItems(VerticalAlign.Center)
    if (planDate(this.project, this.state.events)) { Text((this.state.readiness(this.project.id).dateFromEvent ? '日期来自活动 · ' : '计划日期 · ') + planDate(this.project, this.state.events)).fontSize(13).fontColor(Theme.muted) }
    if (this.project.eventId) {
      Button('活动 · ' + (this.state.events.find((e: CosEvent) => e.id === this.project.eventId)?.name || '未关联'))
        .backgroundColor(Theme.tint)
        .fontColor(Theme.accent)
        .fontSize(13)
        .constraintSize({ minHeight: 36 })
        .onClick((): void => { vibration.dotVibration(); this.open('event', this.project.eventId); })
        .accessibilityText('打开关联活动').visualEffect(this.feedback.effect('button-5')).compositingFilter(this.feedback.filter('button-5')).attributeModifier(this.feedback.control('button-5'))
    }
  }

  private categorySummary(id: string): string { const category = this.state.readiness(this.project.id).prep.categories.find((item) => item.id === id); return category ? category.done + '/' + category.total + ' 完成' : '尚未添加任务'; }
  private categories(): PreparationCategory[] { return this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.project.id); }
  private tasks(categoryId: string): PreparationTask[] { return this.state.preparationTasks.filter((t: PreparationTask) => t.categoryId === categoryId)
    .sort((a: PreparationTask, b: PreparationTask) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id)); }

  private visibleTasks(categoryId: string): PreparationTask[] {
    const tasks = this.tasks(categoryId);
    const visible = this.route.showCompleted ? tasks : tasks.filter((task: PreparationTask) => !task.done);
    return this.route.expandedCategories.includes(categoryId) ? visible : visible.slice(0, 1);
  }
  private expandCategory(id: string): void {
    vibration.dotVibration(); this.route.expandedCategories = this.route.expandedCategories.includes(id) ? this.route.expandedCategories.filter((key: string) => key !== id) : this.route.expandedCategories.concat(id);
  }
  @Builder preparationSheet() {
    Column({ space: 14 }) {
      SheetHeader({
        title: '准备任务',
        hint: '准备完成与装包确认分别记录',
        haptic: this.state.settings.haptic,
        hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.route.preparing = false; }
      }).opacity(this.sheetEntrance.step >= 1 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 1 ? 0 : 20 })
      Row({ space: 10 }) {
        Button('＋ 自定义分类')
          .accessibilityText('自定义分类')
          .layoutWeight(1)
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.route.preparing = false; this.edit('category', '', this.project.id); })
          .visualEffect(this.feedback.effect('button-6'))
          .compositingFilter(this.feedback.filter('button-6'))
          .attributeModifier(this.feedback.control('button-6'))
          .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
          .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
        Button('＋ 自定义任务')
          .accessibilityText('自定义任务')
          .layoutWeight(1)
          .backgroundColor(Theme.tint)
          .fontColor(Theme.accent)
          .enabled(!this.state.busy && this.categories()
          .length > 0)
          .onClick((): void => { vibration.dotVibration(); this.route.preparing = false; this.edit('preparation', '', this.project.id); })
          .visualEffect(this.feedback.effect('button-7'))
          .compositingFilter(this.feedback.filter('button-7'))
          .attributeModifier(this.feedback.control('button-7'))
          .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
          .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
      }.width('100%')
      Scroll() {
        PreparationTemplatePicker({
          keys: this.templateKeys,
          mode: this.templateMode,
          change: (keys: string[], mode: number): void => { this.templateKeys = keys; this.templateMode = mode; }
        })
      }.layoutWeight(1).width('100%').opacity(this.sheetEntrance.step >= 2 ? 1 : 0).translate({ y: this.sheetEntrance.step >= 2 ? 0 : 20 })
      Button(this.state.busy ? '添加中…' : '补入所选任务')
        .accessibilityText(this.state.busy ? '正在添加准备任务' : '补入所选准备任务')
        .width('100%')
        .backgroundColor(Theme.brand)
        .fontColor(Theme.onAccent)
        .enabled(!this.state.busy && this.templateKeys.length > 0)
        .onClick(async (): Promise<void> => { vibration.dotVibration(); if (await this.state.addPreparationTemplate(this.project.id, this.templateKeys)) { this.route.preparing = false; } })
          .visualEffect(this.feedback.effect('button-8'))
          .compositingFilter(this.feedback.filter('button-8'))
          .attributeModifier(this.feedback.control('button-8'))
          .opacity(this.sheetEntrance.step >= 3 ? 1 : 0)
          .translate({ y: this.sheetEntrance.step >= 3 ? 0 : 20 })
      Text('同名分类和任务不会重复添加，也不会重置已有完成状态。').fontSize(12).fontColor(Theme.muted)
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder preparation() {
    Column({ space: 12 }) {
      SectionHeading({ title: '准备', trailing: this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total + ' 项完成' })
      if (this.state.readiness(this.project.id).prep.total > 8) { Progress({ value: this.state.preparationPercent(this.project.id), total: 100, type: ProgressType.Linear }).width('100%').color(Theme.brand).backgroundColor(Theme.tint) }
      Text('在途 ' + this.state.readiness(this.project.id).prep.waiting + ' 项 · 装备可用 ' + this.state.readiness(this.project.id).equipment.available + ' / ' + this.state.readiness(this.project.id).equipment.total + ' 件').fontSize(14).fontColor(Theme.muted)
      Button(this.route.showCompleted ? '收起已完成' : '显示已完成').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.showCompleted = !this.route.showCompleted; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder preparationList() {
    SectionHeading({ title: '分类准备任务' })
    if (this.categories().length === 0) { EmptyState({
        title: '这次要准备哪些事？',
        message: '可选常用模板、复用装备模板，或自己添加分类。原有打包记录会保留。',
        button: '＋ 添加准备任务',
        action: (): void => { this.route.sheetKind = 0; this.route.preparing = true; }
      }) }
    ForEach(this.categories(), (category: PreparationCategory) => {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Button() {
            Column({ space: 3 }) { Text(category.name)
              .fontColor(Theme.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }); Text(this.categorySummary(category.id) + ' · ' + (this.route.expandedCategories.includes(category.id) ? '收起' : '展开'))
              .fontSize(11)
              .fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start)
              .width('100%')
          }.type(ButtonType.Normal)
            .backgroundColor(Theme.transparent)
            .layoutWeight(1)
            .onClick((): void => this.expandCategory(category.id))
            .accessibilityText((this.route.expandedCategories.includes(category.id) ? '收起分类 ' : '展开分类 ') + category.name)
            .visualEffect(this.feedback.effect('button-11' + ":" + category.id))
            .compositingFilter(this.feedback.filter('button-11' + ":" + category.id))
            .attributeModifier(this.feedback.control('button-11' + ":" + category.id))
          Button('编辑')
            .backgroundColor(Theme.bg)
            .fontColor(Theme.muted)
            .fontSize(12)
            .onClick((): void => { vibration.dotVibration(); this.edit('category', category.id, this.project.id); })
            .accessibilityText('编辑分类 ' + category.name)
            .visualEffect(this.feedback.effect('button-12' + ":" + category.id))
            .compositingFilter(this.feedback.filter('button-12' + ":" + category.id))
            .attributeModifier(this.feedback.control('button-12' + ":" + category.id))
          Button('＋')
            .backgroundColor(Theme.tint)
            .fontColor(Theme.accent)
            .onClick((): void => { vibration.dotVibration(); this.edit('preparation', '', category.id); })
            .accessibilityText('添加 ' + category.name + ' 任务')
            .visualEffect(this.feedback.effect('button-13' + ":" + category.id))
            .compositingFilter(this.feedback.filter('button-13' + ":" + category.id))
            .attributeModifier(this.feedback.control('button-13' + ":" + category.id))
          Button('−')
            .backgroundColor(Theme.bg)
            .fontColor(Theme.muted)
            .enabled(!this.state.busy)
            .onClick((): void => { vibration.dotVibration(); this.remove('category', category.id); })
            .accessibilityText('删除分类 ' + category.name)
            .visualEffect(this.feedback.effect('button-14' + ":" + category.id))
            .compositingFilter(this.feedback.filter('button-14' + ":" + category.id))
            .attributeModifier(this.feedback.control('button-14' + ":" + category.id))
        }.width('100%')
        ForEach(this.visibleTasks(category.id), (task: PreparationTask) => {
          Row({ space: 8 }) {
            Button(task.done ? '✓' : '○')
              .constraintSize({ minWidth: 48, minHeight: 48 })
              .backgroundColor(task.done ? Theme.tint : Theme.bg)
              .fontColor(Theme.accent)
              .enabled(!this.state.busy)
              .onClick((): void => { vibration.dotVibration(); this.state.togglePreparation(task); })
                .accessibilityText(category.name + ' · ' + task.label + (task.done ? '，已完成，点击取消' : '，点击完成'))
                .visualEffect(this.feedback.effect('button-15' + ":" + category.id + ":" + task.id))
                .compositingFilter(this.feedback.filter('button-15' + ":" + category.id + ":" + task.id))
                .attributeModifier(this.feedback.control('button-15' + ":" + category.id + ":" + task.id))
            Column({ space: 4 }) {
              Text(task.label)
                .fontSize(15)
                .fontColor(task.done ? Theme.muted : Theme.ink)
                .decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
              if (!task.done && (task.waitingOn || task.waitingUntil)) { Text('在途 · ' + (task.waitingOn || '等待外部进展') + (task.waitingUntil ? ' · 等待至 ' + task.waitingUntil : '')).fontSize(13).fontColor(Theme.accent) }
              else if (task.dueDate) { Text((!task.done && task.dueDate < this.state.localDate ? '逾期 · 截止 ' : '截止 ') + task.dueDate).fontSize(13).fontColor(Theme.muted) }
              if (task.notes) { Text(task.notes).fontSize(12).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
            }.layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .onClick((): void => { vibration.dotVibration(); this.edit('preparation', task.id, this.project.id); })
              .accessibilityText('编辑任务 ' + task.label)
              .visualEffect(this.feedback.effect('column-16' + ":" + category.id + ":" + task.id))
              .compositingFilter(this.feedback.filter('column-16' + ":" + category.id + ":" + task.id))
              .attributeModifier(this.feedback.control('column-16' + ":" + category.id + ":" + task.id))
            Button('−')
              .backgroundColor(Theme.bg)
              .fontColor(Theme.muted)
              .enabled(!this.state.busy)
              .onClick((): void => { vibration.dotVibration(); this.remove('preparation', task.id); })
              .accessibilityText('删除准备任务 ' + task.label)
              .visualEffect(this.feedback.effect('button-17' + ":" + category.id + ":" + task.id))
              .compositingFilter(this.feedback.filter('button-17' + ":" + category.id + ":" + task.id))
              .attributeModifier(this.feedback.control('button-17' + ":" + category.id + ":" + task.id))
          }.id('preparation-row:' + task.id).width('100%').padding(8).border({ width: task.id === this.route.focusTaskId ? 1 : 0, color: Theme.accent }).borderRadius(12)
            .onAreaChange((_, area: Area): void => { this.focusItem(task.id, area); })
        }, (task: PreparationTask) => task.id)
        if (this.tasks(category.id).length === 0) { Text('点击 ＋ 添加第一项任务').fontSize(12).fontColor(Theme.muted) }
      }.padding(14)
        .width('100%')
        .backgroundColor(Theme.surface)
        .borderRadius(Theme.cardRadius)
        .alignItems(HorizontalAlign.Start)
        .visualEffect(this.feedback.effect('column-10' + ":" + category.id, true))
        .compositingFilter(this.feedback.filter('column-10' + ":" + category.id, true))
        .attributeModifier(this.feedback.control('column-10' + ":" + category.id, true))
    }, (category: PreparationCategory) => category.id)
  }

  @Builder equipmentList() {
    SectionHeading({ title: '本次装备', trailing: this.state.readiness(this.project.id).equipment.total + ' 件' })
    ForEach(this.equipment(), (asset: Asset) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(asset.name)
          .fontSize(16)
          .fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '存放位置待补充'))
          .fontSize(12)
          .fontColor(Theme.muted) }.layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick((): void => { vibration.dotVibration(); this.open('asset', asset.id); })
          .accessibilityText(asset.name + '，打开装备详情').visualEffect(this.feedback.effect('column-19' + ":" + asset.id)).compositingFilter(this.feedback.filter('column-19' + ":" + asset.id)).attributeModifier(this.feedback.control('column-19' + ":" + asset.id))
        Button('移除')
          .backgroundColor(Theme.bg)
          .fontColor(Theme.muted)
          .enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.unlink(asset); })
          .accessibilityText('解除 ' + asset.name + ' 的计划关联')
          .visualEffect(this.feedback.effect('button-20' + ":" + asset.id))
          .compositingFilter(this.feedback.filter('button-20' + ":" + asset.id))
          .attributeModifier(this.feedback.control('button-20' + ":" + asset.id))
      }.
    width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(18).visualEffect(this.feedback.effect('row-18' + ":" + asset.id, true)).compositingFilter(this.feedback.filter('row-18' + ":" + asset.id, true)).attributeModifier(this.feedback.control('row-18' + ":" + asset.id, true))
    }, (asset: Asset) => asset.id)
    if (this.state.projectAssets(this.project.id).length === 0) {
      Row({ space: 8 }) { Text('还没有关联装备，可以新建或从衣柜复用。')
        .fontSize(13)
        .fontColor(Theme.muted)
        .layoutWeight(1); Button('＋ 新装备')
        .accessibilityText('新装备')
        .backgroundColor(Theme.tint)
        .fontColor(Theme.accent)
        .onClick((): void => { vibration.dotVibration(); this.edit('asset', '', this.project.id); })
        .visualEffect(this.feedback.effect('button-21'))
        .compositingFilter(this.feedback.filter('button-21'))
        .attributeModifier(this.feedback.control('button-21')) }.width('100%')
    }
    if (this.project.notes) { SectionHeading({ title: '备注' }); Text(this.project.notes).fontSize(14).fontColor(Theme.muted) }

  }

  @Builder contextSheet() {
    Column({ space: 16 }) {
      SheetHeader({ title: this.route.contextSheet === 'team' ? '团队分工' : this.route.contextSheet === 'references' ? '准备参考图' : this.route.contextSheet === 'records' ? '计划记录' : '计划收录', haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, closeSize: 48, close: (): void => { this.route.contextSheet = ''; } })
      Scroll() {
        Column({ space: 14 }) {
          if (this.route.contextSheet === 'team') { this.team() }
          else if (this.route.contextSheet === 'records') {
            Text(this.project.name + ' · 自动记录的操作历程').fontSize(15).fontColor(Theme.muted)
            ForEach(this.state.projectDiary(this.project.id), (entry: DiaryEntry) => {
              Column({ space: 8 }) {
                Text(formatTimestamp(entry.createdAt)).fontSize(14).fontColor(Theme.accent)
                Text(entry.text).fontSize(17).fontColor(Theme.ink)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(Theme.tint).borderRadius(12)
            }, (entry: DiaryEntry) => entry.id)
            if (!this.state.projectDiary(this.project.id).length) { Text('这份计划还没有操作记录，后续记录会显示在这里。').fontSize(16).fontColor(Theme.muted) }
          }
          else if (this.route.contextSheet === 'references') {
            ReferenceGallery({ state: this.state, images: this.state.references.filter((image: ReferenceImage) => image.projectId === this.project.id), add: (): void => { this.state.importReferences(this.project.id); }, open: (id: string): void => { this.open('reference', id); } })
          } else { EntryCollection({ state: this.state, scopeKind: 'project', scopeId: this.project.id, open: (kind: string, id: string): void => { this.open(kind, id); } }) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%')
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }
  @Builder team() {
    Row({ space: 8 }) {
      SectionHeading({ title: '团队分工' }).layoutWeight(1)
      Button('＋ 添加成员')
        .accessibilityText('添加成员')
        .backgroundColor(Theme.tint)
        .fontColor(Theme.accent)
        .onClick((): void => { vibration.dotVibration(); this.edit('team', '', this.project.id); })
        .visualEffect(this.feedback.effect('button-22'))
        .compositingFilter(this.feedback.filter('button-22'))
        .attributeModifier(this.feedback.control('button-22'))
    }.width('100%')
    ForEach(this.state.team.filter((m: TeamMember) => m.projectId === this.project.id), (m: TeamMember) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(m.role + ' · ' + m.name)
          .fontSize(15)
          .fontColor(Theme.ink); if (m.notes) { Text(m.notes)
          .fontSize(12)
          .fontColor(Theme.muted) } }.layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick((): void => { vibration.dotVibration(); this.edit('team', m.id, this.project.id); })
          .accessibilityText('编辑团队成员 ' + m.name)
          .visualEffect(this.feedback.effect('column-24' + ":" + m.id))
          .compositingFilter(this.feedback.filter('column-24' + ":" + m.id))
          .attributeModifier(this.feedback.control('column-24' + ":" + m.id))
        Button('−')
          .backgroundColor(Theme.bg)
          .fontColor(Theme.muted)
          .enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.remove('team', m.id); })
          .accessibilityText('删除团队成员 ' + m.name)
          .visualEffect(this.feedback.effect('button-25' + ":" + m.id))
          .compositingFilter(this.feedback.filter('button-25' + ":" + m.id))
          .attributeModifier(this.feedback.control('button-25' + ":" + m.id))
      }.
    width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(16).visualEffect(this.feedback.effect('row-23' + ":" + m.id, true)).compositingFilter(this.feedback.filter('row-23' + ":" + m.id, true)).attributeModifier(this.feedback.control('row-23' + ":" + m.id, true))
    }, (m: TeamMember) => m.id)
    if (!this.state.team.some((m: TeamMember) => m.projectId === this.project.id)) { Text('记录毛娘、妆娘、摄影、后勤和后期的人选。').fontColor(Theme.muted).fontSize(13) }
  }
  @Builder overview() {
    Column({ space: 14 }) {
      if ([ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED].includes(this.project.status) && this.state.projectWork(this.project.id)) { WorkCard({ work: this.state.projectWork(this.project.id)!, hint: '双击查看本计划照片', open: (): void => { this.route.section = 3; } }) }
      if (![ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED].includes(this.project.status)) { Text(this.state.readiness(this.project.id).blockers[0] || this.state.readiness(this.project.id).prep.next?.label || '当前没有准备卡点').fontSize(19).fontWeight(FontWeight.Medium).fontColor(Theme.ink) }
      Button('角色 · ' + this.state.characterName(this.project.characterId) + (this.project.variantId ? ' / ' + (this.state.variants.find((variant) => variant.id === this.project.variantId)?.name || '版本已不存在') : '')).constraintSize({ minHeight: 48 }).onClick((): void => { this.open('character', this.project.characterId); })
      Row({ space: 8 }) {
        Button('改日期 / 关联活动').constraintSize({ minHeight: 48 }).onClick((): void => { this.edit('project', this.project.id, ''); })
        Button('记一笔').constraintSize({ minHeight: 48 }).onClick((): void => { this.edit('expense', '', this.project.id); })
      }.width('100%')
      Button('准备 ' + this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total + ' 项完成 · 在途 ' + this.state.readiness(this.project.id).prep.waiting + ' 项').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.section = 1; })
      Button('打包 ' + this.state.readiness(this.project.id).pack.packed + ' / ' + this.state.readiness(this.project.id).pack.total + ' 件确认').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.section = 2; })
      Text(this.state.readiness(this.project.id).equipment.total ? '装备可用 ' + this.state.readiness(this.project.id).equipment.available + ' / ' + this.state.readiness(this.project.id).equipment.total + ' 件' : '尚未关联装备').fontSize(15).fontColor(Theme.muted)
      ForEach(this.state.readiness(this.project.id).equipment.unavailable, (asset: Asset) => {
        Button(asset.name + ' · ' + ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)]).constraintSize({ minHeight: 48 }).onClick((): void => { this.open('asset', asset.id); })
      }, (asset: Asset) => asset.id)
      Button('花费 ¥' + (this.state.readiness(this.project.id).money.spentCents / 100).toFixed(2) + ' · ' + budgetLabel(this.project.budgetConfigured, this.project.budgetCents)).width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.open('expenseStats', this.project.id); })
      Button('团队 · ' + this.state.team.filter((member: TeamMember) => member.projectId === this.project.id).length + ' 人 · 编辑分工').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.contextSheet = 'team'; })
      Button('参考图 · ' + this.state.references.filter((image: ReferenceImage) => image.projectId === this.project.id).length + ' 张').width('100%').constraintSize({ minHeight: 48 }).onClick((): void => { this.route.contextSheet = 'references'; })
      this.entryLink()
      Button('计划记录 · ' + this.state.projectDiary(this.project.id).length + ' 条').id('project-records-open').width('100%').constraintSize({ minHeight: 48 })
        .onClick((): void => { this.route.contextSheet = 'records'; })
      if (this.project.notes) { Text(this.project.notes).fontSize(15).fontColor(Theme.muted) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder entryLink() {
    Button('收录 · ' + this.state.entries.filter((entry) => entry.scopeKind === 'project' && entry.scopeId === this.project.id).length + ' 条').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).constraintSize({ minHeight: 48 }).onClick((): void => { this.route.contextSheet = 'entries'; })
  }

  @Builder packing() {
    SectionHeading({
      title: '打包清单',
      trailing: `${this.state.readiness(this.project.id).pack.packed} / ${this.state.readiness(this.project.id).pack.total} 已装包`
    })
    if (this.route.outing) { Text('出门模式 · ' + (this.state.hand() === 'left' ? '左手操作' : this.state.hand() === 'right' ? '右手操作' : '智感握持'))
      .fontColor(Theme.accent)
      .fontSize(13) }
    Progress({ value: this.state.readiness(this.project.id).pack.percent, total: 100, type: ProgressType.Linear })
      .accessibilityText('打包清单完成 ' + this.state.readiness(this.project.id).pack.percent + '%')
      .color(Theme.brand)
      .backgroundColor(Theme.tint)
      .width('100%')
    if (this.items().length === 0) { EmptyState({
        title: '清单还空着',
        message: '添加装备会自动生成打包项，也可以添加手机、门票等随身物品。',
        button: '添加常用物品',
        action: (): void => { this.state.generateChecklist(this.project.id); }
      }) }
    ForEach(this.items(), (item: ChecklistItem) => {
      Row({ space: 12 }) {
        if (this.state.hand() === 'left') { this.checkButton(item) }
        Column({ space: 6 }) {
          Text(item.label)
            .fontSize(this.route.outing ? 20 : 16)
            .fontColor(item.done ? Theme.muted : Theme.ink)
            .decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          if (item.assetId) { Button(this.location(item) + ' · ' + this.packingAssetStatus(item))
            .constraintSize({ minHeight: this.route.outing ? 64 : 48 }).fontSize(14).fontColor(Theme.accent).onClick((): void => { this.open('asset', item.assetId); }).accessibilityText('查看 ' + item.label + ' 的装备位置与状态') }
          else { Text(this.location(item)).fontSize(14).fontColor(Theme.muted) }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (!this.route.outing) { Button('−')
          .backgroundColor(Theme.bg)
          .fontColor(Theme.muted)
          .enabled(!this.state.busy)
          .onClick((): void => { vibration.dotVibration(); this.remove('checklist', item.id); })
          .accessibilityText('删除清单项 ' + item.label)
          .visualEffect(this.feedback.effect('button-32' + ":" + item.id))
          .compositingFilter(this.feedback.filter('button-32' + ":" + item.id))
          .attributeModifier(this.feedback.control('button-32' + ":" + item.id)) }
        if (this.state.hand() !== 'left') { this.checkButton(item) }
      }.
    width('100%').id('packing-row:' + item.id).padding(14).backgroundColor(Theme.surface).borderRadius(20).border({ width: item.id === this.route.focusPackingId ? 1 : 0, color: Theme.accent }).onAreaChange((_, area: Area): void => { this.focusItem(item.id, area); }).visualEffect(this.feedback.effect('row-31' + ":" + item.id, true)).compositingFilter(this.feedback.filter('row-31' + ":" + item.id, true)).attributeModifier(this.feedback.control('row-31' + ":" + item.id, true))
    }, (item: ChecklistItem) => item.id)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(this.topInset).width('100%')
        Column({ space: 10 }) {
          this.header()
          if (this.focusFeedback) { Text(this.focusFeedback).fontSize(14).fontColor(Theme.muted) }
          if (this.state.error) { Text(this.state.error).fontSize(14).fontColor(Theme.danger) }
          if (this.route.section === 1) { this.preparation() }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.entrance.step >= 1 ? 1 : 0).translate({ y: this.entrance.step >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          if (this.route.section === 0) { this.overview() } else if (this.route.section === 2) { this.packing() } else { this.preparationList(); this.equipmentList() }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.
    constraintSize({ maxWidth: Theme.contentMaxWidth }).alignItems(HorizontalAlign.Start).padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%')
    }.id(this.route.section === 2 ? 'project-packing' : this.route.section === 0 ? 'project-overview' : 'project-preparation')
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onAreaChange((_, area: Area): void => {
        this.viewportTop = Number(area.globalPosition.y);
        if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); this.focusAfterMeasure(); }
      })
      .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.displayedSection] = this.scroller.currentOffset().yOffset; } })
      .align(Alignment.Top)
      .transition(pageTransition())
      .bindSheet(this.route.preparing || this.route.linking || Boolean(this.route.contextSheet), this.activeSheet(), appSheetOptions((): void => { this.route.preparing = false; this.route.linking = false; this.route.contextSheet = ''; }, this.sheetEntrance, this.getUIContext()))
      .onDisAppear((): void => { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); this.state.suspend(); })
  }
}
