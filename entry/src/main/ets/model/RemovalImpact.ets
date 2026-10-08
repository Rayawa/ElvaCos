import { SearchData } from './GlobalSearch';
import { ChecklistItem, DiaryEntry, ProjectAsset, ProjectStatus } from './Entities';
import { PreparationCategory, PreparationTask } from './Preparation';
import { Expense, ReferenceImage, TeamMember } from './Planning';
import { ProjectShot } from './Shot';

export interface RemovalData extends SearchData {
  checklist: ChecklistItem[];
  diary: DiaryEntry[];
  links: ProjectAsset[];
  preparationCategories: PreparationCategory[];
  preparationTasks: PreparationTask[];
  expenses: Expense[];
  references: ReferenceImage[];
  team: TeamMember[];
  shots: ProjectShot[];
}
export class RemovalImpact {
  title: string;
  detail: string;
  constructor(name: string, detail: string) { this.title = '删除「' + name + '」？'; this.detail = detail; }
}
// Confirmation counts describe the actual cascade/reassignment, never a fictional recycle bin.
export function removalImpact(data: RemovalData, kind: string, id: string): RemovalImpact | undefined {
  const entries = data.entries.filter((entry) => entry.scopeKind === kind && entry.scopeId === id).length;
  const unfile = entries + ' 条所属收录回到未归位。';
  if (kind === 'project') {
    const project = data.projects.find((item) => item.id === id); if (!project) { return undefined; }
    const photos = data.photos.filter((item) => item.projectId === id).length;
    const refs = data.references.filter((item) => item.projectId === id).length;
    const tasks = data.preparationTasks.filter((item) => item.projectId === id).length;
    const packing = data.checklist.filter((item) => item.projectId === id).length;
    const shots = data.shots.filter((item) => item.projectId === id).length;
    const expenses = data.expenses.filter((item) => item.projectId === id).length;
    const team = data.team.filter((item) => item.projectId === id).length;
    const diary = data.diary.filter((item) => item.projectId === id).length;
    const links = data.links.filter((item) => item.projectId === id).length;
    const archive = project.status === ProjectStatus.COMPLETED ? '若需保留照片与履历，请取消并选择「归档计划」。\n' : '';
    return new RemovalImpact(project.name, archive + '永久删除此计划及照片 ' + photos + ' 张、参考图 ' + refs + ' 张、准备任务 ' + tasks + ' 项、打包项 ' + packing + ' 项、拍摄事项 ' + shots + ' 项、花费 ' + expenses + ' 笔、团队分工 ' + team + ' 条、计划记录 ' + diary + ' 条。\n解除 ' + links + ' 条装备关联，衣柜装备保留；' + unfile + '\n上述照片与参考图的应用内副本将删除，系统相册原图保留。');
  }
  if (kind === 'character') {
    const character = data.characters.find((item) => item.id === id); if (!character) { return undefined; }
    const plans = data.projects.filter((item) => item.characterId === id).length;
    const variants = data.variants.filter((item) => item.characterId === id).length;
    const refs = data.references.filter((item) => item.characterId === id).length;
    return new RemovalImpact(character.name, plans ? '仍有关联计划 ' + plans + ' 份，无法删除。请先处理计划关联。' : '永久删除此角色及 ' + variants + ' 个版本、' + refs + ' 张参考图和应用内参考图副本；' + unfile + '系统相册原图保留。');
  }
  if (kind === 'event') {
    const event = data.events.find((item) => item.id === id); if (!event) { return undefined; }
    const plans = data.projects.filter((item) => item.eventId === id).length;
    return new RemovalImpact(event.name, '永久删除此活动；' + plans + ' 份关联计划保留并解除活动关联，来自活动的日期将不再提供。' + unfile + '应用内提醒将取消。');
  }
  if (kind === 'variant') {
    const variant = data.variants.find((item) => item.id === id); if (!variant) { return undefined; }
    const plans = data.projects.filter((item) => item.variantId === id).length;
    return new RemovalImpact(variant.name, plans ? '仍有 ' + plans + ' 份计划使用此版本，无法删除。请先在计划中取消版本关联。' : '永久删除此角色版本，所属角色保留。');
  }
  if (kind === 'category') {
    const category = data.preparationCategories.find((item) => item.id === id); if (!category) { return undefined; }
    return new RemovalImpact(category.name, '永久删除此准备分类及 ' + data.preparationTasks.filter((item) => item.categoryId === id).length + ' 项准备任务；装备和打包清单保留。');
  }
  if (kind === 'preparation') { const item = data.preparationTasks.find((task) => task.id === id); return item ? new RemovalImpact(item.label, '永久删除此准备任务，打包清单保留。') : undefined; }
  if (kind === 'checklist') { const item = data.checklist.find((row) => row.id === id); return item ? new RemovalImpact(item.label, '永久删除此打包项，装备与准备任务保留。') : undefined; }
  if (kind === 'team') { const item = data.team.find((row) => row.id === id); return item ? new RemovalImpact(item.name, '永久删除此成员在本计划的分工记录，其他计划的记录保留。') : undefined; }
  if (kind === 'expense') { const item = data.expenses.find((row) => row.id === id); return item ? new RemovalImpact(item.name, '永久删除这笔 ¥' + (item.amountCents / 100).toFixed(2) + ' 的花费，并从统计移除。') : undefined; }
  if (kind === 'reference') {
    const item = data.references.find((row) => row.id === id); if (!item) { return undefined; }
    const shots = data.shots.filter((row) => row.referenceId === id).length;
    return new RemovalImpact(item.caption || '参考图', '永久删除此参考图记录与应用内副本；' + shots + ' 项拍摄事项保留并清除参考图关联。使用此图的角色封面将清除。系统相册原图保留。');
  }
  if (kind === 'photo') {
    const item = data.photos.find((row) => row.id === id); if (!item) { return undefined; }
    const plan = data.projects.find((row) => row.id === item.projectId);
    return new RemovalImpact(item.caption || (plan?.name || '本计划') + '的照片', '永久删除此照片记录与应用内副本，使用此图的角色封面将清除；所属计划与系统相册原图保留。');
  }
  return undefined;
}
