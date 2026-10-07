import { AttributeUpdater, curves, UIContext } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';
import { pressLightFieldFilter, pressVisualEffect } from './visualEffects';

/** 每个实际节点独享 updater；不增加布局层，也不接管点击、输入和滑动。 */
class PressModifier extends AttributeUpdater<CommonAttribute> {
  private pressed: boolean = false;
  private context: () => UIContext;
  private large: boolean;
  constructor(context: () => UIContext, large: boolean) { super(); this.context = context; this.large = large; }

  initializeModifier(instance: CommonAttribute): void {
    this.applyNormalAttribute(instance);
    instance.onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.update(true); }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.update(false); }
    });
  }

  onComponentChanged(instance: CommonAttribute): void { this.pressed = false; this.initializeModifier(instance); }

  applyNormalAttribute(instance: CommonAttribute): void { this.render(instance); }

  private render(instance: CommonAttribute): void {
    instance.visualEffect(pressVisualEffect(this.pressed, this.large ?
      hdsEffect.PointLightIlluminatedType.BORDER : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT))
      .compositingFilter(pressLightFieldFilter(this.pressed))
      .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 });
  }

  private update(pressed: boolean): void {
    if (this.pressed === pressed) { return; }
    this.pressed = pressed;
    const instance = this.attribute;
    if (instance) {
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
}
