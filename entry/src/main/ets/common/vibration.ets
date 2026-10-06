import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEFAULT_VIBRATION_LEVEL, STORAGE_KEY_VIBRATION_LEVEL } from './constants';

const VIBRATION_LEVEL_OFF = 0;
const VIBRATION_LEVEL_SOFT = 1;
const EFFECT_SOFT = 'haptic.effect.soft';
const EFFECT_HARD = 'haptic.effect.hard';

export class vibration {
  private static lastBackVibrationAt: number = 0;
  private static hardwareSupported?: boolean;
  private static effectSupport: Map<string, boolean> = new Map();
  private static loggedFallback: boolean = false;

  /**
   * 查询本机振动器列表。空列表表示当前设备没有振动硬件。
   * getVibratorInfoSync 从 API 19 起提供，项目当前兼容 API 23。
   */
  static isSupported(): boolean {
    if (vibration.hardwareSupported !== undefined) return vibration.hardwareSupported;
    try {
      vibration.hardwareSupported = vibrator.getVibratorInfoSync().length > 0;
      return vibration.hardwareSupported;
    } catch (error) {
      const businessError = error as BusinessError;
      console.warn('[ElvaCos][common/vibration][WARN]',
        `Failed to query vibrator info. Code: ${businessError.code}, message: ${businessError.message}`,
      );
      return false;
    }
  }

  /**
   * 部分设备不支持 haptic.effect.* 预置效果。预置效果不可用时回落到时长振动，
   * 保证「有振动硬件就一定有点击/返回反馈」，而不是静默失败。
   */
  private static startTimeVibration(duration: number): void {
    if (!vibration.isSupported()) return;
    try {
      vibrator.startVibration(
        { type: 'time', duration },
        { usage: 'touch' },
        (error: BusinessError) => {
          if (error) {
            console.error('[ElvaCos][common/vibration][ERROR]',
              `Failed to start time vibration. Code: ${error.code}, message: ${error.message}`,
            );
          }
        },
      );
    } catch (error) {
      const businessError = error as BusinessError;
      console.error('[ElvaCos][common/vibration][ERROR]',
        `Failed to start time vibration. Code: ${businessError.code}, message: ${businessError.message}`,
      );
    }
  }

  private static currentEffectId(): string | undefined {
    const level = AppStorage.get<number>(STORAGE_KEY_VIBRATION_LEVEL) ?? DEFAULT_VIBRATION_LEVEL;
    if (level === VIBRATION_LEVEL_OFF) return undefined;
    return level === VIBRATION_LEVEL_SOFT ? EFFECT_SOFT : EFFECT_HARD;
  }

  private static startPresetVibrationWithEffect(effectId: string, count: number, intensity: number): void {
    let supported = vibration.effectSupport.get(effectId);
    if (supported === undefined) {
      try {
        supported = vibrator.isSupportEffectSync(effectId);
        vibration.effectSupport.set(effectId, supported);
      } catch (error) {
        const businessError = error as BusinessError;
        console.error('[ElvaCos][common/vibration][ERROR]',
          `Failed to query effect ${effectId}. Code: ${businessError.code}, message: ${businessError.message}`,
        );
        // 查询失败不能吞掉反馈：按不支持处理并回落到时长振动。
        vibration.effectSupport.set(effectId, false);
        vibration.startTimeVibration(24);
        return;
      }
      if (!supported) {
        if (!vibration.loggedFallback) {
          vibration.loggedFallback = true;
          console.warn('[ElvaCos][common/vibration][WARN]',
            `Vibration effect is unsupported: ${effectId}; falling back to timed vibration.`);
        }
        vibration.startTimeVibration(count > 1 ? 32 : 24);
        return;
      }
    } else if (!supported) {
      vibration.startTimeVibration(count > 1 ? 32 : 24);
      return;
    }
    try {
      vibrator.startVibration(
        {
          type: 'preset',
          effectId,
          count,
          intensity,
        },
        { usage: 'touch' },
        (error: BusinessError) => {
          if (error) {
            console.error('[ElvaCos][common/vibration][ERROR]',
              `Failed to start ${effectId}. Code: ${error.code}, message: ${error.message}`,
            );
          }
        },
      );
    } catch (error) {
      const businessError = error as BusinessError;
      console.error('[ElvaCos][common/vibration][ERROR]',
        `Failed to start ${effectId}. Code: ${businessError.code}, message: ${businessError.message}`,
      );
    }
  }

  private static startPresetVibration(count: number, intensity: number): void {
    const effectId = vibration.currentEffectId();
    if (effectId === undefined) return;
    vibration.startPresetVibrationWithEffect(effectId, count, intensity);
  }

  static dotVibration(): void {
    vibration.startPresetVibration(1, 50);
  }

  /**
   * 返回键、标题栏返回与系统侧滑返回可能在同一帧触发多个回调；短时间去重，
   * 保证一次返回动作只产生一次清晰的触觉反馈。
   */
  static backVibration(): void {
    const now = Date.now();
    if (now - vibration.lastBackVibrationAt < 120) return;
    vibration.lastBackVibrationAt = now;
    vibration.startPresetVibration(1, 50);
  }

  static waveVibration(): void {
    // 首次启动时拦截关闭重要提示属于强制提醒，不受用户常规触觉强度设置影响。
    vibration.startPresetVibrationWithEffect(EFFECT_HARD, 5, 100);
  }

  static errorVibration(): void {
    vibration.startPresetVibration(2, 100);
  }
}
