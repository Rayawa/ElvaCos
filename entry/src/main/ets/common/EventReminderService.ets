import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CosEvent } from '../model/Entities';
import { reminderTime, eventDateLabel, eventTimeLabel } from '../model/Schedule';

// API 9 publish/cancel; API 12 getAllValidReminders; notification request API 10, settings API 13.
// Only publish() requests notification permission, after an explicit form opt-in.
export class EventReminderService {
  async publish(event: CosEvent, context: common.UIAbilityContext): Promise<number> {
    if (!canIUse('SystemCapability.Notification.ReminderAgent')) { throw new Error('此设备不支持活动提醒，活动已保存'); }
    const when = reminderTime(event);
    if (!when || when <= Date.now()) { throw new Error('提醒时间已过去，活动已保存，请调整日期或提前时间'); }
    await notificationManager.requestEnableNotification(context);
    const time = new Date(when);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: { year: time.getFullYear(), month: time.getMonth() + 1, day: time.getDate(), hour: time.getHours(), minute: time.getMinutes(), second: 0 },
      title: event.name,
      content: eventDateLabel(event) + ' · ' + eventTimeLabel(event) + (event.venue ? ' · ' + event.venue : ''),
      expiredContent: '活动提醒已结束',
      ringDuration: 0, snoozeTimes: 0,
      actionButton: [{ title: '关闭', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }],
      wantAgent: { pkgName: context.abilityInfo.bundleName, abilityName: 'EntryAbility', parameters: { eventId: event.id } }
    };
    return reminderAgentManager.publishReminder(request);
  }
  async settings(context: common.UIAbilityContext): Promise<void> {
    if (!canIUse('SystemCapability.Notification.NotificationSettings')) { throw new Error('此设备不支持通知设置入口，请在系统设置中管理通知'); }
    await notificationManager.openNotificationSettings(context);
  }
  async cancel(id: number): Promise<void> {
    if (id < 0 || !canIUse('SystemCapability.Notification.ReminderAgent')) { return; }
    try { await reminderAgentManager.cancelReminder(id); }
    catch (error) { if ((error as BusinessError).code !== 1700003) { throw error as Error; } }
  }
  async reconcile(events: CosEvent[]): Promise<void> {
    if (!canIUse('SystemCapability.Notification.ReminderAgent')) { return; }
    const reminders = await reminderAgentManager.getAllValidReminders();
    const ids = events.map((e: CosEvent) => e.reminderId);
    for (const reminder of reminders) { if (!ids.includes(reminder.reminderId)) { await this.cancel(reminder.reminderId); } }
  }
  static same(a: CosEvent, b: CosEvent): boolean {
    return a.reminderId >= 0 && a.name === b.name && a.date === b.date && a.dateMode === b.dateMode && a.endDate === b.endDate && a.timeMode === b.timeMode && a.startTime === b.startTime && a.endTime === b.endTime && a.venue === b.venue && a.reminderMinutes === b.reminderMinutes;
  }
  static failure(error: Error): string {
    const code = (error as BusinessError).code;
    return code === 201 || code === 1700001 || code === 1600004 ? '活动已保存，提醒未开启。请在活动详情的「通知设置」开启通知，再编辑活动选择提醒。' : code === 1700002 ? '活动已保存，系统提醒数量已满，提醒未开启。' : code ? '活动已保存，系统提醒未开启，请检查通知设置后重试。' : error.message;
  }
}
