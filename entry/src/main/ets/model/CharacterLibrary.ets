import { Character, CharacterVariant } from './Entities';
import { ProjectWork } from './ProjectWork';
import { PlanListRoute } from './PlanListRoute';

export class CharacterSummary {
  id: string = '';
  variants: string[] = [];
  planCount: number = 0;
}
export function buildCharacterSummaries(characters: Character[], variants: CharacterVariant[], works: ProjectWork[]): CharacterSummary[] {
  return characters.map((character: Character) => {
    const result = new CharacterSummary(); result.id = character.id;
    result.variants = variants.filter((variant: CharacterVariant) => variant.characterId === character.id).map((variant: CharacterVariant) => variant.name);
    result.planCount = works.filter((work: ProjectWork) => work.value.characterId === character.id).length;
    return result;
  });
}
export function filterCharacters(characters: Character[], route: PlanListRoute): Character[] {
  const query = route.query.trim().toLocaleLowerCase();
  return characters.filter((character: Character) => (!route.favoriteOnly || character.favorite) && (!query || (character.name + ' ' + character.workName).toLocaleLowerCase().includes(query)));
}
