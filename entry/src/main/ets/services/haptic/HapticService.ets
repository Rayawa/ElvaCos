import { vibration } from '../../common/vibration';

// Keep business callers stable while using Dashboard's implementation verbatim.
export class HapticService {
  static async confirm(enabled: boolean, level: number = 1): Promise<void> {
    if (enabled) { vibration.dotVibration(); }
  }
  static back(enabled: boolean, level: number = 1): void {
    if (enabled) { vibration.backVibration(); }
  }
}
