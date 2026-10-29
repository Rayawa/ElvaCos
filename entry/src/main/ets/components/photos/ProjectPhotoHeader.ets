import { SheetContent } from '../common/SheetContent';
import { ContextRow } from '../common/ContextRow';
import { AppState } from '../../state/ApplicationState';
import { ProjectRoute } from '../../models/ProjectRoute';
import { ProjectShot } from '../../models/Shot';
import { ReferenceImage } from '../../models/Planning';
import { Theme } from '../../ui/theme/Theme';
import { StaggerEntrance } from '../../ui/animation/motion';
import { appSheetOptions, dismissSheet } from '../../ui/sheet/sheet';
import { confirm } from '../../ui/feedback/Confirm';
import { operationCommitted } from '../../domain/operations/OperationResult';
import { SheetHeader } from '../common/SheetHeader';
import { ManagedImage } from '../common/ManagedImage';
import { EmptyState } from '../common/Surfaces';

@ComponentV2
export struct ProjectPhotoHeader {
    @Require @Param state: AppState;
    @Require @Param route: ProjectRoute;
    @Event edit: (id: string, projectId: string) => void = () => {};
    @Event openReference: (id: string) => void = () => {};
    @Event openAlbum: () => void = () => {};
    @Local entrance: StaggerEntrance = new StaggerEntrance();
    @Local actionError: string = '';
    private scroller: Scroller = new Scroller();
    private measured: boolean = false;
    private restoring: boolean = true;
    private viewportTop: number = 0;
    private timer: number = -1;
    private pendingReference: string = '';
    private pendingEdit: boolean = false;
    private pendingEditId: string = '';
    private targetY: number = -1;

    private items(): ProjectShot[] {
        return this.state.readiness(this.route.id).shots.items;
    }

    private writable(): boolean {
        return !this.state.busy && !this.state.staleScopes.length;
    }

    private reference(shot: ProjectShot): ReferenceImage | undefined {
        return this.state.references.find((reference: ReferenceImage) => reference.id === shot.referenceId);
    }

    aboutToDisappear(): void {
        if (this.timer >= 0) {
            clearTimeout(this.timer);
        }
    }

    @Monitor('route.shotsOpen', 'route.restoreVersion', 'state.shots', 'state.staleScopes')
    changed(): void {
        if (this.route.shotsOpen) {
            this.restoring = true;
            this.restore();
        }
    }

    private restore(): void {
        if (!this.measured || !this.route.shotsOpen) {
            return;
        }
        if (!this.state.staleScopes.length && this.route.focusShotId && !this.route.focusShotHandled && !this.items().some((shot: ProjectShot) => shot.id === this.route.focusShotId)) {
            this.route.focusShotHandled = true;
            this.actionError = '这条拍摄事项已不存在，已保留所属计划与附近位置';
        }
        if (this.timer >= 0) {
            clearTimeout(this.timer);
        }
        this.timer = setTimeout((): void => {
            this.timer = -1;
            if (this.route.focusShotId && !this.route.focusShotHandled) {
                if (this.targetY < 0) {
                    return;
                }
                this.route.focusShotHandled = true;
                this.route.shotOffset = Math.max(0, this.scroller.currentOffset().yOffset + this.targetY - this.viewportTop - 12);
                try {
                    this.getUIContext().getFocusController().requestFocus('shot-row:' + this.route.focusShotId);
                } catch (error) {
                }
            }
            this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.shotOffset, animation: false });
            this.restoring = false;
        }, 0);
    }

    private focusArea(shot: ProjectShot, area: Area): void {
        if (shot.id === this.route.focusShotId && !this.route.focusShotHandled) {
            this.targetY = Number(area.globalPosition.y);
            this.restore();
        }
    }

    private async toggle(shot: ProjectShot): Promise<void> {
        this.actionError = '';
        const result = await this.state.toggleShot(shot.id, this.route.id, shot.done);
        if (!operationCommitted(result)) {
            this.actionError = this.state.error || '拍摄勾选未保存，请重试';
        }
    }

    private async remove(shot: ProjectShot): Promise<void> {
        if (await confirm(this.getUIContext(), '删除拍摄事项？', '将删除「' + shot.title + '」。仅影响这份计划的拍摄清单，参考图和其他记录保留。', '删除')) {
            if (!(await this.state.removeShot(shot.id, this.route.id))) {
                this.actionError = this.state.error || '删除失败，原事项保留';
            }
        }
    }

    private startEdit(id: string): void {
        this.pendingEdit = true;
        this.pendingEditId = id;
        this.route.shotsOpen = false;
    }

    private startReference(id: string): void {
        this.pendingReference = id;
        this.route.resumeShots = true;
        this.route.shotsOpen = false;
    }

    private close(): void {
        if (!this.state.busy) {
            this.route.shotsOpen = false;
        }
    }

    private options(): SheetOptions {
        const options = appSheetOptions((): void => {
            this.route.shotsOpen = false;
            this.measured = false;
            this.targetY = -1;
            if (this.pendingEdit) {
                this.pendingEdit = false;
                const id = this.pendingEditId;
                this.pendingEditId = '';
                this.edit(id, this.route.id);
            } else if (this.pendingReference) {
                const id = this.pendingReference;
                this.pendingReference = '';
                this.openReference(id);
            }
        }, this.entrance, this.getUIContext());
        options.onWillDismiss = (action: DismissSheetAction): void => {
            void dismissSheet(action, async (): Promise<boolean> => !this.state.busy);
        };
        return options;
    }

    @Builder sheet() {
        SheetContent() {
            Column({ space: 14 }) {
                SheetHeader({ title: '拍摄清单', hint: this.state.projectName(this.route.id), haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel, close: (): void => {
                        this.close();
                    }
                })
                ContextRow({ label: '已拍', text: this.state.readiness(this.route.id)
                        .shots.done + ' / ' + this.state.readiness(this.route.id)
                        .shots.total + ' 项' })
                Button('添加拍摄事项').constraintSize({ minHeight: 48 }).width('100%').enabled(this.writable()).onClick((): void => {
                    this.startEdit('');
                })
                if (this.actionError || this.state.error) {
                    Text(this.actionError || this.state.error).fontSize(14).fontColor(Theme.danger)
                }
                Scroll(this.scroller) {
                    Column({ space: 12 }) {
                        ForEach(this.items(), (shot: ProjectShot) => {
                            Column({ space: 8 }) {
                                Button() {
                                    ContextRow({ label: shot.done ? '已拍' : '待拍', text: shot.title, prominent: true })
                                }.type(ButtonType.Normal).constraintSize({ minHeight: 48 }).width('100%').enabled(this.writable())
                                    .backgroundColor(shot.done ? Theme.tint : Theme.surface).fontColor(Theme.ink).id('shot-row:' + shot.id).focusable(true)
                                    .onClick((): void => {
                                        void this.toggle(shot);
                                    }).accessibilityText((shot.done ? '取消已拍 ' : '标记已拍 ') + shot.title)
                                if (this.reference(shot)) {
                                    Button() {
                                        Row({ space: 10 }) {
                                            if (this.reference(shot)?.thumbnailPath) {
                                                ManagedImage({ sourcePath: this.reference(shot)?.thumbnailPath || '', label: '拍摄参考图' }).width(64).height(64)
                                            }
                                            ContextRow({ label: '参考图', text: this.reference(shot)?.caption || '无说明' }).layoutWeight(1)
                                        }.width('100%')
                                    }.type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).onClick((): void => {
                                        this.startReference(shot.referenceId);
                                    })
                                }
                                Row({ space: 8 }) {
                                    Button('编辑事项').constraintSize({ minHeight: 48 }).enabled(this.writable()).onClick((): void => {
                                        this.startEdit(shot.id);
                                    }).accessibilityText('编辑拍摄事项 ' + shot.title)
                                    Button('删除事项').constraintSize({ minHeight: 48 }).enabled(this.writable()).fontColor(Theme.danger).onClick((): void => {
                                        void this.remove(shot);
                                    }).accessibilityText('删除拍摄事项 ' + shot.title)
                                }
                            }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
                                .onAreaChange((_, area: Area): void => {
                                    this.focusArea(shot, area);
                                })
                        }, (shot: ProjectShot) => shot.id)
                        if (!this.items().length) {
                            EmptyState({ title: '记下今天想拍的画面', message: '可选关联此计划或角色的参考图，拍摄完成后勾选。', button: '添加拍摄事项', action: (): void => {
                                    if (this.writable()) {
                                        this.startEdit('');
                                    }
                                }
                            })
                        }
                    }.width('100%').alignItems(HorizontalAlign.Start)
                }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
                    .onAreaChange((_, area: Area): void => {
                        this.viewportTop = Number(area.globalPosition.y);
                        if (Number(area.height) > 0 && !this.measured) {
                            this.measured = true;
                            this.restore();
                        }
                    })
                    .onDidScroll((): void => {
                        if (this.measured && !this.restoring) {
                            this.route.shotOffset = this.scroller.currentOffset().yOffset;
                        }
                    })
            }.padding(Theme.pagePadding).width('100%').height('100%').backgroundColor(Theme.surface)
        }
    }

    build() {
        Column({ space: 8 }) {
            ContextRow({ label: '本计划照片', text: this.state.readiness(this.route.id).photos.total + ' 张' })
            Button('在相册查看本计划').width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent)
                .onClick((): void => {
                    this.openAlbum();
                })
            Button() {
                ContextRow({ label: '拍摄清单', text: '已拍 ' + this.state.readiness(this.route.id)
                        .shots.done + ' / ' + this.state.readiness(this.route.id)
                        .shots.total + ' 项' })
            }.type(ButtonType.Normal).width('100%').constraintSize({ minHeight: 48 }).id('project-shots-open')
                .backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
                .padding({ left: 16, right: 16 })
                .onClick((): void => {
                    this.actionError = '';
                    this.route.shotsOpen = true;
                })
        }.width('100%').alignItems(HorizontalAlign.Start)
            .bindSheet(this.route.shotsOpen, this.sheet(), this.options())
    }
}
