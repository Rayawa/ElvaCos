import { UIContext } from '@kit.ArkUI';

export async function confirm(context: UIContext, title: string, message: string, action: string): Promise<boolean> {
  try {
    const result = await context.getPromptAction().showDialog({ title: title, message: message, buttons: [{ text: '取消', color: $r('app.color.diff_content') }, { text: action, color: $r('app.color.v3_accent_red') }] });
    return result.index === 1;
  } catch (error) { return false; }
}
