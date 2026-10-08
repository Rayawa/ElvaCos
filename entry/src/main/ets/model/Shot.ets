import { newId, CosProject } from './Entities';
import { ReferenceImage } from './Planning';

export class ProjectShot {
  id: string = newId();
  projectId: string = '';
  title: string = '';
  done: boolean = false;
  referenceId: string = '';
  sortOrder: number = 0;
  createdAt: number = Date.now();
}
export class ShotReadiness {
  items: ProjectShot[] = [];
  done: number = 0;
  get total(): number { return this.items.length; }
}
export function buildShotReadiness(shots: ProjectShot[], projectId: string): ShotReadiness {
  const result = new ShotReadiness();
  result.items = shots.filter((shot: ProjectShot) => shot.projectId === projectId).sort((a: ProjectShot, b: ProjectShot) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
  result.done = result.items.filter((shot: ProjectShot) => shot.done).length;
  return result;
}
export function shotReferences(references: ReferenceImage[], project: CosProject): ReferenceImage[] {
  return references.filter((reference: ReferenceImage) => reference.projectId === project.id || reference.characterId === project.characterId);
}
