import abilityTest from './Ability.test';
import preparationTest from './Preparation.test';
import planningTest from './Planning.test';
import planningRulesTest from '../../../test/PlanningRules.test';

export default function testsuite() {
  abilityTest();
  preparationTest();
  planningRulesTest();
  planningTest();
}
