import { Theme } from '../ui/Theme';
import { MediaRepository } from '../services/MediaRepository';

/** 受管媒体图片展示容器：纯粹内容面，不挂载按压光效。 */
@ComponentV2
export struct ManagedImage {
    @Param large: boolean = false;
    @Event onFailure: () => void = () => {};
    @Param sourcePath: string = '';
    @Param label: string = '照片';
    @Param failureText: string = '照片暂不可用';
    @Param fit: ImageFit = ImageFit.Cover;
    @Param ratio: number = 0.8;
    @Param radius: number = Theme.slotRadius;
    @Local loading: boolean = true;
    @Local failed: boolean = false;
    @Local loadedRatio: number = 1;

    @Monitor('sourcePath')
    private sourceChanged(): void {
        this.loading = true;
        this.failed = false;
        this.loadedRatio = 1;
    }

    private uri(): string {
        try {
            return MediaRepository.imageUri(this.sourcePath);
        } catch (error) {
            return '';
        }
    }

    build() {
        Stack() {
            if (this.sourcePath && !this.failed) {
                Image(this.uri())
                    .width('100%')
                    .height('100%')
                    .objectFit(this.fit)
                    .onComplete((event) => {
                        if (event && event.width > 0 && event.height > 0) {
                            this.loadedRatio = event.width / event.height;
                        }
                        this.loading = false;
                    })
                    .onError(() => {
                        this.loading = false;
                        this.failed = true;
                        this.onFailure();
                    })
                    .accessibilityText(this.label)
                    .accessibilityDescription(this.loading ? '照片加载中' : '照片已加载')
                if (this.loading) {
                    LoadingProgress()
                        .width(24)
                        .height(24)
                        .color(Theme.brand)
                        .accessibilityText('照片加载中')
                }
            } else {
                Text(this.failureText)
                    .fontSize(13)
                    .fontColor(Theme.muted)
                    .textAlign(TextAlign.Center)
                    .accessibilityText(this.label + '，' + this.failureText)
            }
        }.width('100%')
            .aspectRatio(this.ratio > 0 ? this.ratio : this.loadedRatio)
            .backgroundColor(Theme.tint)
            .borderRadius(this.radius)
            .clip(true)
    }
}
