import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { ProjectWork, ProjectShareObject, projectShareText } from '../model/ProjectWork';
import { SystemCapability } from './SystemCapability';
export { ProjectShareObject } from '../model/ProjectWork';

export class ShareService {
  static object(work: ProjectWork): ProjectShareObject { return work.value; }
  static async project(context: common.UIAbilityContext, value: ProjectShareObject): Promise<void> {
    if (!SystemCapability.share()) { throw new Error('此设备暂不支持系统分享'); }
    const data = new systemShare.SharedData({ utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, title: value.name, content: projectShareText(value), extraData: { objectType: value.kind, schemaVersion: value.schemaVersion, payload: JSON.stringify(value) } });
    await new systemShare.ShareController(data).show(context, { previewMode: systemShare.SharePreviewMode.DETAIL });
  }
}
