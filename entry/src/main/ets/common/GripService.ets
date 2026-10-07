import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { SystemCapability } from './SystemCapability';

export class GripService {
  private active: boolean = false;
  private revision: number = 0;
  private timer: number = -1;
  private listener: (status: motion.HoldingHandStatus) => void = () => { };

  async authorize(context: common.UIAbilityContext): Promise<void> {
    if (!SystemCapability.grip()) { throw new Error('此设备暂不支持智感握持，请使用左手或右手布局'); }
    const permission = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, ['ohos.permission.DETECT_GESTURE']);
    if (permission.authResults[0] !== 0) { throw new Error('未允许智感握持，已保留原设置；可选择左手或右手'); }
  }

  async start(context: common.UIAbilityContext, update: (hand: string) => void): Promise<void> {
    this.stop();
    const revision = this.revision;
    await this.authorize(context);
    // 权限对话框期间可能已离开页面；过期请求不能重新注册监听。
    if (revision !== this.revision) { return; }
    this.listener = (status: motion.HoldingHandStatus): void => {
      if (!this.active || revision !== this.revision) { return; }
      if (this.timer >= 0) { clearTimeout(this.timer); }
      this.timer = setTimeout((): void => {
        this.timer = -1;
        if (revision === this.revision && this.active) {
          update(status === motion.HoldingHandStatus.LEFT_HAND_HELD ? 'left' : status === motion.HoldingHandStatus.RIGHT_HAND_HELD ? 'right' : 'auto');
        }
      }, 650);
    };
    try { motion.on('holdingHandChanged', this.listener); }
    catch (error) { throw new Error('当前设备不支持智感握持，可选择左手或右手'); }
    this.active = true;
  }

  stop(): void {
    this.revision++;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (this.active) {
      try { motion.off('holdingHandChanged', this.listener); }
      catch (error) { console.warn('[ElvaCos][Grip] 取消握姿监听失败'); }
      this.active = false;
    }
  }
}
