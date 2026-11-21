import { Theme } from '../ui/Theme';

/** Dashboard 风格数字滚动过渡展示。 */
@ComponentV2
export struct RollingNumber {
    @Param value: number = 0;
    @Param decimals: number = 0;
    @Param prefix: string = '';
    @Param suffix: string = '';
    @Param fontSize: number = 24;
    @Param fontWeight: FontWeight = FontWeight.Bold;
    @Param color: ResourceColor = Theme.accent;
    @Param accessibilityLabel: string = '';
    @Local private displayedValue: number = 0;
    private animationToken: number = 0;
    private animationTimer: number = -1;

    @Monitor('value')
    private onValueChanged(): void {
        this.animateValue();
    }

    private animateValue(): void {
        const target = this.decimals > 0 ? Math.max(0, this.value) : Math.max(0, Math.round(this.value));
        const token = ++this.animationToken;
        if (this.animationTimer >= 0) {
            clearTimeout(this.animationTimer);
        }
        this.displayedValue = 0;
        this.animationTimer = setTimeout((): void => {
            this.animationTimer = -1;
            if (token !== this.animationToken) {
                return;
            }
            this.getUIContext().animateTo({ duration: 850, curve: Curve.EaseOut }, (): void => {
                this.displayedValue = target;
            });
        }, 60);
    }

    private formattedText(): string {
        const body = this.decimals > 0 ?
            this.displayedValue.toFixed(this.decimals) :
            String(Math.round(this.displayedValue));
        return `${this.prefix}${body}${this.suffix}`;
    }

    aboutToAppear(): void {
        this.animateValue();
    }

    aboutToDisappear(): void {
        this.animationToken++;
        if (this.animationTimer >= 0) {
            clearTimeout(this.animationTimer);
            this.animationTimer = -1;
        }
    }

    build() {
        Text(this.formattedText())
            .fontSize(this.fontSize)
            .fontWeight(this.fontWeight)
            .fontColor(this.color)
            .maxLines(1)
            .contentTransition(this.decimals === 0 && !this.prefix && !this.suffix ?
                new NumericTextTransition({
                    flipDirection: FlipDirection.DOWN,
                    enableBlur: true,
                }) : undefined)
            .accessibilityText(`${this.accessibilityLabel}${this.prefix}${this.decimals > 0 ? this.value.toFixed(this.decimals) : Math.round(this.value)}${this.suffix}`)
    }
}
