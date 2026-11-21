# UI/UX 改进计划 (uifix 分支)

## 现状评估

`uifix` 分支已经完成了大量重构工作:
- ✅ 目录结构已按 Dashboard 形式重组 (ui/、components/、state/、domain/ 等)
- ✅ 已有完善的饼图组件 `DistributionChart` (Canvas 绘制、入场动画、交互选择)
- ✅ 已有完善的折线图组件 `InteractiveLineChart` (平滑曲线、缩放平移、多系列)
- ✅ 响应式布局已有部分实现 (RESPONSIVE_BREAKPOINT_MEDIUM/LARGE)
- ✅ 主题管理已统一到 `Theme` 和 `color.json`
- ✅ 动画与反馈已有 `motion.ets`、`pressFeedback.ets`、`vibration.ets`
- ✅ 无障碍标签已有初步覆盖

## 待改进项 (按优先级排序)

### P0: 关键缺陷修复 (必须完成)

1. **✅ 已完成** - 图表组件基础能力
2. **✅ 已完成** - 响应式布局框架
3. **✅ 已完成** - 主题管理统一

### P1: 重要改进 (重点推进)

#### 1.1 响应式布局完善 (2-3 天)

**目标**: 确保所有页面在不同设备尺寸下都有良好的显示效果

**任务清单**:
- [ ] 补充缺失的响应式布局实现
  - [ ] `CosPage.ets` - 角色/资产列表
  - [ ] `EventsPage.ets` - 活动列表
  - [ ] `LibraryPage.ets` - 衣柜页
  - [ ] `AlbumPage.ets` - 相册页
  - [ ] 详情页 (PhotoDetailPage、AssetDetailPage 等)
  
- [ ] 统一响应式实现模式
  ```typescript
  // 在每个页面组件中:
  @Local private viewportWidth: number = 360;
  
  @Computed
  private get columns(): number {
    if (this.viewportWidth >= RESPONSIVE_BREAKPOINT_LARGE) return 3;
    if (this.viewportWidth >= RESPONSIVE_BREAKPOINT_MEDIUM) return 2;
    return 1;
  }
  
  // 在布局中:
  .onAreaChange((_old, newArea) => {
    this.viewportWidth = Number(newArea.width);
  })
  ```

- [ ] 补充图表响应式能力
  - [ ] `DistributionChart` 添加 `responsiveSize` 参数
  - [ ] 图例网格在小屏显示 2 列,中屏 3 列,大屏 4 列

**验证**: 编译通过 + 在不同尺寸下预览布局

#### 1.2 柱状图组件 (1-2 天)

**目标**: 添加柱状图组件,用于对比展示

**实现方案**:
```typescript
// entry/src/main/ets/components/charts/BarChart.ets

export interface BarChartItem {
  label: string;
  value: number;
  color?: Resource;
}

@ComponentV2
export struct BarChart {
  @Param title: string = '';
  @Param items: BarChartItem[] = [];
  @Param unit: string = '';
  @Param showGrid: boolean = true;
  @Param enableAnimation: boolean = true;
  // Canvas 绘制、入场动画、点击反馈
}
```

**应用场景**:
- 活动花费对比
- 月度统计对比
- 角色出镜次数对比

**验证**: 编译通过 + 在测试页显示正常

#### 1.3 无障碍补充 (1 天)

**目标**: 补充缺失的无障碍标签,确保核心功能可被屏幕朗读器访问

**任务清单**:
- [ ] 主要页面补充 `.accessibilityGroup(true)` 和整体描述
- [ ] 表单字段补充 `.accessibilityLabel()` 和 `.accessibilityHint()`
- [ ] 图片补充 `.accessibilityText()` 描述
- [ ] 按钮补充 `.accessibilityRole(AccessibilityRoleType.BUTTON)`
- [ ] 列表项补充 `.accessibilitySelected()` 状态

**重点页面**:
- CosPage - 角色/资产列表
- EventsPage - 活动列表
- 详情页 - 表单字段

**验证**: 编译通过 + 代码审查

### P2: 体验优化 (有条件推进)

#### 2.1 动画统一与增强 (1-2 天)

**目标**: 统一各页面的动画效果,提升视觉连贯性

**任务清单**:
- [ ] 页面入场动画
  ```typescript
  // 使用现有的 MainEntranceSession
  Column()
    .opacity(this.entranceSession.opacity())
    .translate({ y: this.entranceSession.offset() })
    .animation({ duration: 400, curve: Curve.FastOutSlowIn })
  ```

- [ ] 列表项入场动画
  ```typescript
  // 使用现有的 PressFeedback
  .visualEffect(this.feedback.effect(itemId))
  .compositingFilter(this.feedback.filter(itemId))
  ```

- [ ] 删除/完成动画
  ```typescript
  // 使用 scale + opacity 过渡
  .scale({ x: this.removing ? 0.9 : 1, y: this.removing ? 0.9 : 1 })
  .opacity(this.removing ? 0 : 1)
  .animation({ duration: 250, curve: Curve.EaseOut })
  ```

**重点页面**:
- 任务列表 (TasksPage)
- 活动列表 (EventsPage)
- 相册网格 (AlbumPage)

**验证**: 编译通过

#### 2.2 表单体验优化 (1 天)

**目标**: 改进表单输入体验

**任务清单**:
- [ ] 表单验证反馈
  - [ ] 错误提示使用 `Theme.error` 颜色
  - [ ] 错误边框使用 `.border({ width: 1, color: Theme.error })`
  - [ ] 成功状态使用 `Theme.success` 颜色

- [ ] 输入框统一样式
  ```typescript
  TextInput()
    .backgroundColor(Theme.tint)
    .borderRadius(Theme.inputRadius)
    .border({ width: 1, color: focused ? Theme.brand : Theme.line })
    .padding(12)
  ```

- [ ] 日期选择器统一使用 `DatePicker`
- [ ] 下拉选择统一使用 `Select`

**重点组件**:
- FormEditor
- DateField
- 详情页的各种输入

**验证**: 编译通过

#### 2.3 空状态优化 (0.5 天)

**目标**: 改进空状态的视觉表现

**任务清单**:
- [ ] 统一使用现有的 `EmptyState` 组件
- [ ] 补充空状态插图 (可选)
- [ ] 补充引导操作按钮

**示例**:
```typescript
EmptyState({
  icon: $r('sys.media.ohos_ic_public_add'),
  title: '暂无活动',
  message: '添加第一个活动开始记录',
  actionLabel: '添加活动',
  onAction: () => this.add('event', '')
})
```

**重点页面**:
- CosPage - 空角色/资产列表
- EventsPage - 空活动列表
- TasksPage - 空任务列表
- AlbumPage - 空相册

**验证**: 编译通过

#### 2.4 深浅色主题验证 (0.5 天)

**目标**: 确保五组配色在深浅色模式下都正确显示

**任务清单**:
- [ ] 运行 `python3 scripts/test_theme_colors.py` 验证颜色定义
- [ ] 代码审查:检查是否有硬编码颜色
- [ ] 检查图表颜色是否适配深浅色
- [ ] 检查按钮/卡片的对比度

**重点检查**:
- DistributionChart - 扇区颜色
- InteractiveLineChart - 线条颜色
- 主题色选择器 - ThemeColorPicker

**验证**: `python3 scripts/test_theme_colors.py` 通过

#### 2.5 性能优化 (1 天)

**目标**: 优化页面加载和滚动性能

**任务清单**:
- [ ] 图片懒加载
  ```typescript
  // 使用现有的 ManagedImage 组件
  ManagedImage({ path: photo.path, diskId: photo.diskId })
  ```

- [ ] 长列表虚拟滚动
  ```typescript
  List() {
    LazyForEach(this.dataSource, (item) => {
      ListItem() {
        // ...
      }
    })
  }
  .cachedCount(2) // 缓存屏幕外 2 个
  ```

- [ ] 图表按需绘制
  ```typescript
  // 在 InteractiveLineChart 和 DistributionChart 中:
  // 只在可见时绘制,onPageShow 触发重绘
  ```

- [ ] 生命周期优化
  - [ ] 移除 aboutToAppear 中的非必须初始化
  - [ ] Timer 在 aboutToDisappear 中清理
  - [ ] Observer 在 aboutToDisappear 中注销

**重点页面**:
- AlbumPage - 照片网格
- HomePage - 任务列表
- EventsPage - 活动列表

**验证**: 编译通过 + 代码审查

## 实施计划

### 第一阶段: P1 核心改进 (4-6 天)
1. 响应式布局完善 (2-3 天)
2. 柱状图组件 (1-2 天)
3. 无障碍补充 (1 天)

**里程碑**: 所有主要页面支持响应式,图表能力完整,无障碍基本覆盖

### 第二阶段: P2 体验优化 (4-5 天)
1. 动画统一与增强 (1-2 天)
2. 表单体验优化 (1 天)
3. 空状态优化 (0.5 天)
4. 深浅色主题验证 (0.5 天)
5. 性能优化 (1 天)

**里程碑**: 整体体验流畅,细节打磨到位

### 验证边界

**开发期验证 (每次改动)**:
```bash
./scripts/build.sh  # 编译通过即可
```

**可选验证 (只在必要时)**:
```bash
# 颜色相关改动
python3 scripts/test_theme_colors.py

# 数据库相关改动
python3 scripts/test_schema.py
```

**设备测试**: 不跑,除非用户明确要求

## 关键技术参考

### 响应式布局
- 参考华为官方文档: https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-responsive-layout
- 使用 `GridRow` + `GridCol` 实现响应式网格
- 使用 `@ohos.window` 获取窗口尺寸
- 断点: `RESPONSIVE_BREAKPOINT_MEDIUM = 600`, `RESPONSIVE_BREAKPOINT_LARGE = 840`

### 图表组件
- 使用 `Canvas` + `CanvasRenderingContext2D` 绘制
- 使用 `requestAnimationFrame` 或 `setTimeout` 实现动画
- 使用 `ChartConfigurationObserver` 监听主题变化
- 参考 Dashboard 的 `DistributionPanel` 和折线图实现

### 无障碍
- 参考华为官方文档: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-universal-attributes-accessibility
- 所有可交互组件添加 `.accessibilityRole()`
- 所有图片添加 `.accessibilityText()`
- 复杂组件添加 `.accessibilityGroup(true)`

### 动画
- 使用现有的 `MainEntranceSession` 实现页面入场
- 使用现有的 `PressFeedback` 实现按压反馈
- 使用 `.animation({ duration, curve })` 实现过渡
- 时长规范: 快速反馈 120ms,页面转场 400ms,数据动画 800ms

### 主题
- 所有颜色通过 `Theme.*` 或 `$r('app.color.*')` 引用
- 禁止硬编码颜色值
- 新增颜色必须在 `color.json` 中定义深浅色版本

## 风险与注意事项

1. **API 兼容性**: 严格使用 API 23-26 范围内的能力,不使用预览 API
2. **性能**: Canvas 绘制和长列表渲染注意性能,避免掉帧
3. **内存**: 及时释放 Timer、Observer、Controller 等资源
4. **主题**: 确保深浅色模式下都清晰可读
5. **无障碍**: 不要为了美观牺牲无障碍支持
6. **兼容性**: 保持现有数据结构兼容,不破坏已有数据

## 不做的事情

1. **不做结构重构**: `uifix` 分支已经完成了目录重组,不再调整
2. **不做路由改造**: 保持现有的导航方式
3. **不做数据迁移**: 除非必要,不改动数据库结构
4. **不做设备测试**: 开发期只编译验证
5. **不做过度封装**: 组件封装适度,不为了复用而复用

## 完成标准

**P1 完成标准**:
- [ ] 所有主要页面支持小屏/中屏/大屏三种布局
- [ ] 柱状图组件可用,至少应用在一个页面
- [ ] 核心交互组件和表单字段有无障碍标签
- [ ] 编译通过,无 ERROR

**P2 完成标准**:
- [ ] 页面入场和列表项有统一的动画效果
- [ ] 表单有统一的样式和错误反馈
- [ ] 空状态有统一的视觉表现
- [ ] 五组配色在深浅色模式下都正确
- [ ] 长列表滚动流畅,图片懒加载
- [ ] 编译通过,无 ERROR

**最终验证**:
```bash
./scripts/build.sh  # 编译通过
python3 scripts/test_theme_colors.py  # 颜色验证通过
```

## 后续迭代

完成 P1 和 P2 后,可以考虑:
- 添加更多图表类型 (雷达图、散点图等)
- 添加图表导出功能
- 添加图表配置面板
- 添加更丰富的动画效果
- 添加手势操作 (长按、滑动删除等)
- 添加快捷操作面板

但这些不在当前计划范围内,需要单独立项。
