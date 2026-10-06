import { UIContext } from '@kit.ArkUI';
import { Theme } from './Theme';
import { vibration } from './vibration';

/** 统一确认弹窗：取消为强调色，确认动作为危险色；两个按钮都给出点击反馈。 */
export async function confirm(context: UIContext, title: string, message: string, action: string): Promise<boolean> {
  try {
    const result = await context.getPromptAction().showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: Theme.accent },
        { text: action, color: Theme.danger },
      ],
    });
    vibration.dotVibration();
    return result.index === 1;
  } catch (error) { return false; }
}
