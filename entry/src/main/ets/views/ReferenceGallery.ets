import { curves } from '@kit.ArkUI';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { Icons } from '../ui/Icons';
import { vibration } from '../ui/vibration';
import { photoColumnCount } from '../ui/responsive';
import { ReferenceImage } from '../models/Planning';
import { ManagedImage } from '../components/ManagedImage';
import { SectionHeading } from '../components/Surfaces';

@ComponentV2
export struct ReferenceGallery {
    @Require @Param state: AppState;
    @Param images: ReferenceImage[] = [];
    @Param fullHeight: boolean = false;
    @Event add: () => void = () => {};
    @Event open: (id: string) => void = () => {};
    @Local columnCount: number = 2;
    @Local userColumns: number = 0;
    @Local pressedId: string = '';

    private columns(): number {
        return Math.min(4, Math.max(2, this.columnCount));
    }

    private columnsTemplate(): string {
        return new Array<string>(this.columns()).fill('1fr').join(' ');
    }

    private applyColumns(next: number): void {
        const clamped = Math.min(4, Math.max(2, next));
        if (clamped === this.columnCount && this.userColumns === clamped) {
            return;
        }
        vibration.dotVibration();
        this.getUIContext().animateTo({ duration: 220, curve: curves.springMotion(0.4, 0.9) }, (): void => {
            this.userColumns = clamped;
            this.columnCount = clamped;
        });
    }

    private cycleColumns(): void {
        const current = this.columns();
        const next = current >= 4 ? 2 : current + 1;
        this.applyColumns(next);
    }

    @Builder referenceCard(r: ReferenceImage) {
        Column({ space: 0 }) {
            ManagedImage({
                sourcePath: r.thumbnailPath,
                label: r.caption || '准备参考图',
                failureText: r.localPath ? '缩略图加载失败' : '图片缺失，请重新导入',
                ratio: 0,
                radius: 0,
            }).width('100%')
            if (r.caption.trim() || !r.localPath) {
                Text(r.caption.trim() || '图片缺失，请重新导入')
                    .fontSize(12)
                    .fontColor(Theme.ink)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .padding({ left: 9, right: 9, top: 7, bottom: 9 })
                    .width('100%')
            }
        }.id('reference-thumbnail:' + r.id)
            .width('100%')
            .backgroundColor(Theme.surface)
            .borderRadius(12)
            .border({ width: 0.6, color: Theme.line })
            .clip(true)
            .scale({ x: this.pressedId === r.id ? 0.98 : 1, y: this.pressedId === r.id ? 0.98 : 1 })
            .animation({ duration: 120, curve: curves.springMotion(0.35, 0.9) })
            .onTouch((event: TouchEvent): void => {
                if (event.type === TouchType.Down) {
                    this.pressedId = r.id;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.pressedId = '';
                }
            })
            .onClick((): void => {
                vibration.dotVibration();
                this.open(r.id);
            })
            .focusable(true)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(r.caption || '打开准备参考图')
            .accessibilityLevel('yes')
    }

    build() {
        Column({ space: 10 }) {
            Row({ space: 8 }) {
                SectionHeading({ title: '参考图片', icon: Icons.importPhoto, trailing: this.images.length + ' 张' }).layoutWeight(1)
                if (this.images.length > 0) {
                    Button(this.columns() + '列', { type: ButtonType.Normal, stateEffect: false })
                        .height(34)
                        .padding({ left: 10, right: 10 })
                        .borderRadius(Theme.pillRadius)
                        .backgroundColor(Theme.surface)
                        .border({ width: 0.8, color: Theme.line })
                        .fontSize(12)
                        .fontColor(Theme.muted)
                        .onClick((): void => {
                            this.cycleColumns();
                        })
                        .accessibilityText('当前每行显示 ' + this.columns() + ' 列，点击切换列数，也支持双指捏合缩放')
                }
                Button({ type: ButtonType.Normal, stateEffect: false }) {
                    Row({ space: 5 }) {
                        SymbolGlyph(Icons.add).fontSize(14).fontColor([Theme.accent]).accessibilityLevel('no')
                        Text('添加图片').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.accent)
                    }.padding({ left: 12, right: 12 })
                }.accessibilityText('添加图片')
                    .height(34)
                    .borderRadius(Theme.pillRadius)
                    .backgroundColor(Theme.tint)
                    .border({ width: 0.8, color: Theme.line })
                    .enabled(!this.state.busy)
                    .onClick((): void => {
                        vibration.dotVibration();
                        this.add();
                    })
            }.width('100%')
                .alignItems(VerticalAlign.Center)
            if (this.images.length === 0) {
                Text('添加角色设定、妆容或姿势参考，准备时随时查看。')
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .padding(14)
                    .width('100%')
                    .backgroundColor(Theme.tint)
                    .borderRadius(Theme.cardRadius)
            } else {
                WaterFlow({ layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
                    ForEach(this.images, (r: ReferenceImage) => {
                        FlowItem() {
                            this.referenceCard(r)
                        }.width('100%')
                    }, (r: ReferenceImage) => r.id + ':' + r.thumbnailPath + ':' + r.caption)
                }.width('100%')
                    .columnsTemplate(this.columnsTemplate())
                    .columnsGap(8)
                    .rowsGap(10)
                    .constraintSize(this.fullHeight ? { minHeight: 320, maxHeight: 780 } : { minHeight: 220, maxHeight: 500 })
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                    .nestedScroll({
                        scrollForward: NestedScrollMode.PARENT_FIRST,
                        scrollBackward: NestedScrollMode.SELF_FIRST,
                    })
                    .priorityGesture(
                        PinchGesture({ fingers: 2, distance: 10 })
                            .onActionEnd((event: GestureEvent): void => {
                                if (!event) {
                                    return;
                                }
                                if (event.scale > 1.15 && this.columns() > 2) {
                                    this.applyColumns(this.columns() - 1);
                                } else if (event.scale < 0.85 && this.columns() < 4) {
                                    this.applyColumns(this.columns() + 1);
                                }
                            })
                    )
                    .onAreaChange((_old: Area, area: Area): void => {
                        if (this.userColumns === 0) {
                            const count = Math.min(4, Math.max(2, photoColumnCount(Number(area.width))));
                            if (count !== this.columnCount) {
                                this.columnCount = count;
                            }
                        }
                    })
            }
        }.width('100%')
            .alignItems(HorizontalAlign.Start)
    }
}
