import { today } from '../../utils/format/format';
import { DATE_MODES, DATE_MODE_LABELS, EVENT_TYPES, TIME_MODES, TIME_MODE_LABELS } from '../../config/constants';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { DateField } from './DateField';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { vibration } from '../../ui/feedback/vibration';
import { EditDraft, FormIssue } from '../../state/forms/EditDraft';
import { Field } from '../common/Surfaces';

@ComponentV2
export struct EventFields {
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Param issues: FormIssue[] = [];
    @Event area: (field: string, area: Area) => void = () => {};
    @Event focused: (field: string) => void = () => {};
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    @Builder fieldIssue(field: string) {
        if (this.issue(field)) {
            Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field))
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
    }

    build() {
        Column({ space: Theme.fieldSpacing }) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                Column({ space: 8 }) {
                    Text('活动类型').fontSize(13).fontColor(Theme.muted)
                    Select(EVENT_TYPES.map((type: string): SelectOption => {
                        return { value: type };
                    }))
                        .value(this.draft.type)
                        .onSelect((i: number): void => {
                            vibration.dotVibration();
                            this.draft.type = EVENT_TYPES[i];
                        })
                        .accessibilityText('活动类型')
                        .visualEffect(this.feedback.effect('select-9'))
                        .compositingFilter(this.feedback.filter('select-9'))
                        .attributeModifier(this.feedback.control('select-9'))
                        .id('form-input:type').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                            this.area('type', area);
                        })
                    this.fieldIssue('type')
                }.width('48%').constraintSize({ minWidth: 140 }).alignItems(HorizontalAlign.Start)
                Column({ space: 8 }) {
                    Text('日期安排').fontSize(13).fontColor(Theme.muted)
                    Select(DATE_MODE_LABELS.map((label: string): SelectOption => {
                        return { value: label };
                    }))
                        .value(DATE_MODE_LABELS[DATE_MODES.indexOf(this.draft.dateMode)])
                        .onSelect((i: number): void => {
                            vibration.dotVibration();
                            this.draft.dateMode = DATE_MODES[i];
                            if (i === 0) {
                                this.draft.date = '';
                                this.draft.endDate = '';
                                this.draft.timeMode = 'none';
                                this.draft.startTime = '';
                                this.draft.endTime = '';
                                this.draft.reminderMinutes = -1;
                                this.draft.deviceCalendar = false;
                            } else {
                                if (!this.draft.date) {
                                    this.draft.date = today();
                                }
                                this.draft.endDate = i === 2 ? this.draft.endDate || this.draft.date : '';
                            }
                        })
                        .accessibilityText('活动日期模式')
                        .visualEffect(this.feedback.effect('select-10'))
                        .compositingFilter(this.feedback.filter('select-10'))
                        .attributeModifier(this.feedback.control('select-10'))
                        .id('form-input:dateMode').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                            this.area('dateMode', area);
                        })
                    this.fieldIssue('dateMode')
                }.width('48%').constraintSize({ minWidth: 140 }).alignItems(HorizontalAlign.Start)
            }.width('100%')
            if (this.draft.dateMode !== 'pending') {
                DateField({ componentId: 'form-input:date', error: this.issue('date'), area: (area: Area): void => {
                        this.area('date', area);
                    }, label: this.draft.dateMode === 'multiple' ? '开始日期 *' : '日期 *',
                    value: this.draft.date,
                    change: (v: string): void => {
                        this.draft.date = v;
                    }
                })
                if (this.draft.dateMode === 'multiple') {
                    DateField({ componentId: 'form-input:endDate', error: this.issue('endDate'), area: (area: Area): void => {
                            this.area('endDate', area);
                        }, label: '结束日期 *',
                        value: this.draft.endDate,
                        change: (v: string): void => {
                            this.draft.endDate = v;
                        }
                    })
                }
                Text('时间安排').fontSize(13).fontColor(Theme.muted)
                Select(TIME_MODE_LABELS.map((label: string): SelectOption => {
                    return { value: label };
                }))
                    .value(TIME_MODE_LABELS[TIME_MODES.indexOf(this.draft.timeMode)])
                    .onSelect((i: number): void => {
                        vibration.dotVibration();
                        this.draft.timeMode = TIME_MODES[i];
                        if (i === 0) {
                            this.draft.startTime = '';
                            this.draft.endTime = '';
                        } else {
                            this.draft.startTime = this.draft.startTime || '09:00';
                            this.draft.endTime = i === 2 ? this.draft.endTime || '18:00' : '';
                        }
                    })
                    .accessibilityText('活动时间模式')
                    .visualEffect(this.feedback.effect('select-11'))
                    .compositingFilter(this.feedback.filter('select-11'))
                    .attributeModifier(this.feedback.control('select-11'))
                    .id('form-input:timeMode').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                        this.area('timeMode', area);
                    })
                this.fieldIssue('timeMode')
                if (this.draft.timeMode !== 'none') {
                    DateField({ componentId: 'form-input:startTime', error: this.issue('startTime'), area: (area: Area): void => {
                            this.area('startTime', area);
                        }, label: '开始时间 *',
                        value: this.draft.startTime,
                        time: true,
                        change: (v: string): void => {
                            this.draft.startTime = v;
                        }
                    })
                }
                if (this.draft.timeMode === 'range') {
                    DateField({ componentId: 'form-input:endTime', error: this.issue('endTime'), area: (area: Area): void => {
                            this.area('endTime', area);
                        }, label: '结束时间 *',
                        value: this.draft.endTime,
                        time: true,
                        change: (v: string): void => {
                            this.draft.endTime = v;
                        }
                    })
                }
                Row() {
                    Text('同时添加到设备日历').fontColor(Theme.ink).layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.draft.deviceCalendar })
                        .onChange((value: boolean): void => {
                            vibration.dotVibration();
                            this.draft.deviceCalendar = value;
                        })
                        .id('event-device-calendar')
                        .accessibilityText('保存后打开设备日历确认页')
                        .visualEffect(this.feedback.effect('toggle-12'))
                        .compositingFilter(this.feedback.filter('toggle-12'))
                        .attributeModifier(this.feedback.control('toggle-12'))
                }.width('100%')
                if (this.draft.deviceCalendar) {
                    Text('保存活动后打开系统确认页；日历提醒默认提前 30 分钟，可修改。取消不影响应用内记录。').fontSize(12).fontColor(Theme.muted)
                }
                Text('应用内提醒').fontSize(13).fontColor(Theme.muted)
                Select([{ value: '不提醒' }, { value: '开始时' }, { value: '提前 30 分钟' }, { value: '提前 1 小时' }, { value: '提前 1 天' }])
                    .value(['不提醒', '开始时', '提前 30 分钟', '提前 1 小时', '提前 1 天'][[-1, 0, 30, 60, 1440].indexOf(this.draft.reminderMinutes)])
                    .onSelect((i: number): void => {
                        vibration.dotVibration();
                        this.draft.reminderMinutes = [-1, 0, 30, 60, 1440][i];
                    })
                    .accessibilityText('活动提醒')
                    .visualEffect(this.feedback.effect('select-13'))
                    .compositingFilter(this.feedback.filter('select-13'))
                    .attributeModifier(this.feedback.control('select-13'))
                    .id('form-input:reminderMinutes').constraintSize({ minHeight: 48 }).onAreaChange((_, area: Area): void => {
                        this.area('reminderMinutes', area);
                    })
                this.fieldIssue('reminderMinutes')
                if (this.draft.reminderMinutes >= 0) {
                    Text('保存时申请通知授权；未标记时间的活动按当天 09:00 提醒。').fontSize(12).fontColor(Theme.muted)
                }
            }
            Field({ componentId: 'form-input:city', error: this.issue('city'), area: (area: Area): void => {
                    this.area('city', area);
                }, focused: (): void => {
                    this.focused('city');
                }, label: '城市', value: this.draft.city, change: (v: string) => {
                    this.draft.city = v;
                }
            })
            Field({ componentId: 'form-input:venue', error: this.issue('venue'), area: (area: Area): void => {
                    this.area('venue', area);
                }, focused: (): void => {
                    this.focused('venue');
                }, label: '场馆', value: this.draft.venue, change: (v: string) => {
                    this.draft.venue = v;
                }
            })
            Field({ componentId: 'form-input:url', error: this.issue('url'), area: (area: Area): void => {
                    this.area('url', area);
                }, focused: (): void => {
                    this.focused('url');
                },
                label: '官方 / 售票链接',
                value: this.draft.url,
                placeholder: 'https://',
                change: (v: string) => {
                    this.draft.url = v;
                }
            })
            Text('参与状态').fontSize(13).fontColor(Theme.muted)
            Select([{ value: '想去' }, { value: '计划参加' }, { value: '已参加' }])
                .value(this.draft.status === 'Wishlist' ? '想去' : this.draft.status === 'Attended' ? '已参加' : '计划参加')
                .onSelect((i: number) => {
                    vibration.dotVibration();
                    this.draft.status = ['Wishlist','Planned','Attended'][i];
                })
                .accessibilityText('活动参与状态')
                .visualEffect(this.feedback.effect('select-14'))
                .compositingFilter(this.feedback.filter('select-14'))
                .attributeModifier(this.feedback.control('select-14'))
            Row() {
                Text('已购票')
                    .fontColor(Theme.ink)
                    .layoutWeight(1);
                Toggle({ type: ToggleType.Switch, isOn: this.draft.ticket })
                    .onChange((v: boolean) => {
                        vibration.dotVibration();
                        this.draft.ticket = v;
                    })
                    .accessibilityText('已购票')
                    .visualEffect(this.feedback.effect('toggle-15'))
                    .compositingFilter(this.feedback.filter('toggle-15'))
                    .attributeModifier(this.feedback.control('toggle-15'))
            }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
