import { AttributeUpdater, curves, UIContext } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';
import { uiEffect } from '@kit.ArkGraphics2D';
import { pressLightFieldFilter, pressVisualEffect } from './visualEffects';

/** 光效由节点直接绑定可观察状态；updater 负责触摸与缩放，不增加布局层。 */
@ObservedV2
class PressState { @Trace pressed: boolean = false; }

class PressModifier extends AttributeUpdater<CommonAttribute> {
  private state: PressState = new PressState();
  private pressedAt: number = 0;
  private releaseTimer: number = -1;
  private context: () => UIContext;
  private large: boolean;
  constructor(context: () => UIContext, large: boolean) { super(); this.context = context; this.large = large; }

  initializeModifier(instance: CommonAttribute): void {
    instance.scale({ x: 1, y: 1 });
    this.applyNormalAttribute(instance);
    instance.onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.clearRelease(); this.pressedAt = Date.now(); this.update(true);
      } else if (event.type === TouchType.Up) {
        this.clearRelease();
        // 与 Dashboard 一样，轻点也保留至少一个渲染提交周期的光效。
        const remaining = Math.max(0, 140 - (Date.now() - this.pressedAt));
        this.releaseTimer = setTimeout((): void => { this.releaseTimer = -1; this.update(false); }, remaining);
      } else if (event.type === TouchType.Cancel) { this.clearRelease(); this.update(false); }
    });
  }

  private clearRelease(): void { if (this.releaseTimer >= 0) { clearTimeout(this.releaseTimer); this.releaseTimer = -1; } }
  onComponentChanged(instance: CommonAttribute): void { this.clearRelease(); this.state.pressed = false; this.initializeModifier(instance); }

  applyNormalAttribute(instance: CommonAttribute): void { this.render(instance); }

  private render(instance: CommonAttribute): void {
    instance.scale({ x: this.state.pressed ? 0.985 : 1, y: this.state.pressed ? 0.985 : 1 });
  }
  effect(): VisualEffect { return pressVisualEffect(this.state.pressed, this.large ?
    hdsEffect.PointLightIlluminatedType.BORDER : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT); }
  filter(): uiEffect.Filter { return pressLightFieldFilter(this.state.pressed); }

  private update(pressed: boolean): void {
    if (this.state.pressed === pressed) { return; }
    this.state.pressed = pressed;
    const instance = this.attribute;
    if (instance) {
      // 点光源立即更新；只有几何缩放进入弹簧动画。
      this.context().animateTo({ duration: 130, curve: curves.springMotion(0.35, 0.9) }, (): void => {
        this.render(instance);
      });
    }
  }
}

/** 页面只给稳定节点 key；列表追加实体 ID，避免多行共享按压状态。 */
export class PressFeedback {
  private modifiers: Map<string, PressModifier> = new Map<string, PressModifier>();
  private context: () => UIContext;
  constructor(context: () => UIContext) { this.context = context; }
  control(key: string, large: boolean = false): PressModifier {
    let modifier = this.modifiers.get(key);
    if (!modifier) { modifier = new PressModifier(this.context, large); this.modifiers.set(key, modifier); }
    return modifier;
  }
  effect(key: string, large: boolean = false): VisualEffect { return this.control(key, large).effect(); }
  filter(key: string, large: boolean = false): uiEffect.Filter { return this.control(key, large).filter(); }
}
