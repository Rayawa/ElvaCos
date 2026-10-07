import structureTest from './Structure.test';
import abilityTest from './Ability.test';
import preparationTest from './Preparation.test';
import planningTest from './Planning.test';
import planningRulesTest from '../../../test/PlanningRules.test';

export default function testsuite() {
  structureTest();
  abilityTest();
  preparationTest();
  planningRulesTest();
  planningTest();
}
