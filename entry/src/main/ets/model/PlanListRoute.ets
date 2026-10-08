import { Character, CosProject, ProjectStatus } from './Entities';
import { PlanReadiness } from './PlanReadiness';
import { dateGroup } from './TaskQueue';

/** List state is runtime navigation context; it is never a business field. */
@ObservedV2
export class PlanListRoute {
  @Trace section: number = 0;
  @Trace query: string = '';
  @Trace status: string = '';
  @Trace dateRange: string = 'all';
  offsets: number[] = [0, 0, 0];
}

export function filterPlanList(projects: CosProject[], plans: PlanReadiness[], characters: Character[], route: PlanListRoute, today: string): CosProject[] {
  const query = route.query.trim().toLocaleLowerCase();
  return projects.filter((project: CosProject): boolean => {
    const active = project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED;
    if (route.section === 0 && !active || route.section === 1 && project.status !== ProjectStatus.COMPLETED) { return false; }
    if (route.status && project.status !== route.status) { return false; }
    const character = characters.find((item: Character) => item.id === project.characterId);
    if (query && !(project.name + ' ' + (character?.name || '')).toLocaleLowerCase().includes(query)) { return false; }
    const date = plans.find((plan: PlanReadiness) => plan.id === project.id)?.date || '';
    if (route.dateRange === 'undated') { return !date; }
    if (route.dateRange === 'future') { return !!date && date >= today; }
    if (route.dateRange !== 'all') { return dateGroup(date, today) === route.dateRange; }
    return true;
  });
}
