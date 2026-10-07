import { AppStorageV2 } from '@kit.ArkUI';
import { AppState } from '../model/ApplicationState';
import { STORAGE_KEY_APPLICATION_STATE } from './constants';

/** Dashboard 的公共存储边界；V2 业务对象由 AppStorageV2 观察，偏好仍由 storage / StorageLink 管理。 */
export function getApplicationState(): AppState {
  const state = AppStorageV2.connect(AppState, STORAGE_KEY_APPLICATION_STATE, (): AppState => new AppState());
  if (!state) { throw new Error('应用状态初始化失败'); }
  return state;
}

export function setReminderTarget(id: string): void {
  getApplicationState().pendingEventId = id;
}
