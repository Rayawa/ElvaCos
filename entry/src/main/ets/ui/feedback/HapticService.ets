import { vibration } from './vibration';
// Keep business callers stable while using Dashboard's implementation verbatim.

export class HapticService {
    private static lastBack: number = 0;

    static async confirm(enabled: boolean, level: number = 1): Promise<void> {
        if (enabled) {
            vibration.dotVibration();
        }
    }

    static back(enabled: boolean, level: number = 1): void {
        const now = Date.now();
        if (enabled && now - HapticService.lastBack > 220) {
            HapticService.lastBack = now;
            vibration.backVibration();
        }
    }
}
