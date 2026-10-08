import { Character, CharacterVariant, CosEvent, CosProject, PhotoAsset, PhotoStatus, ProjectStatus, Asset } from './Entities';
import { TeamMember } from './Planning';
import { PlanReadiness } from './PlanReadiness';
import { PROJECT_STATUSES, PROJECT_LABELS } from '../common/constants';

/** Shared by the on-screen work card and the existing structured text share. */
export interface ProjectShareObject {
  schemaVersion: number; kind: string; projectId: string; characterId: string; name: string;
  character: string; work: string; variant: string; status: string;
  event: string; date: string; dateFromEvent: boolean;
  credits: string[]; finalCount: number; spentCents: number;
  reusedEquipmentCount: number; equipmentValueCents: number; coverPhotoId: string;
}
export class ProjectWork {
  value: ProjectShareObject;
  completed: boolean;
  coverPath: string = '';
  coverLabel: string = '';
  constructor(value: ProjectShareObject, completed: boolean) { this.value = value; this.completed = completed; }
}
export function buildProjectWork(project: CosProject, readiness: PlanReadiness, character?: Character, variant?: CharacterVariant, event?: CosEvent, photos: PhotoAsset[] = [], team: TeamMember[] = [], equipment: Asset[] = []): ProjectWork {
  const cover = photos.filter((photo: PhotoAsset) => photo.projectId === project.id && [PhotoStatus.FINAL, PhotoStatus.PUBLISHED].includes(photo.status) && !!photo.thumbnailPath)
    .sort((a: PhotoAsset, b: PhotoAsset) => b.createdAt - a.createdAt || a.id.localeCompare(b.id))[0];
  const credits = team.filter((member: TeamMember) => member.projectId === project.id)
    .sort((a: TeamMember, b: TeamMember) => a.role.localeCompare(b.role) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id))
    .map((member: TeamMember) => member.role + ' · ' + member.name);
  const value: ProjectShareObject = {
    schemaVersion: 2, kind: 'cos-project', projectId: project.id, characterId: project.characterId, name: project.name,
    character: character?.name || '角色已不存在', work: character?.workName || '',
    variant: project.variantId ? variant?.characterId === project.characterId && variant.id === project.variantId ? variant.name : '版本已不存在' : '未指定版本',
    status: PROJECT_LABELS[PROJECT_STATUSES.indexOf(project.status)] || '状态未知',
    event: event?.name || (project.eventId ? '活动已不存在' : '未关联活动'),
    date: readiness.date, dateFromEvent: readiness.dateFromEvent,
    credits: credits, finalCount: readiness.photos.byStage[4], spentCents: readiness.money.spentCents,
    reusedEquipmentCount: readiness.equipment.total,
    equipmentValueCents: equipment.reduce((total: number, asset: Asset) => total + asset.priceCents, 0),
    coverPhotoId: cover?.id || ''
  };
  const result = new ProjectWork(value, project.status === ProjectStatus.COMPLETED || project.status === ProjectStatus.ARCHIVED);
  result.coverPath = cover?.thumbnailPath || character?.cover || '';
  result.coverLabel = cover ? project.name + '成片封面' : character?.cover ? character.name + '角色封面（非本场成片）' : '尚无作品封面';
  return result;
}
export function workHistory(works: ProjectWork[]): ProjectWork[] {
  // No import/update timestamp pretends to be a shoot or completion date.
  return works.slice().sort((a: ProjectWork, b: ProjectWork) => b.value.date.localeCompare(a.value.date) || a.value.projectId.localeCompare(b.value.projectId));
}
export function recentWork(works: ProjectWork[], date: string): ProjectWork | undefined {
  return workHistory(works.filter((work: ProjectWork) => work.completed || work.value.finalCount > 0 && (!work.value.date || work.value.date <= date)))[0];
}
export function projectShareText(value: ProjectShareObject): string {
  return value.character + ' / ' + value.variant + ' · ' + value.name + '\n状态：' + value.status + '\n场次：' + value.event + '\n日期：' + (value.date || '日期待定') + (value.dateFromEvent ? '（来自活动）' : '') + '\n成片：' + value.finalCount + ' 张\n已记录支出：¥' + (value.spentCents / 100).toFixed(2) + '\n团队署名：' + (value.credits.join('；') || '未记录') + '\n衣柜复用：' + value.reusedEquipmentCount + ' 件（资料原值 ¥' + (value.equipmentValueCents / 100).toFixed(2) + '，未计入支出）';
}
