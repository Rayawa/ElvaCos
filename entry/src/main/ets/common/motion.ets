import { curves, UIContext } from '@kit.ArkUI';
import {
  PAGE_EXIT_DURATION_MS,
  PAGE_TRANSITION_DURATION_MS,
  STAGGER_ENTER_DELAY_MS,
  STAGGER_ENTER_DURATION_MS,
  STAGGER_ENTER_INTERVAL_MS,
} from './constants';

export function pageTransition(): TransitionEffect {
  return TransitionEffect.asymmetric(
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: 16 }))
      .combine(TransitionEffect.scale({ x: 0.992, y: 0.992 }))
      .animation({ duration: PAGE_TRANSITION_DURATION_MS, curve: curves.springMotion(0.45, 0.94) }),
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: 10 }))
      .combine(TransitionEffect.scale({ x: 0.992, y: 0.992 }))
      .animation({ duration: PAGE_EXIT_DURATION_MS, curve: Curve.EaseInOut }),
  );
}

/**
 * 使用单一 animStep 驱动任意数量的分组入场，替代为每一组声明状态和定时器。
 */
export function startStaggerEnterAnimation(
  context: UIContext,
  stepCount: number,
  updateStep: (step: number) => void,
): number[] {
  const timers: number[] = [];
  for (let step = 1; step <= stepCount; step++) {
    const targetStep = step;
    timers.push(setTimeout((): void => {
      context.animateTo({
        duration: STAGGER_ENTER_DURATION_MS,
        curve: curves.springMotion(0.35, 0.75),
      }, (): void => updateStep(targetStep));
    }, STAGGER_ENTER_DELAY_MS + (step - 1) * STAGGER_ENTER_INTERVAL_MS));
  }
  return timers;
}

export function cancelStaggerEnterAnimation(timers: number[]): void {
  for (const timer of timers) {
    clearTimeout(timer);
  }
}

/** 由导航显示 / Sheet 打开生命周期驱动，缓存页面也会重新开始。 */
@ObservedV2
export class StaggerEntrance {
  @Trace step: number = 0;
  managed: boolean = false;
  private timers: number[] = [];
  group(step: number): EntranceGroupModifier { return new EntranceGroupModifier(this.step >= step); }
  reset(): void { cancelStaggerEnterAnimation(this.timers); this.timers = []; this.step = 0; }
  play(context: UIContext, groups: number = 4): void {
    this.reset();
    this.timers = startStaggerEnterAnimation(context, groups, (step: number): void => { this.step = step; });
  }
  finish(groups: number): void { cancelStaggerEnterAnimation(this.timers); this.timers = []; this.step = groups; }
}

/** 与 Dashboard 的生命周期相同；Tab 内容重建也不会重复首屏动画。 */
export class MainEntranceSession {
  private played: Set<string> = new Set<string>();
  claim(page: string): boolean {
    if (this.played.has(page)) { return false; }
    this.played.add(page); return true;
  }
}

export class EntranceGroupModifier implements AttributeModifier<CommonAttribute> {
  private visible: boolean;
  constructor(visible: boolean) { this.visible = visible; }
  applyNormalAttribute(instance: CommonAttribute): void {
    instance.opacity(this.visible ? 1 : 0).translate({ y: this.visible ? 0 : 20 });
  }
}
