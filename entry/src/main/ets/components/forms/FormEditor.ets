import { CharacterFields } from './CharacterFields';
import { ShotFields } from './ShotFields';
import { PreparationFields } from './PreparationFields';
import { ExpenseFields } from './ExpenseFields';
import { TeamFields } from './TeamFields';
import { EventFields } from './EventFields';
import { AssetFields } from './AssetFields';
import { ProjectFields } from './ProjectFields';
import { ReferenceImage } from '../../models/Planning';
import { shotReferences } from '../../models/Shot';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { CosProject, CosEvent } from '../../models/Entities';
import { StaggerEntrance } from '../../ui/animation/motion';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { vibration } from '../../ui/feedback/vibration';
import { formatTime } from '../../utils/format/format';
import { FormSession } from '../../state/forms/FormSession';
import { EditDraft, FormIssue } from '../../state/forms/EditDraft';
import { SheetHeader } from '../common/SheetHeader';
import { Field } from '../common/Surfaces';

@ComponentV2
export struct FormEditor {
    @Param creationAction: string = '创建计划并开始准备';
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Param entrance: StaggerEntrance = new StaggerEntrance();
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Require @Param session: FormSession;
    @Event close: () => void = () => {};
    @Local issues: FormIssue[] = [];
    @Local formError: string = '';
    private scroller: Scroller = new Scroller();
    private positions: Map<string, number> = new Map();
    private viewportTop: number = 0;
    private viewportHeight: number = 0;
    private focusedField: string = '';
    private focusTimer: number = -1;
    private attempted: boolean = false;
    @Computed
    get draftValue(): string {
        return this.draft.fingerprint();
    }

    @Monitor('draftValue')
    changed(): void {
        if (this.attempted) {
            this.issues = this.draft.issues(this.state);
        }
        if (!this.session.submitting) {
            this.session.changed();
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
        if (this.focusTimer >= 0) {
            clearTimeout(this.focusTimer);
            this.focusTimer = -1;
        }
        void this.session.flush();
    }

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    private fieldArea(field: string, area: Area): void {
        try {
            this.positions.set(field, Number(area.globalPosition.y) - this.viewportTop + this.scroller.currentOffset().yOffset);
        } catch (error) {
        }
    }

    private reveal(field: string, requestFocus: boolean = false): void {
        const offset = this.positions.get(field);
        this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, (offset || 0) - 12), animation: false });
        if (requestFocus && field !== 'object') {
            try {
                this.getUIContext().getFocusController().requestFocus('form-input:' + field);
            } catch (error) {
            }
        }
    }

    private focus(field: string): void {
        this.focusedField = field;
        this.reveal(field);
    }

    private locateFirstError(): void {
        const field = this.issues[0]?.field || 'object';
        if (['variantId', 'eventId', 'shootingTime', 'money'].includes(field) && this.draft.kind === 'project') {
            this.draft.advanced = true;
        }
        if (this.focusTimer >= 0) {
            clearTimeout(this.focusTimer);
        }
        this.focusTimer = setTimeout((): void => {
            this.focusTimer = -1;
            this.reveal(field, true);
        }, 60);
    }

    @Builder fieldIssue(field: string) {
        if (this.issue(field)) {
            Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field))
        }
    }

    private draftTime(value: number): string {
        const date = new Date(value);
        return formatTime(value) + ' ' + String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0');
    }

    @Builder draftStatus() {
        if (!this.draft.exists(this.state)) {
            Text('记录已不存在，请关闭表单后返回有效页面。').fontSize(16).fontColor(Theme.danger)
        }
        if (this.session.loading) {
            Text('正在读取本地草稿…').fontSize(14).fontColor(Theme.muted)
        }
        if (this.session.pendingRestore) {
            Text('有 ' + this.draftTime(this.session.pendingRestore.savedAt) + ' 的未保存草稿').fontSize(16).fontColor(Theme.ink)
            Row({ space: 8 }) {
                Button('恢复草稿').id('form-restore-draft').constraintSize({ minHeight: 48 }).onClick((): void => {
                    this.session.restore();
                })
                Button('放弃草稿').id('form-discard-draft').constraintSize({ minHeight: 48 }).onClick((): void => {
                    this.session.discardRecovery();
                })
            }
        }
        if (this.session.recoveredAt) {
            Text('已恢复 ' + this.draftTime(this.session.recoveredAt) + ' 的草稿，尚未写入正式记录').fontSize(14).fontColor(Theme.muted)
        }
        if (this.session.sourceChanged) {
            Text('原记录已变更，请核对恢复内容后保存。').fontSize(14).fontColor(Theme.accent)
        }
        if (this.session.error) {
            Text(this.session.error).id('form-draft-error').fontSize(14).fontColor(Theme.danger)
        } else if (!this.session.pendingRestore && this.session.savedAt) {
            Text(this.session.saving ? '正在保存本地草稿…' : '本地草稿已保存').id('form-draft-status').fontSize(14).fontColor(Theme.muted)
        }
        if (!this.session.loading && !this.session.recoveryChecked) {
            Row({ space: 8 }) {
                Button('重试读取草稿').constraintSize({ minHeight: 48 }).onClick((): void => {
                    this.session.initialize(this.state);
                })
                Button('跳过草稿，继续编辑').constraintSize({ minHeight: 48 }).onClick((): void => {
                    this.session.ignoreRecovery();
                })
            }
        }
    }

    @Event saved: (kind: string, id: string, created: boolean) => void = () => {};
    @Event done: () => void = () => {};

    private async save(): Promise<void> {
        if (this.state.busy || this.session.submitting || this.session.loading || !this.session.recoveryChecked || this.session.pendingRestore || this.state.staleScopes.length) {
            return;
        }
        this.attempted = true;
        this.formError = '';
        this.issues = this.draft.issues(this.state);
        if (this.issues.length) {
            this.locateFirstError();
            return;
        }
        const created = !this.draft.id;
        this.session.submitting = true;
        try {
            await this.session.flush();
            if (await this.draft.save(this.state)) {
                const cleaned = await this.session.finish(true, true);
                if (!cleaned) {
                    this.state.reportNotice('记录已保存；对应草稿清理失败，下次打开会核对已保存记录。');
                }
                this.done();
                this.saved(this.draft.kind, this.draft.id, created);
                if (this.draft.kind === 'event' && this.draft.deviceCalendar) {
                    const event = this.state.events.find((event: CosEvent) => event.id === this.draft.id);
                    if (event && !this.state.staleScopes.length) {
                        await this.state.addEventToCalendar(event);
                    }
                }
            } else {
                this.formError = this.state.error || '记录未保存，请重试';
            }
        } catch (error) {
            this.formError = (error as Error).message || '记录未保存，请重试';
            this.state.reportError(this.formError);
        } finally {
            this.session.submitting = false;
        }
    }

    private nameHint(): string {
        if (this.draft.kind === 'shot') {
            return '例如：桥边回头、合影、道具特写';
        }
        if (this.draft.kind === 'event') {
            return '例如：秋日漫展、外景拍摄';
        }
        if (this.draft.kind === 'team') {
            return '例如：摄影小林';
        }
        if (this.draft.kind === 'expense') {
            return '例如：摄影定金';
        }
        if (this.draft.kind === 'variant') {
            return '例如：雪初音';
        }
        if (this.draft.kind === 'asset') {
            return '例如：蓝色长假发';
        }
        if (this.draft.kind === 'checklist') {
            return '例如：美瞳护理液';
        }
        if (this.draft.kind === 'category') {
            return '例如：道具制作';
        }
        if (this.draft.kind === 'preparation') {
            return '例如：试穿并确认尺寸';
        }
        return '例如：初音未来';
    }

    private references(): ReferenceImage[] {
        const project = this.state.projects.find((item: CosProject) => item.id === this.draft.parentId);
        return project ? shotReferences(this.state.references, project) : [];
    }

    build() {
        Column({ space: 12 }) {
            SheetHeader({
                title: this.draft.title(), hint: '内容只保存在本机',
                haptic: this.state.settings.haptic, hapticLevel: this.state.settings.hapticLevel,
                close: (): void => {
                    if (!this.state.busy && !this.session.submitting) {
                        this.close();
                    }
                },
            }).attributeModifier(this.entrance.group(1))
            Scroll(this.scroller) {
                Column({ space: 18 }) {
                    this.draftStatus()
                    Column({ space: 18 }) {
                        if (this.draft.kind !== 'project' && this.draft.kind !== 'reference' && this.draft.kind !== 'photo') {
                            Field({ componentId: 'form-input:name', error: this.issue('name'), area: (area: Area): void => {
                                    this.fieldArea('name', area);
                                }, focused: (): void => {
                                    this.focus('name');
                                },
                                label: this.draft.kind === 'team' ? '姓名 / 称呼 *' : this.draft.kind === 'expense' ? '花费用途 *' : this.draft.kind === 'shot' ? '拍摄事项 *' : '名称 *',
                                value: this.draft.name,
                                placeholder: this.nameHint(),
                                change: (v: string) => {
                                    this.draft.name = v;
                                }
                            })
                        }
                        if (this.draft.kind === 'character') {
                            CharacterFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'project') {
                            ProjectFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'asset') {
                            AssetFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'event') {
                            EventFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'team') {
                            TeamFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'expense') {
                            ExpenseFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'preparation') {
                            PreparationFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind === 'shot') {
                            ShotFields({ state: this.state, draft: this.draft, issues: this.issues,
                                area: (field: string, area: Area): void => {
                                    this.fieldArea(field, area);
                                },
                                focused: (field: string): void => {
                                    this.focus(field);
                                }
                            })
                        }
                        if (this.draft.kind !== 'shot' && this.draft.kind !== 'category' && this.draft.kind !== 'checklist' && (this.draft.kind !== 'project' || this.draft.advanced)) {
                            Field({ componentId: 'form-input:notes', error: this.issue('notes'), area: (area: Area): void => {
                                    this.fieldArea('notes', area);
                                }, focused: (): void => {
                                    this.focus('notes');
                                },
                                multilineLimit: this.draft.kind === 'photo' ? 20000 : 2000, label: this.draft.kind === 'photo' ? '照片说明' : this.draft.kind === 'reference' ? '图片说明' : '备注',
                                value: this.draft.notes,
                                multiline: true,
                                change: (v: string) => {
                                    this.draft.notes = v;
                                }
                            })
                        }
                    }.width('100%')
                        .alignItems(HorizontalAlign.Start)
                        .enabled(!this.session.loading && this.session.recoveryChecked && !this.session.pendingRestore && this.draft.exists(this.state))
                }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 24 })
            }.id('form-scroll')
                .layoutWeight(1)
                .width('100%')
                .align(Alignment.Top)
                .enabled(!this.state.busy && !this.session.submitting)
                .attributeModifier(this.entrance.group(2))
                .onAreaChange((_, area: Area): void => {
                    this.viewportTop = Number(area.globalPosition.y);
                    const height = Number(area.height);
                    if (this.viewportHeight && height !== this.viewportHeight && this.focusedField) {
                        this.reveal(this.focusedField);
                    }
                    this.viewportHeight = height;
                })
            if (this.formError || this.issues.length) {
                Text(this.formError || this.issues[0].message).id('form-error').fontSize(14).fontColor(Theme.danger)
                    .accessibilityText(this.formError || this.issues[0].message)
            }
            Button(this.state.busy || this.session.submitting ? '保存中…' : this.draft.kind === 'project' && !this.draft.id ? this.creationAction : '保存')
                .accessibilityText(this.state.busy || this.session.submitting ? '正在保存' : this.draft.kind === 'project' && !this.draft.id ? this.creationAction : '保存表单')
                .width('100%')
                .constraintSize({ minHeight: 52 })
                .backgroundColor(Theme.brand)
                .fontColor(Theme.onAccent)
                .enabled(!this.state.busy && !this.session.submitting && !this.session.loading && this.session.recoveryChecked && !this.session.pendingRestore && !this.state.staleScopes.length && this.draft.exists(this.state))
                .id('form-submit').onClick(() => {
                    vibration.dotVibration();
                    this.save();
                })
                .visualEffect(this.feedback.effect('button-20'))
                .compositingFilter(this.feedback.filter('button-20'))
                .attributeModifier(this.feedback.control('button-20'))
                .opacity(this.entrance.step >= 3 ? 1 : 0)
                .translate({ y: this.entrance.step >= 3 ? 0 : 20 })
        }.padding(24).height('100%').width('100%').backgroundColor(Theme.surface)
    }
}
