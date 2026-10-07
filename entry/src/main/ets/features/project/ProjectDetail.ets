import { TeamMember, Expense, ReferenceImage, expenseTotal } from '../../model/Planning';
import { ReferenceGallery } from '../../components/ReferenceGallery';
import { PreparationCategory, PreparationTask, preparationKeys, preparationProgress } from '../../model/Preparation';
import { PreparationTemplatePicker } from '../../components/PreparationTemplatePicker';
import { pageTransition, startStaggerEnterAnimation, cancelStaggerEnterAnimation } from '../../common/motion';
import { appSheetOptions } from '../../common/sheet';
import { SheetHeader } from '../../components/SheetHeader';
import { confirm } from '../../common/Confirm';
import { AppState } from '../../common/AppState';
import { Theme } from '../../common/Theme';
import { vibration } from '../../common/vibration';
import { Asset, AssetStatus, ChecklistItem, CosProject, CosEvent, PROJECT_LABELS, PROJECT_STATUSES, ASSET_STATUSES, ASSET_STATUS_LABELS } from '../../model/Entities';
import { ProjectRoute } from '../../model/ProjectRoute';
import { SectionHeading, StatusPill, EmptyState } from '../../components/Surfaces';
import { checklistProgress, projectProgress, planDate } from '../../model/Rules';
import { HapticService } from '../../services/haptic/HapticService';

@ComponentV2
export struct ProjectDetail {
  @Param state: AppState = new AppState();
  @Param project: CosProject = new CosProject();
  @Param route: ProjectRoute = new ProjectRoute('');
  @Param topInset: number = Theme.detailTop;
  @Event open: (kind: string, id: string) => void = () => {};
  @Event edit: (kind: string, id: string, parent: string) => void = () => {};
  @Event remove: (kind: string, id: string) => void = () => {};
  @Local expandedCategories: string[] = [];
  @Local templateKeys: string[] = preparationKeys(1);
  @Local templateMode: number = 1;
  @Local animStep: number = 0;
  private enterTimers: number[] = [];
  // 二级页面：每次进入都重新播放入场动画。
  aboutToAppear(): void { this.enterTimers = startStaggerEnterAnimation(this.getUIContext(), 2, (step: number): void => { this.animStep = step; }); }
  aboutToDisappear(): void { cancelStaggerEnterAnimation(this.enterTimers); this.enterTimers = []; this.animStep = 0; }

  private items(): ChecklistItem[] { return this.state.checklist.filter((c: ChecklistItem) => c.projectId === this.project.id).sort((a: ChecklistItem, b: ChecklistItem) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id)); }
  private equipment(): Asset[] { return this.state.projectAssets(this.project.id).sort((a: Asset, b: Asset) => Number(a.status === AssetStatus.OWNED) - Number(b.status === AssetStatus.OWNED) || a.name.localeCompare(b.name)); }
  private linked(asset: Asset): boolean { return this.state.projectAssets(this.project.id).some((a: Asset) => a.id === asset.id); }
  private location(item: ChecklistItem): string { return this.state.assets.find((a: Asset) => a.id === item.assetId)?.location || (item.assetId ? '存放位置待补充' : '随身物品'); }
  private async unlink(asset: Asset): Promise<void> {
    if (await confirm(this.getUIContext(), '解除装备关联？', '本计划中对应的打包项也会移除，衣柜中的装备会保留。', '解除关联')) { await this.state.unlinkAsset(this.project.id, asset.id); }
  }

  @Builder linkSheet() {
    Column({ space: 14 }) {
      SheetHeader({
        title: '从衣柜添加', hint: '已有装备可以在多份计划里复用',
        haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
        close: (): void => { this.route.linking = false; },
      })
      List({ space: 8 }) {
        ForEach(this.state.assets, (asset: Asset) => {
          ListItem() {
            Button() {
              Row() {
                Column({ space: 5 }) { Text(asset.name).fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '位置待补充')).fontSize(12).fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(this.linked(asset) ? '已添加' : '＋ 添加').fontColor(Theme.accent)
              }.padding(16).width('100%')
            }.width('100%').backgroundColor(Theme.bg).enabled(!this.state.busy && !this.linked(asset)).onClick((): void => { vibration.dotVibration(); this.state.linkAsset(this.project.id, asset); }).accessibilityText('关联 ' + asset.name)
          }
        }, (asset: Asset) => asset.id)
      }.layoutWeight(1).width('100%')
      if (this.state.assets.length === 0) { Text('衣柜还是空的，先添加一件装备。').fontSize(13).fontColor(Theme.muted) }
      Button('＋ 新装备').width('100%').backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.route.linking = false; this.edit('asset', '', this.project.id); })
      Button('完成').width('100%').backgroundColor(Theme.accent).fontColor(Theme.onAccent).onClick((): void => { vibration.dotVibration(); this.route.linking = false; })
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder checkButton(item: ChecklistItem) {
    Button(item.done ? '✓ 已装包' : '装包').constraintSize({ minWidth: 88, minHeight: this.route.outing ? 64 : 48 }).backgroundColor(item.done ? Theme.tint : Theme.accent).fontColor(item.done ? Theme.accent : Theme.onAccent).enabled(!this.state.busy)
      .onClick((): void => { vibration.dotVibration(); this.state.toggleChecklist(item); }).accessibilityText(item.label + (item.done ? '，已装包，点击取消' : '，点击确认装包'))
  }

  @Builder activeSheet() {
    if (this.route.sheetKind === 0) { this.preparationSheet() } else { this.linkSheet() }
  }

  /** 计划头：名称 + 状态 + 日期，替代原先的 26vp 大标题。 */
  @Builder header() {
    Row({ space: 10 }) {
      Text(this.project.name).fontSize(19).fontWeight(FontWeight.Medium).fontColor(Theme.ink).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      StatusPill({ label: PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)] })
    }.width('100%').alignItems(VerticalAlign.Center)
    if (planDate(this.project, this.state.events)) { Text('计划日期 · ' + planDate(this.project, this.state.events)).fontSize(13).fontColor(Theme.muted) }
    if (this.project.eventId) {
      Button('活动 · ' + (this.state.events.find((e: CosEvent) => e.id === this.project.eventId)?.name || '未关联')).backgroundColor(Theme.tint).fontColor(Theme.accent).fontSize(13).constraintSize({ minHeight: 36 })
        .onClick((): void => { vibration.dotVibration(); this.open('event', this.project.eventId); })
        .accessibilityText('打开关联活动')
    }
  }

  private categories(): PreparationCategory[] { return this.state.preparationCategories.filter((c: PreparationCategory) => c.projectId === this.project.id); }
  private tasks(categoryId: string): PreparationTask[] { return this.state.preparationTasks.filter((t: PreparationTask) => t.categoryId === categoryId).sort((a: PreparationTask, b: PreparationTask) => Number(a.done) - Number(b.done) || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id)); }

  private visibleTasks(categoryId: string): PreparationTask[] {
    const tasks = this.tasks(categoryId);
    return this.expandedCategories.includes(categoryId) ? tasks : tasks.filter((t: PreparationTask) => !t.done).slice(0, 1);
  }
  private expandCategory(id: string): void {
    vibration.dotVibration(); this.expandedCategories = this.expandedCategories.includes(id) ? this.expandedCategories.filter((key: string) => key !== id) : this.expandedCategories.concat(id);
  }
  @Builder preparationSheet() {
    Column({ space: 14 }) {
      SheetHeader({ title: '准备任务', hint: '准备完成与装包确认分别记录', haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, close: (): void => { this.route.preparing = false; } })
      Row({ space: 10 }) {
        Button('＋ 自定义分类').layoutWeight(1).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.route.preparing = false; this.edit('category', '', this.project.id); })
        Button('＋ 自定义任务').layoutWeight(1).backgroundColor(Theme.tint).fontColor(Theme.accent).enabled(!this.state.busy && this.categories().length > 0).onClick((): void => { vibration.dotVibration(); this.route.preparing = false; this.edit('preparation', '', this.project.id); })
      }.width('100%')
      Scroll() {
        PreparationTemplatePicker({ keys: this.templateKeys, mode: this.templateMode, change: (keys: string[], mode: number): void => { this.templateKeys = keys; this.templateMode = mode; } })
      }.layoutWeight(1).width('100%')
      Button(this.state.busy ? '添加中…' : '补入所选任务').width('100%').backgroundColor(Theme.accent).fontColor(Theme.onAccent).enabled(!this.state.busy && this.templateKeys.length > 0)
        .onClick(async (): Promise<void> => { vibration.dotVibration(); if (await this.state.addPreparationTemplate(this.project.id, this.templateKeys)) { this.route.preparing = false; } })
      Text('同名分类和任务不会重复添加，也不会重置已有完成状态。').fontSize(12).fontColor(Theme.muted)
    }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
  }

  @Builder preparation() {
    Column({ space: 12 }) {
      Row() { Text('准备进度').fontSize(15).fontColor(Theme.muted).layoutWeight(1); Text(preparationProgress(this.project.id, this.state.preparationTasks).total === 0 ? '待设置' : this.state.preparationPercent(this.project.id) + '%').fontSize(24).fontWeight(FontWeight.Medium).fontColor(Theme.accent) }.width('100%')
      Progress({ value: this.state.preparationPercent(this.project.id), total: 100, type: ProgressType.Linear }).width('100%').color(Theme.accent).backgroundColor(Theme.tint)
      Text(preparationProgress(this.project.id, this.state.preparationTasks).total === 0 ? '尚未添加准备任务，可以从模板开始。' : preparationProgress(this.project.id, this.state.preparationTasks).ready + ' / ' + preparationProgress(this.project.id, this.state.preparationTasks).total + ' 项准备完成').fontSize(12).fontColor(Theme.muted)
      Text('装备可用 ' + projectProgress(this.project.id, this.state.links, this.state.assets).ready + ' / ' + this.state.projectAssets(this.project.id).length + ' 件 · 装包请在「打包」确认').fontSize(12).fontColor(Theme.muted)
    }.alignItems(HorizontalAlign.Start).padding(18).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
  }

  @Builder preparationList() {
    SectionHeading({ title: '分类准备任务' })
    if (this.categories().length === 0) { EmptyState({ title: '这次要准备哪些事？', message: '可选常用模板、复用装备模板，或自己添加分类。原有打包记录会保留。', button: '＋ 添加准备任务', action: (): void => { this.route.sheetKind = 0; this.route.preparing = true; } }) }
    ForEach(this.categories(), (category: PreparationCategory) => {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Button() {
            Column({ space: 3 }) { Text(category.name).fontColor(Theme.ink).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(this.tasks(category.id).filter((t: PreparationTask) => t.done).length + '/' + this.tasks(category.id).length + ' 完成 · ' + (this.expandedCategories.includes(category.id) ? '收起' : '展开')).fontSize(11).fontColor(Theme.muted) }.alignItems(HorizontalAlign.Start).width('100%')
          }.type(ButtonType.Normal).backgroundColor(Color.Transparent).layoutWeight(1).onClick((): void => this.expandCategory(category.id)).accessibilityText((this.expandedCategories.includes(category.id) ? '收起分类 ' : '展开分类 ') + category.name)
          Button('编辑').backgroundColor(Theme.bg).fontColor(Theme.muted).fontSize(12).onClick((): void => { vibration.dotVibration(); this.edit('category', category.id, this.project.id); }).accessibilityText('编辑分类 ' + category.name)
          Button('＋').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.edit('preparation', '', category.id); }).accessibilityText('添加 ' + category.name + ' 任务')
          Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('category', category.id); }).accessibilityText('删除分类 ' + category.name)
        }.width('100%')
        ForEach(this.visibleTasks(category.id), (task: PreparationTask) => {
          Row({ space: 8 }) {
            Button(task.done ? '✓' : '○').constraintSize({ minWidth: 48, minHeight: 48 }).backgroundColor(task.done ? Theme.tint : Theme.bg).fontColor(Theme.accent).enabled(!this.state.busy)
              .onClick((): void => { vibration.dotVibration(); this.state.togglePreparation(task); }).accessibilityText(category.name + ' · ' + task.label + (task.done ? '，已完成，点击取消' : '，点击完成'))
            Column({ space: 4 }) {
              Text(task.label).fontSize(15).fontColor(task.done ? Theme.muted : Theme.ink).decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
              if (task.dueDate) { Text('截止 ' + task.dueDate).fontSize(12).fontColor(Theme.muted) }
              if (task.notes) { Text(task.notes).fontSize(12).fontColor(Theme.muted).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick((): void => { vibration.dotVibration(); this.edit('preparation', task.id, this.project.id); }).accessibilityText('编辑任务 ' + task.label)
            Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('preparation', task.id); }).accessibilityText('删除准备任务 ' + task.label)
          }.width('100%')
        }, (task: PreparationTask) => task.id)
        if (this.tasks(category.id).length === 0) { Text('点击 ＋ 添加第一项任务').fontSize(12).fontColor(Theme.muted) }
      }.padding(14).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius).alignItems(HorizontalAlign.Start)
    }, (category: PreparationCategory) => category.id)
  }

  @Builder equipmentList() {
    SectionHeading({ title: '本次装备', trailing: this.state.projectAssets(this.project.id).length + ' 件' })
    ForEach(this.equipment(), (asset: Asset) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(asset.name).fontSize(16).fontColor(Theme.ink); Text(ASSET_STATUS_LABELS[ASSET_STATUSES.indexOf(asset.status)] + ' · ' + (asset.location || '存放位置待补充')).fontSize(12).fontColor(Theme.muted) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          .onClick((): void => { vibration.dotVibration(); this.open('asset', asset.id); })
          .accessibilityText(asset.name + '，打开装备详情')
        Button('移除').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.unlink(asset); }).accessibilityText('解除 ' + asset.name + ' 的计划关联')
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(18)
    }, (asset: Asset) => asset.id)
    if (this.state.projectAssets(this.project.id).length === 0) {
      Row({ space: 8 }) { Text('还没有关联装备，可以新建或从衣柜复用。').fontSize(13).fontColor(Theme.muted).layoutWeight(1); Button('＋ 新装备').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.edit('asset', '', this.project.id); }) }.width('100%')
    }
    if (this.project.notes) { SectionHeading({ title: '备注' }); Text(this.project.notes).fontSize(14).fontColor(Theme.muted) }

  }

  @Builder planning() {
    ReferenceGallery({ state: this.state, images: this.state.references.filter((r: ReferenceImage) => r.projectId === this.project.id), add: (): void => { this.state.importReferences(this.project.id); }, open: (id: string): void => this.open('reference', id) })
    Row({ space: 8 }) {
      SectionHeading({ title: '团队分工' }).layoutWeight(1)
      Button('＋ 添加成员').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.edit('team', '', this.project.id); })
    }.width('100%')
    ForEach(this.state.team.filter((m: TeamMember) => m.projectId === this.project.id), (m: TeamMember) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(m.role + ' · ' + m.name).fontSize(15).fontColor(Theme.ink); if (m.notes) { Text(m.notes).fontSize(12).fontColor(Theme.muted) } }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick((): void => { vibration.dotVibration(); this.edit('team', m.id, this.project.id); }).accessibilityText('编辑团队成员 ' + m.name)
        Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('team', m.id); }).accessibilityText('删除团队成员 ' + m.name)
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(16)
    }, (m: TeamMember) => m.id)
    if (!this.state.team.some((m: TeamMember) => m.projectId === this.project.id)) { Text('记录毛娘、妆娘、摄影、后勤和后期的人选。').fontColor(Theme.muted).fontSize(13) }
    Row({ space: 8 }) {
      SectionHeading({ title: '实际花费' }).layoutWeight(1)
      Button('＋ 记一笔').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.edit('expense', '', this.project.id); })
    }.width('100%')
    Text('实际 ¥' + (expenseTotal(this.state.expenses, this.project.id) / 100).toFixed(2) + ' / 预计预算 ¥' + (this.project.budgetCents / 100).toFixed(2)).fontColor(Theme.accent).fontSize(16)
    ForEach(this.state.expenses.filter((e: Expense) => e.projectId === this.project.id), (e: Expense) => {
      Row({ space: 8 }) {
        Column({ space: 5 }) { Text(e.name + ' · ¥' + (e.amountCents / 100).toFixed(2)).fontColor(Theme.ink); Text(e.date + ' · ' + e.category).fontSize(12).fontColor(Theme.muted) }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick((): void => { vibration.dotVibration(); this.edit('expense', e.id, this.project.id); }).accessibilityText('编辑花费 ' + e.name)
        Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('expense', e.id); }).accessibilityText('删除花费 ' + e.name)
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(16)
    }, (e: Expense) => e.id)
    Button('查看全部花费统计').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.open('expenseStats', 'all'); })
  }

  @Builder packing() {
    SectionHeading({ title: '打包清单', trailing: `${this.items().filter((c: ChecklistItem) => c.done).length} / ${this.items().length} 已装包` })
    if (this.route.outing) { Text('出门模式 · ' + (this.state.hand() === 'left' ? '左手操作' : this.state.hand() === 'right' ? '右手操作' : '智感握持')).fontColor(Theme.accent).fontSize(13) }
    Progress({ value: checklistProgress(this.items()), total: 100, type: ProgressType.Linear }).color(Theme.accent).backgroundColor(Theme.tint).width('100%')
    if (this.items().length === 0) { EmptyState({ title: '清单还空着', message: '添加装备会自动生成打包项，也可以添加手机、门票等随身物品。', button: '添加常用物品', action: (): void => { this.state.generateChecklist(this.project.id); } }) }
    ForEach(this.items(), (item: ChecklistItem) => {
      Row({ space: 12 }) {
        if (this.state.hand() === 'left') { this.checkButton(item) }
        Column({ space: 6 }) {
          Text(item.label).fontSize(this.route.outing ? 20 : 16).fontColor(item.done ? Theme.muted : Theme.ink).decoration({ type: item.done ? TextDecorationType.LineThrough : TextDecorationType.None })
          Text(this.location(item)).fontSize(12).fontColor(Theme.muted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (!this.route.outing) { Button('−').backgroundColor(Theme.bg).fontColor(Theme.muted).enabled(!this.state.busy).onClick((): void => { vibration.dotVibration(); this.remove('checklist', item.id); }).accessibilityText('删除清单项 ' + item.label) }
        if (this.state.hand() !== 'left') { this.checkButton(item) }
      }.width('100%').padding(14).backgroundColor(Theme.surface).borderRadius(20)
    }, (item: ChecklistItem) => item.id)
  }

  build() {
    Scroll() {
      Column({ space: Theme.sectionSpacing }) {
        Blank().height(this.topInset).width('100%')
        Column({ space: 10 }) {
          this.header()
          if (this.route.section !== 1) { this.preparation() }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.animStep >= 1 ? 1 : 0).translate({ y: this.animStep >= 1 ? 0 : 20 })
        Column({ space: Theme.sectionSpacing }) {
          if (this.route.section === 1) { this.packing() } else { this.preparationList(); this.equipmentList(); this.planning() }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .opacity(this.animStep >= 2 ? 1 : 0).translate({ y: this.animStep >= 2 ? 0 : 20 })
        Blank().height(Theme.contentBottom).width('100%')
      }.alignItems(HorizontalAlign.Start).padding({ left: Theme.pagePadding, right: Theme.pagePadding }).width('100%')
    }.id(this.route.section === 1 ? 'project-packing' : 'project-preparation').width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
      .bindSheet(this.route.preparing || this.route.linking, this.activeSheet(), appSheetOptions((): void => { this.route.preparing = false; this.route.linking = false; }))
      .onDisAppear((): void => { HapticService.back(this.state.settings.haptic, this.state.settings.hapticLevel); this.state.suspend(); })
  }
}
