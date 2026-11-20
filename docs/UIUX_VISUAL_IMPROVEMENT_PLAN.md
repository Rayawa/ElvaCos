# UI/UX 视觉体验改进方案

> 专注于视觉设计、交互体验、信息层级、空间节奏的改进  
> 当前分支: `uifix`  
> 更新时间: 2026-11-20

---

## 一、当前 UI/UX 问题诊断

### 1.1 视觉层级问题

#### 问题 1: 卡片内信息密度过高
**现状**:
- `ProjectCard` 在 88px 高的封面旁边堆叠了 4 行信息(标题、角色/版本、状态+日期+进度)
- 字号从 19px → 14px → 13px,层级不够明确
- `StatusPill` 的 12px 字号过小,视觉权重不足

**影响**:
- 用户难以快速扫描关键信息
- 卡片视觉焦点不清晰
- 小屏设备上更拥挤

#### 问题 2: 颜色对比度不足
**现状**:
- `Theme.muted` (次要文字) 在浅色模式下对比度可能不足 4.5:1
- `StatusPill` 的背景色 `Theme.tint` 与文字 `Theme.accent` 对比度较低
- 图表中的网格线 `Theme.groupDivider` 可能过于显眼

**影响**:
- 可读性下降,尤其在强光环境下
- 无障碍不达标(WCAG AA 要求 4.5:1)

#### 问题 3: 间距节奏不一致
**现状**:
- `HomePage` 的 `next()` 和 `taskRow()` 之间缺少明确的视觉分隔
- 卡片内部 `space: 12` 与卡片之间 `cardSpacing: 12` 相同,层级不清
- 详情页的 section 之间只有标题分隔,缺少视觉呼吸空间

**影响**:
- 页面显得拥挤
- 内容分组不够清晰
- 阅读疲劳

### 1.2 交互体验问题

#### 问题 4: 触摸目标尺寸不足
**现状**:
- `Select` 组件的 `minHeight: 36` 低于 HarmonyOS 推荐的 48vp
- `StatusPill` 的 padding 只有 `10px × 5px`,点击区域过小
- 部分 `Button` 的 `minHeight: 40` 也低于推荐值

**影响**:
- 误触率高,尤其在移动场景下
- 不符合 HarmonyOS 设计规范

#### 问题 5: 反馈不够及时
**现状**:
- `InteractiveCard` 的 scale 动画 130ms 偏慢
- 列表滚动时没有阻尼感(Dashboard 有 `EdgeEffect.Spring`)
- 加载状态缺少骨架屏或占位符

**影响**:
- 交互感觉迟钝
- 用户不确定操作是否生效
- 加载时出现闪烁

#### 问题 6: 空状态缺少引导
**现状**:
- `EmptyState` 组件样式过于简单,缺少插图或图标
- 空状态消息过于简短,没有告诉用户为什么是空的
- 部分列表(如搜索结果)没有空状态

**影响**:
- 用户不知道如何开始使用
- 搜索无结果时体验生硬

### 1.3 信息架构问题

#### 问题 7: 首页信息优先级不清
**现状**:
- `HomePage` 的 `next()` 区域包含了今天活动、接下来的计划、新建按钮,逻辑混杂
- `taskRow()` 的完成按钮是 `○`,不够直观
- "接下来" 标题与内容的关系不够明确

**影响**:
- 用户不知道该先关注什么
- 首页没有体现"今天要做什么"的核心价值

#### 问题 8: 详情页导航不够清晰
**现状**:
- `ProjectDetailPage` 的 section 切换依赖 `HdsTitleBarSegment`,但没有预览每个 section 的内容概览
- 准备事项、装箱清单、记录三个 section 平铺,没有层级关系
- 用户不知道当前在哪个 section

**影响**:
- 用户迷失在详情页中
- 切换 section 的成本高

### 1.4 视觉美感问题

#### 问题 9: 卡片设计过于单调
**现状**:
- 所有卡片都是白底(浅色) / 深灰底(深色) + 细边框
- 没有利用颜色、阴影、渐变来区分重要性
- 封面图和文字的组合缺少设计感

**影响**:
- 视觉上缺少层次感
- 重要内容不够突出
- 整体感觉平淡

#### 问题 10: 图表视觉表现力不足
**现状**:
- `DistributionChart` 的饼图缺少数据标签,用户需要对照图例才能看懂
- `InteractiveLineChart` 的折线过细(2px),视觉冲击力不足
- 图表颜色过于依赖 `Theme.brand`,缺少层次

**影响**:
- 数据可视化的价值打折扣
- 用户需要费力解读图表

---

## 二、改进方案

### 2.1 视觉层级改进

#### 改进 1: 优化卡片信息层级

**方案 A: 重构 ProjectCard 布局**
```typescript
// 目标: 突出标题,弱化次要信息,拉开层级

@Builder body() {
    Column({ space: 16 }) {  // 增加间距从 12 → 16
        Row({ space: 16 }) {
            // 封面保持 68×88
            if (this.character()?.cover) {
                ManagedImage({ ... })
                    .width(68).height(88).borderRadius(12)
            } else {
                // 无封面时的占位符增加视觉趣味
                Column() {
                    Text(this.state.characterName(this.project.characterId).slice(0, 1))
                        .fontSize(36)  // 从 30 → 36
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                }
                .width(68).height(88)
                .backgroundColor(Theme.tint)
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
            }
            
            Column({ space: 8 }) {  // 保持 8
                // 标题增大,增加呼吸空间
                Text(displayName(this.project.name))
                    .fontSize(20)  // 从 19 → 20
                    .fontWeight(FontWeight.Bold)  // Medium → Bold
                    .fontColor(Theme.ink)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .lineHeight(26)  // 增加行高
                
                // 角色/版本保持
                Text(displayName(this.state.characterName(this.project.characterId) + ...))
                    .fontSize(14)
                    .fontColor(Theme.muted)
                    .maxLines(1)
                
                // 状态行重新组织
                Row({ space: 10 }) {  // 从 8 → 10
                    // 状态标签增大
                    Text(PROJECT_LABELS[PROJECT_STATUSES.indexOf(this.project.status)])
                        .fontSize(13)  // 从 12 → 13
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })  // 增加 padding
                        .backgroundColor(Theme.tint)
                        .borderRadius(14)  // 从 12 → 14
                    
                    // 日期
                    Text(this.state.readiness(this.project.id).date || '日期待定')
                        .fontSize(14)
                        .fontColor(Theme.muted)
                    
                    // 进度放到新行或使用图标
                    if (this.state.readiness(this.project.id).prep.total) {
                        // 使用进度条而不是纯文字
                        Row({ space: 4 }) {
                            Text(this.state.readiness(this.project.id).prep.done + ' / ' + this.state.readiness(this.project.id).prep.total)
                                .fontSize(13)
                                .fontColor(Theme.muted)
                            // 可选: 添加进度条可视化
                            Progress({
                                value: this.state.readiness(this.project.id).prep.done,
                                total: this.state.readiness(this.project.id).prep.total,
                                type: ProgressType.Linear
                            })
                            .width(40)
                            .color(Theme.brand)
                            .backgroundColor(Theme.tint)
                        }
                    }
                }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        
        // hint 单独成行,增加呼吸空间
        if (this.state.readiness(this.project.id).hint) {
            ContextRow({ ... })
                .padding({ top: 4 })  // 增加顶部间距
        }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
}
```

**方案 B: 增加卡片变体(Hero Card)**
```typescript
// 为首页的"接下来"区域设计大卡片

@Builder planHeroV2(project: CosProject) {
    Column({ space: 0 }) {
        // 封面区域(如果有)
        if (this.character()?.cover) {
            ManagedImage({ ... })
                .width('100%')
                .height(160)  // 横向封面
                .borderRadius({ topLeft: Theme.cardRadius, topRight: Theme.cardRadius })
        }
        
        // 信息区域
        Column({ space: 12 }) {
            Row({ space: 12 }) {
                Column({ space: 6 }) {
                    Text(displayName(project.name))
                        .fontSize(24)  // 大标题
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink)
                    
                    Text(this.versionLabel(project))
                        .fontSize(15)
                        .fontColor(Theme.muted)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                
                // 日期大字显示
                Column({ space: 2 }) {
                    Text(this.planDateLabel(project))
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.accent)
                    
                    if (this.planDateContext(project)) {
                        Text(this.planDateContext(project))
                            .fontSize(12)
                            .fontColor(Theme.muted)
                    }
                }
            }
            .width('100%')
            
            // 准备进度可视化
            if (this.state.readiness(project.id).prep.total) {
                Column({ space: 6 }) {
                    Row() {
                        Text('准备进度')
                            .fontSize(13)
                            .fontColor(Theme.muted)
                            .layoutWeight(1)
                        
                        Text(this.state.readiness(project.id).prep.done + ' / ' + this.state.readiness(project.id).prep.total)
                            .fontSize(13)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Theme.ink)
                    }
                    .width('100%')
                    
                    Progress({
                        value: this.state.readiness(project.id).prep.done,
                        total: this.state.readiness(project.id).prep.total,
                        type: ProgressType.Linear
                    })
                    .width('100%')
                    .height(6)
                    .color(Theme.brand)
                    .backgroundColor(Theme.tint)
                    .borderRadius(3)
                }
            }
        }
        .width('100%')
        .padding(20)  // 更大的内边距
    }
    .width('100%')
    .backgroundColor(Theme.surface)
    .borderRadius(Theme.cardRadius)
    .border({ width: 0.5, color: Theme.line })
    .shadow({ radius: 8, color: Theme.shadow, offsetY: 2 })  // 增加阴影
}
```

#### 改进 2: 优化颜色对比度

**方案: 调整色阶,确保 WCAG AA 合规**
```typescript
// entry/src/main/resources/base/element/color.json
// 需要验证并调整以下颜色的对比度:

{
  "color": [
    // 次要文字: 浅色模式对比度应 ≥ 4.5:1
    {
      "name": "v3_text_secondary",
      "value": "#666666"  // 当前值,需要验证
      // 如果不足,调整为 #5A5A5A 或更深
    },
    
    // StatusPill 背景色: 应该更浅,让 accent 文字对比度更高
    {
      "name": "v3_surface_alt",
      "value": "#F0F0F0"  // 浅色模式建议值
    },
    
    // 图表网格线: 应该更淡
    {
      "name": "v3_chart_grid",
      "value": "#E8E8E8"  // 浅色模式建议值
    }
  ]
}

// 验证脚本 (scripts/test_contrast.py)
import re
from pathlib import Path
import json

def relative_luminance(hex_color: str) -> float:
    """计算相对亮度"""
    # 移除 # 号
    hex_color = hex_color.lstrip('#')
    
    # 转换为 RGB
    r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    
    # 归一化到 0-1
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    
    # 应用伽马校正
    r = r / 12.92 if r <= 0.03928 else ((r + 0.055) / 1.055) ** 2.4
    g = g / 12.92 if g <= 0.03928 else ((g + 0.055) / 1.055) ** 2.4
    b = b / 12.92 if b <= 0.03928 else ((b + 0.055) / 1.055) ** 2.4
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast_ratio(color1: str, color2: str) -> float:
    """计算对比度"""
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)
    
    lighter = max(l1, l2)
    darker = min(l1, l2)
    
    return (lighter + 0.05) / (darker + 0.05)

def main():
    # 读取颜色定义
    color_file = Path('entry/src/main/resources/base/element/color.json')
    with open(color_file, 'r', encoding='utf-8') as f:
        colors = json.load(f)['color']
    
    # 提取关键颜色对
    bg = next((c['value'] for c in colors if c['name'] == 'background'), '#FFFFFF')
    muted = next((c['value'] for c in colors if c['name'] == 'v3_text_secondary'), '#666666')
    
    # 验证对比度
    ratio = contrast_ratio(bg, muted)
    print(f'次要文字对比度: {ratio:.2f}:1 (要求 ≥ 4.5:1)')
    
    if ratio < 4.5:
        print('⚠️  对比度不足,建议调整颜色')
    else:
        print('✅ 对比度合格')

if __name__ == '__main__':
    main()
```

#### 改进 3: 优化间距节奏

**方案: 建立清晰的间距系统**
```typescript
// entry/src/main/ets/ui/theme/Theme.ets
// 在 ThemeTokens 中添加间距令牌

class ThemeTokens {
    // ... 现有代码
    
    // 间距系统 (基于 4px 网格)
    readonly space1: number = 4;   // 最小间距
    readonly space2: number = 8;   // 组内间距
    readonly space3: number = 12;  // 卡片内间距 (当前 cardSpacing)
    readonly space4: number = 16;  // 区块间距
    readonly space5: number = 24;  // section 间距
    readonly space6: number = 32;  // 大区块间距
    readonly space8: number = 48;  // 页面级间距
    
    // 语义化间距
    readonly inlineSpace: number = 8;        // 行内元素间距 (如 icon + text)
    readonly stackSpace: number = 12;        // 垂直堆叠间距
    readonly cardInnerSpace: number = 16;    // 卡片内部间距
    readonly cardOuterSpace: number = 12;    // 卡片之间间距
    readonly sectionGap: number = 24;        // section 之间间距
    readonly pageGap: number = 32;           // 页面大区块间距
}

// 应用到组件
@Builder body() {
    Column({ space: Theme.cardInnerSpace }) {  // 从硬编码 12 改为语义化
        Row({ space: Theme.inlineSpace }) {
            // ...
        }
        // ...
    }
}

// 应用到页面
build() {
    List({ space: Theme.cardOuterSpace }) {  // 卡片之间
        ListItemGroup({ space: Theme.sectionGap }) {  // section 之间
            // ...
        }
    }
}
```

### 2.2 交互体验改进

#### 改进 4: 统一触摸目标尺寸

**方案: 全局检查并调整为 48vp**
```typescript
// 1. Select 组件
Select([...])
    .constraintSize({ minHeight: 48 })  // 从 36 → 48
    .controlSize(ControlSize.SMALL)  // 保持小尺寸视觉,但增加点击区域

// 2. StatusPill 增加点击区域(如果可点击)
@ComponentV2
export struct StatusPill {
    @Param label: string = '';
    @Param clickable: boolean = false;
    @Event onClick: () => void = () => {};
    
    build() {
        Text(this.label)
            .fontSize(13)  // 从 12 → 13
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.accent)
            .padding({ 
                left: 12,   // 从 10 → 12
                right: 12, 
                top: this.clickable ? 8 : 6,  // 可点击时增加
                bottom: this.clickable ? 8 : 6 
            })
            .constraintSize(this.clickable ? { minHeight: 48, minWidth: 48 } : {})
            .backgroundColor(Theme.tint)
            .borderRadius(14)  // 从 12 → 14
            .onClick(this.clickable ? (): void => {
                vibration.dotVibration();
                this.onClick();
            } : undefined)
    }
}

// 3. Button 全局检查
// 搜索所有 minHeight < 48 的 Button
// 批量替换为 48
```

**验证脚本**:
```bash
#!/bin/bash
# scripts/check_touch_targets.sh

echo "检查触摸目标尺寸..."

# 查找 minHeight < 48 的组件
grep -rn "minHeight.*: [0-9]\{1,2\}[^0-9]" entry/src/main/ets/ --include="*.ets" | \
  grep -v "minHeight.*: 48\|minHeight.*: [5-9][0-9]" | \
  while read -r line; do
    echo "⚠️  $line"
  done

echo "完成"
```

#### 改进 5: 优化反馈及时性

**方案 A: 加快动画响应**
```typescript
// InteractiveCard.ets
.scale({ x: this.pressed ? 0.98 : 1, y: this.pressed ? 0.98 : 1 })  // 从 0.985 → 0.98 (更明显)
.animation({ 
    duration: 100,  // 从 130 → 100
    curve: curves.springMotion(0.4, 0.95)  // 从 (0.35, 0.9) 调整
})
```

**方案 B: 添加列表滚动阻尼**
```typescript
// CosPage.ets
build() {
    List({ space: Theme.cardSpacing, scroller: this.scroller }) {
        // ...
    }
    .edgeEffect(EdgeEffect.Spring)  // 添加这行
    .friction(0.6)  // 调整摩擦系数
}
```

**方案 C: 添加加载骨架屏**
```typescript
// 新建 entry/src/main/ets/components/common/SkeletonCard.ets
@ComponentV2
export struct SkeletonCard {
    @Local shimmer: boolean = false;
    
    aboutToAppear() {
        // 启动闪烁动画
        setInterval(() => {
            this.shimmer = !this.shimmer;
        }, 1000);
    }
    
    build() {
        Column({ space: 16 }) {
            Row({ space: 16 }) {
                // 封面占位
                Column()
                    .width(68)
                    .height(88)
                    .backgroundColor(Theme.tint)
                    .borderRadius(12)
                    .opacity(this.shimmer ? 0.5 : 1)
                    .animation({ duration: 800, curve: Curve.EaseInOut })
                
                Column({ space: 8 }) {
                    // 标题占位
                    Column()
                        .width('80%')
                        .height(20)
                        .backgroundColor(Theme.tint)
                        .borderRadius(4)
                        .opacity(this.shimmer ? 0.5 : 1)
                    
                    // 次要信息占位
                    Column()
                        .width('60%')
                        .height(14)
                        .backgroundColor(Theme.tint)
                        .borderRadius(4)
                        .opacity(this.shimmer ? 0.5 : 1)
                    
                    // 状态行占位
                    Row({ space: 8 }) {
                        Column()
                            .width(60)
                            .height(28)
                            .backgroundColor(Theme.tint)
                            .borderRadius(14)
                            .opacity(this.shimmer ? 0.5 : 1)
                        
                        Column()
                            .width(80)
                            .height(14)
                            .backgroundColor(Theme.tint)
                            .borderRadius(4)
                            .opacity(this.shimmer ? 0.5 : 1)
                    }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
            }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Theme.surface)
        .borderRadius(Theme.cardRadius)
        .border({ width: 0.5, color: Theme.line })
    }
}

// 在 CosPage 中使用
build() {
    List({ ... }) {
        if (this.state.busy && !this.visiblePlans.length) {
            // 显示骨架屏
            ListItem() { SkeletonCard() }
            ListItem() { SkeletonCard() }
            ListItem() { SkeletonCard() }
        } else {
            // 正常内容
            LazyForEach(...)
        }
    }
}
```

#### 改进 6: 优化空状态设计

**方案: 增强空状态的引导性**
```typescript
// 重构 EmptyState.ets
@ComponentV2
export struct EmptyState {
    @Param icon: Resource = $r('app.media.empty_box');  // 新增插图
    @Param title: string = '';
    @Param message: string = '';
    @Param button: string = '';
    @Param secondaryButton: string = '';  // 新增次要按钮
    @Event action: () => void = () => {};
    @Event secondaryAction: () => void = () => {};

    build() {
        Column({ space: 16 }) {  // 从 10 → 16
            // 插图
            Image(this.icon)
                .width(120)
                .height(120)
                .opacity(0.6)
                .margin({ bottom: 8 })
            
            // 标题
            Text(this.title)
                .fontSize(18)  // 从 16 → 18
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink)
                .textAlign(TextAlign.Center)
            
            // 消息
            Text(this.message)
                .fontSize(14)  // 从 13 → 14
                .fontColor(Theme.muted)
                .textAlign(TextAlign.Center)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            
            // 按钮组
            if (this.button) {
                Row({ space: 12 }) {
                    if (this.secondaryButton) {
                        Button(this.secondaryButton)
                            .type(ButtonType.Normal)
                            .backgroundColor(Color.Transparent)
                            .fontColor(Theme.accent)
                            .fontSize(15)
                            .constraintSize({ minHeight: 48, minWidth: 100 })
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.secondaryAction();
                            })
                    }
                    
                    Button(this.button)
                        .backgroundColor(Theme.brand)
                        .fontColor(Theme.onAccent)
                        .fontSize(15)  // 从 14 → 15
                        .constraintSize({ minHeight: 48, minWidth: 120 })  // 从 40 → 48
                        .onClick((): void => {
                            vibration.dotVibration();
                            this.action();
                        })
                }
            }
        }
        .width('100%')
        .padding(32)  // 从 20 → 32
        .backgroundColor(Theme.surface)
        .borderRadius(Theme.cardRadius)
        .border({ width: 0.5, color: Theme.line })
    }
}

// 准备空状态插图 (entry/src/main/resources/base/media/)
// empty_box.svg - 通用空状态
// empty_search.svg - 搜索无结果
// empty_calendar.svg - 无活动
// empty_photo.svg - 无照片
```

### 2.3 信息架构改进

#### 改进 7: 重构首页信息优先级

**方案: "今天要做什么"优先**
```typescript
// HomePage.ets
build() {
    Scroll({ scroller: this.scroller }) {
        Column({ space: Theme.sectionGap }) {  // 统一间距
            // 1. 今天模式入口 (如果有今天的活动)
            if (this.state.todayEvents.length && !this.dayEntryInSnack) {
                this.todayBanner()  // 新增,大卡片样式
            }
            
            // 2. 今天的任务 (最优先)
            if (this.rows.length > 0) {
                Column({ space: Theme.stackSpace }) {
                    SectionHeading({ title: '今天要做', trailing: this.rows.length + ' 项' })
                    ForEach(this.rows, (row: HomeTaskRow) => {
                        this.taskRowV2(row)  // 重新设计
                    })
                }
            }
            
            // 3. 接下来的计划
            if (this.upcoming) {
                Column({ space: Theme.stackSpace }) {
                    SectionHeading({ title: '接下来' })
                    this.planHeroV2(this.upcoming)  // 使用新的 hero 卡片
                }
            }
            
            // 4. 最近的工作记录
            if (this.recentWorkCard) {
                Column({ space: Theme.stackSpace }) {
                    SectionHeading({ title: '最近记录' })
                    WorkCard({ ... })
                }
            }
            
            // 5. 快捷操作 (始终可见)
            this.quickActions()  // 新增,网格布局
        }
        .width('100%')
        .padding({ 
            left: Theme.pagePadding, 
            right: Theme.pagePadding,
            top: this.topInset,
            bottom: this.bottomInset
        })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)  // 添加阻尼
}

// 新增今天横幅
@Builder todayBanner() {
    Column({ space: 0 }) {
        // 渐变背景
        Row() {
            Column({ space: 8 }) {
                Row({ space: 6 }) {
                    Text('📅')
                        .fontSize(20)
                    Text(dayTitle(this.state.todayEvents[0], this.state.clockTime))
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.onAccent)
                }
                
                Text(displayName(this.state.todayEvents[0].name))
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.onAccent)
                
                if (this.state.todayEvents.length > 1) {
                    Text('还有 ' + (this.state.todayEvents.length - 1) + ' 场活动')
                        .fontSize(14)
                        .fontColor(Theme.onAccent)
                        .opacity(0.9)
                }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            
            Text('›')
                .fontSize(32)
                .fontColor(Theme.onAccent)
                .opacity(0.8)
        }
        .width('100%')
        .padding(20)
    }
    .width('100%')
    .linearGradient({
        angle: 135,
        colors: [
            [Theme.brand, 0.0],
            [Theme.accent, 1.0]
        ]
    })
    .borderRadius(Theme.cardRadius)
    .shadow({ radius: 12, color: Theme.shadow, offsetY: 4 })
    .onClick((): void => {
        this.open('dayEvent', this.state.todayEvents[0]?.id || '');
    })
    .accessibilityText('进入今天模式')
}

// 重新设计任务行
@Builder taskRowV2(row: HomeTaskRow) {
    Row({ space: 12 }) {
        // 完成/撤销按钮
        if (row.undo) {
            Button({ type: ButtonType.Normal }) {
                Row({ space: 6 }) {
                    Text('↶').fontSize(18).fontColor(Theme.accent)
                    Text('撤销').fontSize(15).fontColor(Theme.accent)
                }
            }
            .backgroundColor(Theme.tint)
            .constraintSize({ minHeight: 48, minWidth: 80 })
            .borderRadius(12)
            .onClick((): void => { this.undo(row); })
        } else if (row.item.source === 'preparation') {
            // 使用更直观的勾选框
            Checkbox({ name: 'task-' + row.item.focusId })
                .select(false)
                .selectedColor(Theme.brand)
                .width(24)
                .height(24)
                .onChange((checked: boolean): void => {
                    if (checked) {
                        this.complete(row);
                    }
                })
                .accessibilityText('标记完成')
        }
        
        // 任务内容
        Column({ space: 6 }) {
            Text(displayName(row.item.title))
                .fontSize(16)
                .fontWeight(row.undo ? FontWeight.Normal : FontWeight.Medium)
                .fontColor(row.undo ? Theme.muted : Theme.ink)
                .decoration(row.undo ? { type: TextDecorationType.LineThrough } : {})
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            
            Row({ space: 8 }) {
                // 状态标签
                Text(row.undo ? '已完成' : row.item.kind === 'waiting' ? '在途' : row.item.group === 'overdue' ? '逾期' : '待办')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(row.item.group === 'overdue' ? Theme.danger : Theme.accent)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(row.item.group === 'overdue' ? Color.Transparent : Theme.tint)
                    .borderRadius(8)
                    .border(row.item.group === 'overdue' ? { width: 1, color: Theme.danger } : {})
                
                Text('·').fontSize(12).fontColor(Theme.muted)
                
                Text(displayName(row.item.projectName))
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .maxLines(1)
            }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        
        // 打开按钮
        if (!row.undo) {
            Button({ type: ButtonType.Circle }) {
                Text('›')
                    .fontSize(20)
                    .fontColor(Theme.muted)
            }
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)
            .onClick((): void => {
                this.openTask(row.item);
            })
        }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.surface)
    .borderRadius(Theme.cardRadius)
    .border({ width: 0.5, color: Theme.line })
}

// 新增快捷操作网格
@Builder quickActions() {
    Column({ space: Theme.stackSpace }) {
        SectionHeading({ title: '快捷操作' })
        
        GridRow({ columns: 2, gutter: Theme.cardSpacing }) {
            GridCol() {
                this.quickActionCard('新建计划', '🎭', (): void => {
                    this.add('project', '');
                })
            }
            
            GridCol() {
                this.quickActionCard('新建活动', '📅', (): void => {
                    this.add('event', '');
                })
            }
            
            GridCol() {
                this.quickActionCard('添加角色', '⭐', (): void => {
                    this.add('character', '');
                })
            }
            
            GridCol() {
                this.quickActionCard('查看衣柜', '👗', (): void => {
                    this.open('wardrobe', 'all');
                })
            }
        }
    }
}

@Builder quickActionCard(title: string, emoji: string, action: () => void) {
    Column({ space: 8 }) {
        Text(emoji)
            .fontSize(32)
        
        Text(title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.ink)
    }
    .width('100%')
    .height(100)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.surface)
    .borderRadius(Theme.cardRadius)
    .border({ width: 0.5, color: Theme.line })
    .onClick((): void => {
        vibration.dotVibration();
        action();
    })
}
```

#### 改进 8: 优化详情页导航

**方案: 添加 section 预览与面包屑**
```typescript
// ProjectDetailPage.ets
// 在标题栏下方添加进度指示器

@Builder sectionIndicator() {
    Row({ space: 8 }) {
        ForEach(['概览', '准备', '装箱', '记录'], (label: string, index: number) => {
            Column({ space: 4 }) {
                Row({ space: 4 }) {
                    // 序号
                    Text((index + 1).toString())
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.displayedSection === index ? Theme.onAccent : Theme.muted)
                        .width(20)
                        .height(20)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(this.displayedSection === index ? Theme.brand : Theme.tint)
                        .borderRadius(10)
                    
                    // 标签
                    Text(label)
                        .fontSize(13)
                        .fontWeight(this.displayedSection === index ? FontWeight.Medium : FontWeight.Normal)
                        .fontColor(this.displayedSection === index ? Theme.ink : Theme.muted)
                }
                
                // 进度条
                if (this.displayedSection === index) {
                    Column()
                        .width('100%')
                        .height(2)
                        .backgroundColor(Theme.brand)
                        .borderRadius(1)
                }
            }
            .layoutWeight(1)
            .onClick((): void => {
                this.route.section = index;
            })
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Theme.bg)
    .border({ width: { bottom: 0.5 }, color: Theme.divider })
}
```

### 2.4 视觉美感改进

#### 改进 9: 丰富卡片视觉层次

**方案 A: 为重要卡片添加渐变与阴影**
```typescript
// 首页的接下来卡片
@Builder planHeroV2(project: CosProject) {
    Column({ space: 16 }) {
        // ... 内容
    }
    .width('100%')
    .padding(20)
    .borderRadius(Theme.cardRadius)
    // 添加渐变背景
    .linearGradient({
        angle: 135,
        colors: [
            [Theme.surface, 0.0],
            [Theme.tint, 1.0]
        ]
    })
    // 添加阴影
    .shadow({
        radius: 16,
        color: Theme.shadow,
        offsetX: 0,
        offsetY: 4
    })
    // 添加边框
    .border({ width: 1, color: Theme.line })
}

// 今天模式入口卡片 (已在改进7中实现)
// 使用品牌色渐变 + 大阴影
```

**方案 B: 优化封面展示**
```typescript
// ProjectCard 中的封面
if (this.character()?.cover) {
    Stack({ alignContent: Alignment.BottomEnd }) {
        // 封面图
        ManagedImage({ ... })
            .width(68)
            .height(88)
            .borderRadius(12)
        
        // 添加角标(如果有新动态)
        if (this.hasNewUpdate()) {
            Column()
                .width(8)
                .height(8)
                .backgroundColor(Theme.danger)
                .borderRadius(4)
                .border({ width: 2, color: Theme.surface })
                .margin({ right: 4, bottom: 4 })
        }
    }
    .width(68)
    .height(88)
} else {
    // 无封面时使用渐变背景
    Column() {
        Text(this.state.characterName(this.project.characterId).slice(0, 1))
            .fontSize(36)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.onAccent)
    }
    .width(68)
    .height(88)
    .justifyContent(FlexAlign.Center)
    .borderRadius(12)
    .linearGradient({
        angle: 135,
        colors: [
            [Theme.brand, 0.0],
            [Theme.accent, 1.0]
        ]
    })
}
```

#### 改进 10: 增强图表视觉表现

**方案 A: 为饼图添加数据标签**
```typescript
// DistributionChart.ets
private drawLabels(context: CanvasRenderingContext2D): void {
    const centerX = this.canvasSize / 2;
    const centerY = this.canvasSize / 2;
    const radius = Math.min(centerX, centerY) * 0.7;
    const labelRadius = radius * 1.3;  // 标签位于饼图外侧
    
    const total = this.total();
    let currentAngle = -Math.PI / 2;
    
    this.items.forEach((item: PhotoDistributionItem, index: number) => {
        const angle = (item.value / total) * Math.PI * 2;
        const midAngle = currentAngle + angle / 2;
        
        // 计算标签位置
        const labelX = centerX + Math.cos(midAngle) * labelRadius;
        const labelY = centerY + Math.sin(midAngle) * labelRadius;
        
        // 绘制标签背景
        context.fillStyle = this.configuration.toHex(this.resolved(Theme.surface));
        const text = item.label + ' ' + Math.round((item.value / total) * 100) + '%';
        const metrics = context.measureText(text);
        context.fillRect(
            labelX - metrics.width / 2 - 6,
            labelY - 10,
            metrics.width + 12,
            20
        );
        
        // 绘制标签文字
        context.font = '12px sans-serif';
        context.fillStyle = this.configuration.toHex(this.resolved(Theme.ink));
        context.textAlign = 'center';
        context.textBaseline = 'middle';
        context.fillText(text, labelX, labelY);
        
        // 绘制引导线
        const lineStartX = centerX + Math.cos(midAngle) * radius;
        const lineStartY = centerY + Math.sin(midAngle) * radius;
        const lineMidX = centerX + Math.cos(midAngle) * (radius + 15);
        const lineMidY = centerY + Math.sin(midAngle) * (radius + 15);
        
        context.strokeStyle = this.configuration.toHex(this.resolved(Theme.line));
        context.lineWidth = 1;
        context.beginPath();
        context.moveTo(lineStartX, lineStartY);
        context.lineTo(lineMidX, lineMidY);
        context.lineTo(labelX, labelY - 10);
        context.stroke();
        
        currentAngle += angle;
    });
}

// 在 draw() 方法中调用
private draw(): void {
    // ... 现有绘制逻辑
    
    // 绘制标签
    if (this.progress === 1) {  // 动画完成后再绘制标签
        this.drawLabels(this.context);
    }
}
```

**方案 B: 增强折线图视觉冲击力**
```typescript
// InteractiveLineChart.ets
private drawLine(context: CanvasRenderingContext2D): void {
    // ... 现有逻辑
    
    // 增加线宽
    context.lineWidth = 3;  // 从 2 → 3
    context.strokeStyle = this.configuration.toHex(this.resolved(Theme.brand));
    context.lineJoin = 'round';  // 圆角连接
    context.lineCap = 'round';   // 圆角端点
    
    // 添加渐变填充(线下方区域)
    const gradient = context.createLinearGradient(0, 0, 0, this.chartHeight);
    gradient.addColorStop(0, this.configuration.toHex(this.resolved(Theme.brand)) + '40');  // 25% 透明度
    gradient.addColorStop(1, this.configuration.toHex(this.resolved(Theme.brand)) + '00');  // 完全透明
    
    context.fillStyle = gradient;
    context.fill();
    
    // 绘制数据点(增大)
    this.points.forEach((point: Point) => {
        context.beginPath();
        context.arc(point.x, point.y, 5, 0, Math.PI * 2);  // 从 4 → 5
        context.fillStyle = this.configuration.toHex(this.resolved(Theme.brand));
        context.fill();
        context.strokeStyle = this.configuration.toHex(this.resolved(Theme.surface));
        context.lineWidth = 2;
        context.stroke();
    });
}
```

---

## 三、实施计划

### 阶段 1: 基础改进 (2-3 天)

#### Day 1: 视觉层级优化
- [ ] 调整 ProjectCard 布局和字号
- [ ] 创建 Hero Card 变体
- [ ] 优化颜色对比度(运行 test_contrast.py)
- [ ] 建立间距系统并应用到主要页面
- [ ] 编译验证

#### Day 2: 交互体验优化
- [ ] 统一触摸目标尺寸(运行 check_touch_targets.sh)
- [ ] 优化动画时长和曲线
- [ ] 添加列表滚动阻尼
- [ ] 创建 SkeletonCard 组件
- [ ] 编译验证

#### Day 3: 空状态与反馈
- [ ] 重构 EmptyState 组件
- [ ] 准备空状态插图(可使用系统图标或 SVG)
- [ ] 应用到所有列表页面
- [ ] 编译验证

### 阶段 2: 信息架构改进 (2-3 天)

#### Day 4: 首页重构
- [ ] 实现 todayBanner()
- [ ] 重新设计 taskRowV2()
- [ ] 实现 quickActions()
- [ ] 调整首页布局顺序
- [ ] 编译验证

#### Day 5: 详情页导航
- [ ] 实现 sectionIndicator()
- [ ] 优化 section 切换动画
- [ ] 添加面包屑导航
- [ ] 编译验证

### 阶段 3: 视觉美感提升 (2-3 天)

#### Day 6: 卡片视觉优化
- [ ] 为重要卡片添加渐变
- [ ] 优化封面展示(渐变背景、角标)
- [ ] 添加阴影系统
- [ ] 编译验证

#### Day 7: 图表增强
- [ ] 为 DistributionChart 添加数据标签
- [ ] 增强 InteractiveLineChart 视觉表现
- [ ] 优化图表配色
- [ ] 编译验证

### 阶段 4: 验证与优化 (1 天)

#### Day 8: 全面验证
- [ ] 编译验证
- [ ] 对比度验证(test_contrast.py)
- [ ] 触摸目标验证(check_touch_targets.sh)
- [ ] 主题验证(test_theme_colors.py)
- [ ] 功能验证(五个主页面、详情页、设置)
- [ ] 深浅色切换验证
- [ ] 响应式布局验证(小屏、中屏、大屏)

---

## 四、验证清单

### 视觉验证
- [ ] 所有文字对比度 ≥ 4.5:1 (运行 test_contrast.py)
- [ ] 卡片层级清晰(封面、标题、次要信息、状态)
- [ ] 间距节奏一致(使用 Theme.space* 令牌)
- [ ] 深浅色主题都美观

### 交互验证
- [ ] 所有触摸目标 ≥ 48vp (运行 check_touch_targets.sh)
- [ ] 按压反馈及时(< 100ms)
- [ ] 滚动流畅(有阻尼效果)
- [ ] 加载状态清晰(骨架屏或占位符)

### 体验验证
- [ ] 空状态有插图和引导
- [ ] 首页优先级清晰("今天要做"最优先)
- [ ] 详情页导航清晰(section 指示器)
- [ ] 图表易读(有数据标签)

### 功能验证
- [ ] 所有页面正常显示和交互
- [ ] 详情页正常打开和返回
- [ ] 设置正常保存
- [ ] 深浅色切换正常
- [ ] 五组配色都正常

---

## 五、设计原则

### 1. 视觉层级原则
- **标题**: 18-24px, Bold, Theme.ink
- **正文**: 14-16px, Normal/Medium, Theme.ink
- **次要信息**: 12-14px, Normal, Theme.muted
- **标签**: 12-13px, Medium, Theme.accent

### 2. 间距节奏原则
- **行内**: 4-8px (icon + text)
- **组内**: 8-12px (卡片内元素)
- **组间**: 16-24px (section 内卡片)
- **区块**: 24-32px (section 之间)

### 3. 触摸目标原则
- **最小尺寸**: 48vp × 48vp
- **推荐尺寸**: 56vp × 56vp (主要按钮)
- **间距**: 8vp 以上

### 4. 动画原则
- **微交互**: 100-150ms (按压、悬停)
- **转场**: 250-350ms (页面切换)
- **入场**: 400-600ms (stagger 动画)
- **曲线**: springMotion 或 cubicBezier

### 5. 颜色对比度原则
- **正文**: ≥ 4.5:1 (WCAG AA)
- **大字**: ≥ 3:1 (18px+ Bold 或 24px+)
- **装饰**: 无要求

---

## 六、参考资源

### HarmonyOS 官方规范
- [触控与按钮设计](https://developer.huawei.com/consumer/cn/doc/design-guides/touch-design)
- [布局与间距](https://developer.huawei.com/consumer/cn/doc/design-guides/layout-and-spacing)
- [颜色与对比度](https://developer.huawei.com/consumer/cn/doc/design-guides/color-and-contrast)
- [动画与微交互](https://developer.huawei.com/consumer/cn/doc/design-guides/animation)

### WCAG 无障碍标准
- [WCAG 2.1 AA](https://www.w3.org/WAI/WCAG21/quickref/)
- [对比度检测工具](https://webaim.org/resources/contrastchecker/)

### Dashboard 参考
- `entry/src/main/ets/ui/theme/Theme.ets` - 主题系统
- `entry/src/main/ets/ui/animation/motion.ets` - 动画系统
- `entry/src/main/ets/components/common/` - 通用组件

---

**最后更新**: 2026-11-20  
**当前分支**: `uifix`  
**预计工时**: 6-9 天  
**优先级**: P1 (阶段1、2) > P2 (阶段3) > P3 (阶段4)
