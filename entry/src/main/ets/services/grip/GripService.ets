import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { SystemCapability } from '../capability/SystemCapability';

export class GripService {
  private active: boolean = false;
  private timer: number = -1;
  private listener: (status: motion.HoldingHandStatus) => void = () => {};
  async start(context: common.UIAbilityContext, update: (hand: string) => void): Promise<void> {
    this.stop();
    if (!SystemCapability.grip()) { throw new Error('此设备暂不支持智感握持，请使用左手或右手布局'); }
    const permission = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, ['ohos.permission.DETECT_GESTURE']);
    if (permission.authResults[0] !== 0) { throw new Error('未允许智感握持，已保留原设置；可选择左手或右手'); }
    this.listener = (status: motion.HoldingHandStatus) => {
      if (this.timer >= 0) { clearTimeout(this.timer); }
      this.timer = setTimeout(() => {
        update(status === motion.HoldingHandStatus.LEFT_HAND_HELD ? 'left' : status === motion.HoldingHandStatus.RIGHT_HAND_HELD ? 'right' : 'auto');
        this.timer = -1;
      }, 650);
    };
    try { motion.on('holdingHandChanged', this.listener); } catch (error) { throw new Error('当前设备不支持智感握持，可选择左手或右手'); }
    this.active = true;
  }
  stop(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (this.active) { try { motion.off('holdingHandChanged', this.listener); } catch (error) {} this.active = false; }
  }
}
