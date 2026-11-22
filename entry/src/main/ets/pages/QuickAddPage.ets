import { AssetType } from '../models/Entities';
import { today } from '../utils/format';
import { AppState } from '../viewmodels/ApplicationState';
import { InteractiveCard, PillTone, SectionHeading, StatusPill } from '../components/Surfaces';
import { StaggerEntrance } from '../ui/motion';
import { scrollByAxis } from '../ui/scroll';
import { vibration } from '../ui/vibration';
import { showToastSafely } from '../ui/safeUi';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';

export interface QuickAddAiResult {
    kind: string;
    kindLabel: string;
    name: string;
    date: string;
    startTime: string;
    money: string;
    type: string;
    city: string;
    location: string;
    notes: string;
}

interface QuickAddOption {
    key: string;
    title: string;
    hint: string;
    icon: Resource;
    tint: Resource;
    bg: Resource;
}

const CITIES: string[] = [
    '上海', '北京', '广州', '深圳', '杭州', '成都', '南京', '武汉', '重庆', '西安', '苏州', '长沙', '天津', '青岛', '厦门',
];

const AI_EXAMPLES: string[] = [
    '下周六上海 CP 漫展',
    '刻晴假发 放在假发盒 B',
    '雷电将军出片计划 预算 1200 元',
    '摄影定金 300 元',
];

const WEEKDAY_MAP: Record<string, number> = {
    '日': 0,
    '天': 0,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
};

function addDays(baseDate: string, delta: number): string {
    const base = new Date(baseDate + 'T00:00:00');
    if (Number.isNaN(base.getTime())) {
        return baseDate;
    }
    base.setDate(base.getDate() + delta);
    const y = base.getFullYear();
    const m = String(base.getMonth() + 1).padStart(2, '0');
    const d = String(base.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function parseRelativeDate(text: string, baseDate: string): string {
    const iso = text.match(/(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})/);
    if (iso) {
        return `${iso[1]}-${iso[2].padStart(2, '0')}-${iso[3].padStart(2, '0')}`;
    }
    const md = text.match(/(\d{1,2})\s*[月.]\s*(\d{1,2})\s*日?/);
    if (md) {
        const year = Number(baseDate.slice(0, 4)) || new Date().getFullYear();
        const month = Number(md[1]);
        const day = Number(md[2]);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        }
    }
    if (text.includes('后天')) {
        return addDays(baseDate, 2);
    }
    if (text.includes('明天')) {
        return addDays(baseDate, 1);
    }
    if (text.includes('今天')) {
        return baseDate;
    }
    const nextWeek = text.match(/下周([一二三四五六日天])/);
    if (nextWeek) {
        const target = WEEKDAY_MAP[nextWeek[1]];
        const base = new Date(baseDate + 'T00:00:00');
        if (target !== undefined && !Number.isNaN(base.getTime())) {
            const currentDay = base.getDay();
            const mondayOffset = (currentDay + 6) % 7;
            const targetMondayOffset = (target + 6) % 7;
            const delta = 7 - mondayOffset + targetMondayOffset;
            return addDays(baseDate, delta);
        }
    }
    return '';
}

function parseAssetType(lower: string): string {
    if (lower.includes('假发') || lower.includes('毛胚')) {
        return AssetType.WIG;
    }
    if (lower.includes('鞋') || lower.includes('靴')) {
        return AssetType.SHOES;
    }
    if (lower.includes('道具') || lower.includes('武器') || lower.includes('剑')) {
        return AssetType.PROP;
    }
    if (lower.includes('配饰') || lower.includes('发饰') || lower.includes('耳饰')) {
        return AssetType.ACCESSORY;
    }
    if (lower.includes('美瞳')) {
        return AssetType.LENS;
    }
    if (lower.includes('妆品') || lower.includes('化妆')) {
        return AssetType.MAKEUP;
    }
    if (lower.includes('服装') || lower.includes('cos服') || lower.includes('c服') || lower.includes('衣服')) {
        return AssetType.COSTUME;
    }
    return AssetType.OTHER;
}

function parseEventType(lower: string): string {
    if (lower.includes('拍摄') || lower.includes('约拍') || lower.includes('棚拍')) {
        return '拍摄';
    }
    if (lower.includes('妆造')) {
        return '妆造';
    }
    if (lower.includes('聚会') || lower.includes('茶会') || lower.includes('同好')) {
        return '聚会';
    }
    if (lower.includes('漫展') || lower.includes('cp') || lower.includes('bw') || lower.includes('cj') || lower.includes('出展')) {
        return '漫展';
    }
    return '其他';
}

function parseExpenseCategory(lower: string): string {
    if (lower.includes('假发')) {
        return '假发';
    }
    if (lower.includes('美瞳')) {
        return '美瞳';
    }
    if (lower.includes('妆')) {
        return '妆造';
    }
    if (lower.includes('摄影') || lower.includes('约拍')) {
        return '摄影';
    }
    if (lower.includes('后期') || lower.includes('修图')) {
        return '后期';
    }
    if (lower.includes('门票')) {
        return '门票';
    }
    if (lower.includes('交通') || lower.includes('高铁') || lower.includes('打车')) {
        return '交通';
    }
    if (lower.includes('住宿') || lower.includes('酒店')) {
        return '住宿';
    }
    if (lower.includes('道具')) {
        return '道具';
    }
    if (lower.includes('服')) {
        return '服装';
    }
    return '其他';
}

export function parseQuickAddInput(raw: string, baseDate: string): QuickAddAiResult {
    const trimmed = raw.trim();
    const lower = trimmed.toLocaleLowerCase();
    const date = parseRelativeDate(trimmed, baseDate);
    const timeMatch = trimmed.match(/\b([01]?\d|2[0-3]):([0-5]\d)\b/);
    const startTime = timeMatch ? `${timeMatch[1].padStart(2, '0')}:${timeMatch[2]}` : '';
    const moneyMatch = trimmed.match(/(?:¥|￥|预算|花了|花费|定金|尾款|费用)\s*(\d+(?:\.\d{1,2})?)\s*(?:元|块|rmb)?|(\d+(?:\.\d{1,2})?)\s*(?:元|块|rmb)/i);
    const money = moneyMatch ? (moneyMatch[1] || moneyMatch[2] || '') : '';
    const city = CITIES.find((item: string): boolean => trimmed.includes(item)) || '';
    const locMatch = trimmed.match(/(?:放在|放|位于|收纳在|存放在)\s*([^\s，。,；;]{2,18})/);
    const location = locMatch ? locMatch[1].trim() : '';

    let kind = 'project';
    let kindLabel = '出片计划';
    let type = '';

    if (lower.includes('导入照片') || lower.includes('上传照片') || lower.includes('导图') || lower.includes('选片')) {
        kind = 'photo';
        kindLabel = '导入照片';
    } else if (lower.includes('http://') || lower.includes('https://') || lower.includes('收录') || lower.includes('链接') || lower.includes('灵感笔记')) {
        kind = 'inbox';
        kindLabel = '新建收录';
    } else if ((lower.includes('花费') || lower.includes('支出') || lower.includes('记一笔') || lower.includes('定金') || lower.includes('尾款') || lower.includes('花了') || lower.includes('门票') || lower.includes('交通') || lower.includes('住宿')) &&
        !lower.includes('计划') && !lower.includes('预算')) {
        kind = 'expense';
        kindLabel = '花费记录';
        type = parseExpenseCategory(lower);
    } else if (lower.includes('假发') || lower.includes('毛胚') || lower.includes('服装') || lower.includes('cos服') || lower.includes('c服') ||
        lower.includes('鞋') || lower.includes('靴') || lower.includes('道具') || lower.includes('配饰') || lower.includes('美瞳') ||
        lower.includes('妆品') || lower.includes('衣柜') || lower.includes('装备')) {
        kind = 'asset';
        kindLabel = '衣柜装备';
        type = parseAssetType(lower);
    } else if (lower.includes('漫展') || lower.includes('cp') || lower.includes('bw') || lower.includes('cj') ||
        lower.includes('约拍') || lower.includes('棚拍') || lower.includes('聚会') || lower.includes('活动') ||
        lower.includes('出展') || lower.includes('茶会')) {
        kind = 'event';
        kindLabel = '日程活动';
        type = parseEventType(lower);
    } else if (lower.includes('新增角色') || lower.includes('添加角色') || lower.includes('角色')) {
        kind = 'character';
        kindLabel = '角色库角色';
    }

    let cleanedName = trimmed
        .replace(/^(?:帮我|请)?(?:添加|新增|新建|记录|记一笔|买了|购买)\s*/, '')
        .replace(/(?:放在|放|位于|收纳在|存放在)\s*[^\s，。,；;]{2,18}/g, '')
        .replace(/(?:¥|￥|预算|花了|花费|定金|尾款)\s*\d+(?:\.\d{1,2})?\s*(?:元|块|rmb)?/gi, '')
        .trim();
    if (!cleanedName) {
        cleanedName = trimmed;
    }
    if (cleanedName.length > 24) {
        cleanedName = cleanedName.slice(0, 24);
    }

    return {
        kind,
        kindLabel,
        name: cleanedName,
        date,
        startTime,
        money,
        type,
        city,
        location,
        notes: trimmed,
    };
}

@ComponentV2
export struct QuickAddPage {
    @Require @Param state: AppState;
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Param topInset: number = Theme.detailTop;
    @Param bottomInset: number = Theme.detailBottom;
    @Event onSelectOption: (kind: string) => void = () => {};
    @Event onAiSubmit: (result: QuickAddAiResult) => void = () => {};
    @Local aiInput: string = '';
    @Local contentWidth: number = 360;
    private scroller: Scroller = new Scroller();

    private readonly options: QuickAddOption[] = [
        { key: 'project', title: '新建计划', hint: '规划角色、准备清单与排期', icon: Icons.plan, tint: Theme.accent, bg: Theme.tint },
        { key: 'character', title: '添加角色', hint: '录入角色、作品与造型版本', icon: Icons.tabProfile, tint: Theme.purple, bg: Theme.purpleBg },
        { key: 'event', title: '添加活动', hint: '记录漫展、拍摄与聚会提醒', icon: Icons.event, tint: Theme.warning, bg: Theme.warningBg },
        { key: 'asset', title: '添加装备', hint: '收纳服装、假发与存放位置', icon: Icons.library, tint: Theme.success, bg: Theme.successBg },
        { key: 'photo', title: '导入照片', hint: '从系统相册导入并归属计划', icon: Icons.importPhoto, tint: Theme.info, bg: Theme.noticeBg },
        { key: 'expense', title: '记一笔', hint: '记录服装、摄影等项目花费', icon: Icons.creditcard, tint: Theme.danger, bg: Theme.dangerBg },
        { key: 'inbox', title: '新建收录', hint: '保存参考链接与灵感便签', icon: Icons.folder, tint: Theme.accent, bg: Theme.tint },
    ];

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private optionColumns(): number {
        return this.contentWidth >= 340 ? 2 : 1;
    }

    private submitAi(): void {
        if (!this.writable()) {
            return;
        }
        if (!this.aiInput.trim()) {
            showToastSafely(this.getUIContext().getPromptAction(), '请先输入一句话描述要添加的内容', 2000, 'QuickAdd');
            return;
        }
        const result = parseQuickAddInput(this.aiInput, today());
        vibration.dotVibration();
        this.onAiSubmit(result);
    }

    @Builder aiCard() {
        Column({ space: 12 }) {
            Row({ space: 10 }) {
                Stack({ alignContent: Alignment.Center }) {
                    SymbolGlyph(Icons.ai)
                        .fontSize(20)
                        .fontColor([Theme.accent])
                        .accessibilityLevel('no')
                }.width(38)
                    .height(38)
                    .borderRadius(Theme.slotRadius)
                    .backgroundColor(Theme.tint)
                Text('AI 添加')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .layoutWeight(1)
                StatusPill({ label: '智能识别', tone: 'brand' as PillTone, compact: true })
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            TextArea({
                text: this.aiInput,
                placeholder: '输入一句话描述，自动识别计划、日程、装备或花费，例如：下周六上海 CP 漫展 / 刻晴假发放在假发盒 B',
            })
                .id('quick-add-ai-input')
                .width('100%')
                .height(96)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor(Theme.tint)
                .border({ width: 0.8, color: Theme.line, radius: Theme.controlRadius })
                .borderRadius(Theme.controlRadius)
                .fontSize(14)
                .fontColor(Theme.ink)
                .onChange((value: string): void => {
                    this.aiInput = value;
                })
                .accessibilityText('AI 添加内容输入框')
            Scroll() {
                Row({ space: 8 }) {
                    ForEach(AI_EXAMPLES, (sample: string) => {
                        Button(sample, { type: ButtonType.Capsule, stateEffect: false })
                            .height(32)
                            .padding({ left: 12, right: 12 })
                            .backgroundColor(Theme.tint)
                            .border({ width: 0.8, color: Theme.line, radius: Theme.pillRadius })
                            .borderRadius(Theme.pillRadius)
                            .fontSize(12)
                            .fontColor(Theme.muted)
                            .onClick((): void => {
                                vibration.dotVibration();
                                this.aiInput = sample;
                            })
                            .accessibilityText('填入示例：' + sample)
                    }, (sample: string) => sample)
                }.padding({ right: 4 })
            }.width('100%')
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
            Button({ type: ButtonType.Capsule, stateEffect: false }) {
                Row({ space: 8 }) {
                    SymbolGlyph(Icons.ai)
                        .fontSize(17)
                        .fontColor([Theme.onAccent])
                        .accessibilityLevel('no')
                    Text('AI 识别并填入')
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.onAccent)
                }
            }.id('quick-add-ai-submit')
                .width('100%')
                .height(44)
                .backgroundColor(Theme.brand)
                .borderRadius(Theme.pillRadius)
                .enabled(this.writable())
                .onClick((): void => {
                    this.submitAi();
                })
                .accessibilityText('AI 识别并填入对应表单')
        }.id('quick-add-ai')
            .width('100%')
            .padding(16)
            .backgroundColor(Theme.surface)
            .border({ width: 1, color: Theme.line, radius: Theme.cardRadius })
            .borderRadius(Theme.cardRadius)
            .shadow({ radius: 10, color: Theme.shadow, offsetX: 0, offsetY: 2 })
            .attributeModifier(this.entrance.group(1))
    }

    @Builder optionCardContent(option: QuickAddOption) {
        Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(option.icon)
                    .fontSize(20)
                    .fontColor([option.tint])
                    .accessibilityLevel('no')
            }.width(42)
                .height(42)
                .borderRadius(Theme.slotRadius)
                .backgroundColor(option.bg)
            Column({ space: 4 }) {
                Text(option.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(option.hint)
                    .fontSize(12)
                    .fontColor(Theme.muted)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
        }.width('100%')
            .alignItems(VerticalAlign.Center)
    }

    build() {
        Scroll(this.scroller) {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(this.topInset).width('100%')
                this.aiCard()
                Column({ space: Theme.sectionContentGap }) {
                    SectionHeading({
                        title: '常规添加',
                        icon: Icons.add,
                        trailing: this.options.length + ' 项入口',
                    })
                    List({ space: Theme.cardSpacing }) {
                        ForEach(this.options, (option: QuickAddOption) => {
                            ListItem() {
                                InteractiveCard({
                                    label: option.title,
                                    hint: option.hint,
                                    effects: this.state.settings.effects,
                                    contentPadding: 14,
                                    action: (): void => {
                                        this.onSelectOption(option.key);
                                    },
                                    content: (): void => {
                                        this.optionCardContent(option);
                                    },
                                }).id('quick-add-option-' + option.key)
                            }
                        }, (option: QuickAddOption) => option.key)
                    }.width('100%')
                        .lanes(this.optionColumns(), Theme.cardSpacing)
                        .scrollBar(BarState.Off)
                        .nestedScroll({
                            scrollForward: NestedScrollMode.PARENT_FIRST,
                            scrollBackward: NestedScrollMode.SELF_FIRST,
                        })
                }.width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .attributeModifier(this.entrance.group(2))
                Blank().height(this.bottomInset).width('100%')
            }.width('100%')
                .constraintSize({ maxWidth: Theme.contentMaxWidth })
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .alignItems(HorizontalAlign.Start)
        }.id('quick-add-scroll')
            .width('100%')
            .height('100%')
            .align(Alignment.Top)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .backgroundColor(Theme.bg)
            .onAreaChange((_old: Area, area: Area): void => {
                this.contentWidth = Number(area.width);
            })
            .onAxisEvent((event: AxisEvent): void => {
                scrollByAxis(this.scroller, event);
            })
    }
}
