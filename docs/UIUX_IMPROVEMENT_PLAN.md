# UI/UX 改进计划 (uifix 分支)

> 基于 `uifix` 分支的当前状态,制定的 UI/UX 改进计划  
> 更新时间: 2026-11-20

---

## 当前状态评估

### ✅ 已完成

#### 1. 工程结构重构
- ✅ 目录结构已按 Dashboard 重组(`abilities/`, `components/`, `config/`, `domain/`, `models/`, `pages/`, `services/`, `state/`, `ui/`, `utils/`)
- ✅ 状态管理统一(`AppState`, `AppStorageV2`)
- ✅ 路由系统改造(5 个独立 NavPathStack + 统一 detailStack)
- ✅ 页面分层清晰(main、detail、settings、about)

#### 2. 响应式布局基础
- ✅ 定义了断点(`600vp` 中屏, `840vp` 大屏)
- ✅ 提供了响应式工具函数(`cardColumnCount`, `photoColumnCount`)
- ✅ 主要页面已应用响应式布局(CosPage、EventsPage、HomePage、AlbumPage、LibraryPage)

#### 3. 图表组件
- ✅ **饼图** `DistributionChart`:Canvas 绘制,支持选中反馈、入场动画、资源色、深浅色适配
- ✅ **折线图** `InteractiveLineChart`:Canvas 绘制,支持触摸交互、缩放、拖拽、深浅色适配
- ✅ **柱状图** `BarChart`:Canvas 绘制,支持悬停高亮、入场动画、深浅色适配(本次新增)

#### 4. 无障碍
- ✅ 所有主要页面已补充 `accessibilityText`、`accessibilityGroup`、`accessibilityRole`
- ✅ 所有交互组件(按钮、图片、卡片)已添加无障碍标签

#### 5. 颜色与主题
- ✅ 所有颜色统一通过 `color.json` 管理
- ✅ 主题验证脚本通过(`test_theme_colors.py`)
- ✅ 无硬编码颜色(图表降级色除外)
- ✅ 支持 5 组配色方案(蓝、青、橙、绿、紫)

#### 6. 动画与交互
- ✅ 入场动画系统(`MainEntranceSession`, `startStaggerEnterAnimation`)
- ✅ 页面转场动画(NavPathStack 默认转场)
- ✅ 触摸反馈(`PressFeedback`, 震动反馈)
- ✅ 图表入场动画(饼图、柱状图)

#### 7. 组件库
- ✅ `EmptyState`:空状态占位,支持标题、消息、按钮
- ✅ `StatusPill`:状态标签,支持多种状态样式
- ✅ `InteractiveCard`:交互卡片,支持触摸反馈
- ✅ `ContextRow`:上下文行,支持图标、标题、操作
- ✅ `ManagedImage`:图片管理,支持加载状态、错误处理
- ✅ `DashboardSearch`:搜索组件,支持实时搜索
- ✅ `ProjectCard`、`EventCard`、`CharacterCard`:业务卡片组件

---

## 待改进项 (按优先级排序)

### P2: 重要但非紧急

#### 2.1 图表组件扩展 ⏳
**当前状态**: 已有饼图、折线图、柱状图  
**待完成**:
- [ ] 为 HomePage 的 `Statistics` 集成 `BarChart`(替换现有的简单柱状图)
- [ ] 为 `DistributionChart` 添加数据标签(百分比/数值)
- [ ] 为 `InteractiveLineChart` 添加数据标签(Y 轴数值)

**代码位置**:
- `entry/src/main/ets/pages/main/HomePage.ets` - 集成 BarChart
- `entry/src/main/ets/components/charts/DistributionChart.ets` - 添加数据标签
- `entry/src/main/ets/components/charts/InteractiveLineChart.ets` - 添加数据标签

**实施建议**:
```typescript
// HomePage.ets - 替换为 BarChart
import { BarChart, BarChartItem } from '../../components/charts/BarChart';

// 准备数据
const barData: BarChartItem[] = this.state.statistics.monthlySpendingTrend.map((value: number, index: number) => ({
    label: `${index + 1}月`,
    value: value,
    color: Theme.brand
}));

// 使用组件
BarChart({
    title: '月度花费趋势',
    items: barData,
    height: 200
})
```

#### 2.2 响应式布局细化 ⏳
**当前状态**: 已定义断点,主要页面已应用  
**待完成**:
- [ ] 详情页(CosDetailPage、EventDetailPage、AlbumDetailPage)响应式布局
- [ ] 大屏分栏布局(中屏以上,左侧列表 + 右侧详情)
- [ ] 表单页面响应式(大屏居中,最大宽度 `600vp`)

**代码位置**:
- `entry/src/main/ets/pages/detail/*.ets` - 详情页
- `entry/src/main/ets/pages/Main.ets` - 分栏布局

**实施建议**:
```typescript
// 详情页响应式
@Local viewportWidth: number = 0;

build() {
    Scroll() {
        Column() {
            // 内容
        }
        .padding({
            left: this.viewportWidth >= 840 ? 40 : 16,
            right: this.viewportWidth >= 840 ? 40 : 16
        })
    }
    .onAreaChange((oldArea: Area, newArea: Area): void => {
        this.viewportWidth = Number(newArea.width);
    })
}
```

#### 2.3 性能优化 🔧
**当前问题**: 长列表可能存在卡顿  
**优化方向**:
- [ ] 为长列表页面启用 `cachedCount`(CosPage、EventsPage、LibraryPage)
- [ ] 为图片列表启用懒加载(AlbumPage)
- [ ] 优化 `aboutToAppear` 生命周期(减少首帧阻塞)

**代码位置**:
- `entry/src/main/ets/pages/main/CosPage.ets`
- `entry/src/main/ets/pages/main/EventsPage.ets`
- `entry/src/main/ets/pages/main/LibraryPage.ets`
- `entry/src/main/ets/pages/main/AlbumPage.ets`

**实施建议**:
```typescript
// 长列表优化
LazyForEach(this.source, (item: T) => {
    // ...
}, (item: T) => item.id)
    .cachedCount(5) // 缓存 5 个屏外项
```

```typescript
// 图片懒加载
Image(this.src)
    .objectFit(ImageFit.Cover)
    .alt($r('app.media.placeholder')) // 占位图
    .onComplete(() => { /* 加载完成 */ })
    .onError(() => { /* 加载失败 */ })
```

#### 2.4 表单与输入优化 📝
**当前状态**: 表单组件分散,样式不统一  
**待完成**:
- [ ] 统一表单样式(边框、间距、标签、提示)
- [ ] 统一错误提示样式
- [ ] 为日期选择器添加快捷选项(今天、明天、本周末)

**代码位置**:
- `entry/src/main/ets/components/forms/*.ets`
- `entry/src/main/ets/pages/detail/*Page.ets`

**实施建议**:
```typescript
// 统一表单项样式
@ComponentV2
export struct FormField {
    @Param label: string = '';
    @Param required: boolean = false;
    @Param error: string = '';
    @BuilderParam content: () => void;

    build() {
        Column({ space: 4 }) {
            Row() {
                Text(this.label).fontSize(13).fontColor(Theme.muted)
                if (this.required) {
                    Text('*').fontSize(13).fontColor(Theme.critical)
                }
            }
            this.content()
            if (this.error) {
                Text(this.error).fontSize(12).fontColor(Theme.critical)
            }
        }
    }
}
```

#### 2.5 空状态与错误处理完善 🎯
**当前状态**: 已有 `EmptyState` 组件  
**待完成**:
- [ ] 为所有列表页面添加空状态(CosPage、EventsPage、LibraryPage、AlbumPage)
- [ ] 为搜索无结果添加空状态
- [ ] 为网络错误、加载失败添加错误提示

**代码位置**:
- `entry/src/main/ets/pages/main/*.ets`
- `entry/src/main/ets/components/common/Surfaces.ets`

**实施建议**:
```typescript
// 列表空状态
if (this.filteredProjects.length === 0) {
    EmptyState({
        title: '暂无计划',
        message: '点击右下角 + 按钮创建你的第一个 Cos 计划',
        button: '创建计划',
        action: (): void => { this.add('project', ''); }
    })
} else {
    // 列表内容
}
```

### P3: 可选优化

#### 3.1 微交互增强 ✨
- [ ] 为卡片添加长按菜单(快捷操作:编辑、删除、分享)
- [ ] 为列表项添加滑动删除
- [ ] 为搜索添加搜索历史
- [ ] 为日期选择器添加农历显示

#### 3.2 高级图表功能 📊
- [ ] 为折线图添加多系列支持(对比多个月份)
- [ ] 为饼图添加环形模式(Donut Chart)
- [ ] 为柱状图添加堆叠模式(Stacked Bar Chart)
- [ ] 为柱状图添加分组模式(Grouped Bar Chart)

#### 3.3 设置页面完善 ⚙️
- [ ] 为设置页面添加搜索
- [ ] 为设置页面添加分组折叠
- [ ] 为设置页面添加重置到默认值
- [ ] 为设置页面添加导入/导出配置

---

## 实施路线图

### 阶段 1: 图表与数据可视化完善 (1-2 天)
- [x] 创建 `BarChart` 组件
- [ ] 为 HomePage 集成 `BarChart`
- [ ] 为图表添加数据标签
- [ ] 编译验证

### 阶段 2: 响应式布局细化 (1-2 天)
- [ ] 详情页响应式布局
- [ ] 大屏分栏布局(可选)
- [ ] 表单页面响应式
- [ ] 编译验证

### 阶段 3: 性能与体验优化 (1-2 天)
- [ ] 长列表性能优化
- [ ] 图片懒加载
- [ ] 表单样式统一
- [ ] 空状态与错误处理完善
- [ ] 编译验证

### 阶段 4: 微交互与高级功能 (可选,1-2 天)
- [ ] 长按菜单
- [ ] 滑动删除
- [ ] 搜索历史
- [ ] 高级图表功能
- [ ] 设置页面完善
- [ ] 编译验证

---

## 验证清单

### 编译验证
```bash
./scripts/build.sh
```

### 主题验证
```bash
python3 scripts/test_theme_colors.py
```

### 功能验证(开发期,只验证核心流程)
- [ ] 五个主页面正常显示
- [ ] 详情页正常打开和返回
- [ ] 设置页面正常显示和保存
- [ ] 图表正常显示和交互
- [ ] 深浅色主题切换正常

### 设备验证(发布前)
- [ ] `./scripts/device-test.sh` - 核心功能
- [ ] `./scripts/ui-test.sh` - UI 交互
- [ ] `./scripts/layout-test.sh` - 响应式布局
- [ ] `./scripts/theme-test.sh` - 主题切换

---

## 注意事项

1. **验证边界**: 开发期只运行编译验证(`./scripts/build.sh`),不跑设备测试
2. **代码风格**: 保持紧凑、清晰、易读,括号配对、链式调用和换行以可读性为原则
3. **组件封装**: 只有真正需要复用或显著降低复杂度时才封装组件
4. **响应式布局**: 严格参考华为官方最佳实践,不要凭其他平台经验猜测
5. **API 兼容性**: 目标 API 26,最低兼容 API 23,参考华为开发者联盟官方文档
6. **无障碍**: 所有新增组件必须补充无障碍标签
7. **颜色管理**: 所有颜色必须通过 `color.json` 管理,禁止硬编码
8. **生命周期**: 检查 `aboutToAppear` 中的任务,非首帧必须逻辑移至更合适的生命周期

---

## 参考资源

### Dashboard 参考
- `entry/src/main/ets/pages/Dashboard.ets` - 路由结构
- `entry/src/main/ets/pages/main/HomePage.ets` - 主页面示例
- `entry/src/main/ets/state/appState.ets` - 状态管理
- `entry/src/main/ets/ui/animation/motion.ets` - 动画工具

### 华为官方文档
- [HdsNavigation](https://developer.huawei.com/consumer/cn/doc/design-guides/navigation)
- [HdsTabs](https://developer.huawei.com/consumer/cn/doc/design-guides/tabs)
- [响应式布局最佳实践](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-responsive-layout)
- [无障碍设计指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-universal-attributes-accessibility)
- [ArkUI 动画](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation)

### 项目文档
- `docs/UX_RESTRUCTURE_PLAN.md` - v2 体验重构方案(尚未实施)
- `docs/RELEASE.md` - 打包与签名边界
- `docs/VALIDATION.md` - 历史验证记录
- `AGENTS.md` - 工程参考与开发规范

---

**最后更新**: 2026-11-20  
**当前分支**: `uifix`  
**当前版本**: 1.0.0-beta.1 (10000001)
