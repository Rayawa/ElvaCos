import { Theme } from '../common/Theme';
import { vibration } from '../common/vibration';
import { validDate } from '../model/Rules';
import { validTime } from '../model/Schedule';

@ComponentV2
export struct DateField {
  @Param label: string = '';
  @Param value: string = '';
  @Param time: boolean = false;
  @Param optional: boolean = false;
  @Event change: (value: string) => void = () => {};
  private choose(): void {
    vibration.dotVibration();
    if (this.time) {
      const selected = new Date();
      if (validTime(this.value)) { selected.setHours(Number(this.value.slice(0, 2)), Number(this.value.slice(3, 5)), 0, 0); }
      this.getUIContext().showTimePickerDialog({ selected: selected, useMilitaryTime: true, onAccept: (value: TimePickerResult): void => { this.change(String(value.hour ?? 0).padStart(2, '0') + ':' + String(value.minute ?? 0).padStart(2, '0')); } });
    } else {
      this.getUIContext().showDatePickerDialog({ selected: validDate(this.value) ? new Date(this.value + 'T12:00:00') : new Date(), onDateAccept: (date: Date): void => { this.change(String(date.getFullYear()).padStart(4, '0') + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0')); } });
    }
  }
  build() {
    Column({ space: 8 }) {
      Text(this.label).fontColor(Theme.muted).fontSize(13)
      Row({ space: 8 }) {
        Button(this.value || (this.optional ? '暂不设置' : this.time ? '选择时间' : '选择日期')).layoutWeight(1).constraintSize({ minHeight: 48 }).backgroundColor(Theme.bg).fontColor(this.value ? Theme.ink : Theme.muted).onClick((): void => this.choose()).accessibilityText(this.label + '，' + (this.value || '未设置'))
        if (this.optional && this.value) { Button('清除').backgroundColor(Theme.tint).fontColor(Theme.accent).onClick((): void => { vibration.dotVibration(); this.change(''); }).accessibilityText('清除' + this.label) }
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
