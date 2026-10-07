import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { CategoryTemplate, TaskTemplate, PREPARATION_TEMPLATES, preparationKeys } from '../model/Preparation';

@ComponentV2
export struct PreparationTemplatePicker {
  @Param keys: string[] = [];
  @Param mode: number = 1;
  @Event change: (keys: string[], mode: number) => void = () => {};
  build() {
    Column({ space: 12 }) {
      Select([{ value: '空白计划' }, { value: '常用准备模板' }, { value: '复用装备 · 不生成购买任务' }])
        .value(['空白计划', '常用准备模板', '复用装备 · 不生成购买任务'][this.mode])
        .onSelect((index: number): void => { vibration.dotVibration(); this.change(preparationKeys(index), index); }).accessibilityText('准备模板')
      Text('按这次需要选择任务，创建后可修改名称、日期和分类。').fontSize(12).fontColor(Theme.muted)
      if (this.mode !== 0) {
        ForEach(PREPARATION_TEMPLATES, (category: CategoryTemplate) => {
          Column({ space: 6 }) {
            Text(category.name).fontSize(14).fontColor(Theme.ink)
            ForEach(category.tasks.filter((task: TaskTemplate) => this.mode === 1 || !task.purchase), (task: TaskTemplate) => {
              Row({ space: 8 }) {
                Checkbox({ name: task.key }).select(this.keys.includes(task.key)).selectedColor(Theme.accent)
                  .onChange((checked: boolean): void => {
                    vibration.dotVibration();
                    this.change(checked ? this.keys.filter((key: string) => key !== task.key).concat(task.key) : this.keys.filter((key: string) => key !== task.key), this.mode);
                  }).accessibilityText(category.name + ' · ' + task.label)
                Text(task.label).fontColor(Theme.ink).fontSize(14).layoutWeight(1)
              }.width('100%')
            }, (task: TaskTemplate) => task.key)
          }.alignItems(HorizontalAlign.Start).padding(12).width('100%').backgroundColor(Theme.bg).borderRadius(14)
        }, (category: CategoryTemplate) => category.name)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
