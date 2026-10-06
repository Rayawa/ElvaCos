import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { CosProject, Character, CosEvent, PROJECT_LABELS, PROJECT_STATUSES } from '../../model/Entities';
import { SystemCapability } from '../capability/SystemCapability';

export interface ProjectShareObject { schemaVersion: number; kind: string; name: string; character: string; work: string; status: string; event: string; date: string; }
export class ShareService {
  static object(project: CosProject, character?: Character, event?: CosEvent): ProjectShareObject {
    return { schemaVersion: 1, kind: 'cos-project', name: project.name, character: character?.name || '', work: character?.workName || '', status: PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)], event: event?.name || '', date: project.targetDate || event?.date || '' };
  }
  static async project(context: common.UIAbilityContext, value: ProjectShareObject): Promise<void> {
    if (!SystemCapability.share()) { throw new Error('此设备暂不支持系统分享'); }
    const data = new systemShare.SharedData({ utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, title: value.name, content: `${value.character} · ${value.name}\n状态：${value.status}\n${value.event}\n${value.date}`, extraData: { objectType: value.kind, schemaVersion: value.schemaVersion, payload: JSON.stringify(value) } });
    await new systemShare.ShareController(data).show(context, { previewMode: systemShare.SharePreviewMode.DETAIL });
  }
}
