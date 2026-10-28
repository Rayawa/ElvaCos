import { DetailLink } from '../../components/common/DetailLink';
import { Icons } from '../../ui/icons/Icons';
import { displayName } from '../../utils/format/format';
import { photoStatusLabel } from '../../domain/photos/PhotoStages';
import { PHOTO_LABELS, PHOTO_STATUSES } from '../../config/constants';
import { PressFeedback } from '../../ui/feedback/pressFeedback';
import { StaggerEntrance, pageTransition } from '../../ui/animation/motion';
import { ManagedImage } from '../../components/common/ManagedImage';
import { vibration } from '../../ui/feedback/vibration';
import { AppState } from '../../state/ApplicationState';
import { Theme } from '../../ui/theme/Theme';
import { PhotoAsset } from '../../models/Entities';

@ComponentV2
export struct PhotoDetail {
    private feedback: PressFeedback = new PressFeedback(() => this.getUIContext());
    @Require @Param state: AppState;
    @Param photo: PhotoAsset = new PhotoAsset();
    @Event open: (kind: string, id: string) => void = () => {};
    @Event edit: (kind: string, id: string, parent: string) => void = () => {};
    @Event remove: (kind: string, id: string) => void = () => {};
    @Local loadError: boolean = false;
    @Local repairError: string = '';
    @Local checking: boolean = true;
    @Local original: string = 'unreadable';
    @Local thumbnail: string = 'unreadable';
    private checkVersion: number = 0;

    private async checkMedia(): Promise<void> {
        const version = ++this.checkVersion;
        this.checking = true;
        const files = await this.state.inspectPhoto(this.photo);
        if (version !== this.checkVersion) {
            return;
        }
        this.original = files.original;
        this.thumbnail = files.thumbnail;
        this.loadError = false;
        this.checking = false;
    }

    private async repair(thumbnailOnly: boolean = false): Promise<void> {
        this.repairError = '';
        const saved = await this.state.repairPhoto(this.photo.id, thumbnailOnly);
        if (!saved && this.state.error) {
            this.repairError = this.state.error;
        }
        await this.checkMedia();
    }

    private missingTitle(): string {
        if (this.loadError) {
            return '原图加载失败';
        }
        if (this.original === 'unlinked') {
            return '媒体待恢复';
        }
        return this.original === 'missing' ? '本机原图缺失' : '原图暂时无法读取';
    }

    private missingMessage(): string {
        if (this.loadError) {
            return '原图路径已找到，但图片未能加载。可重新检查，或为这张记录重新选择原图。';
        }
        if (this.original === 'unlinked') {
            return '这张记录没有本机原图路径，元数据恢复不包含照片文件。计划、状态与说明仍保留。';
        }
        return '照片记录仍保留。重新选择对应的原图，只补回这张记录的媒体。';
    }

    @Param entrance: StaggerEntrance = new StaggerEntrance();
    aboutToAppear(): void {
        void this.checkMedia();
        if (!this.entrance.managed) {
            this.entrance.play(this.getUIContext());
        }
    }

    aboutToDisappear(): void {
        this.feedback.dispose();
        this.checkVersion++;
        if (!this.entrance.managed) {
            this.entrance.reset();
        }
    }

    @Monitor('photo')
    photoChanged(): void {
        void this.checkMedia();
    }

    build() {
        Scroll() {
            Column({ space: Theme.sectionSpacing }) {
                Blank().height(Theme.detailTop).width('100%')
                Column({ space: 12 }) {
                    if (this.checking) {
                        LoadingProgress().width(32).height(32).color(Theme.brand).accessibilityText('正在检查本机照片文件')
                    } else if (this.original === 'available' && !this.loadError) {
                        ManagedImage({
                            large: true, sourcePath: this.photo.localPath,
                            label: this.state.projectName(this.photo.projectId) + '的照片',
                            fit: ImageFit.Contain, ratio: 0, radius: 20, failureText: '原图加载失败',
                            onFailure: (): void => {
                                this.loadError = true;
                            }
                        }).width('100%').constraintSize({ maxHeight: 640 })
                    } else {
                        Text(this.missingTitle()).fontSize(18).fontColor(Theme.ink)
                        Text(this.missingMessage()).fontSize(14).fontColor(Theme.muted)
                        Button('为这张记录补回原图').constraintSize({ minHeight: 48 }).width('100%')
                            .enabled(!this.state.busy && !this.state.staleScopes.length).onClick((): void => {
                                void this.repair();
                            })
                        Button('重新检查原图').constraintSize({ minHeight: 48 }).onClick((): void => {
                            void this.checkMedia();
                        })
                    }
                    if (!this.checking && this.original === 'available') {
                        if (this.thumbnail !== 'available') {
                            Text(this.thumbnail === 'unlinked' ? '尚未建立缩略图，原图仍可查看。' : this.thumbnail === 'missing' ? '缩略图文件缺失，原图仍可查看。' : '缩略图暂时无法读取，原图仍可查看。')
                                .fontSize(14)
                                .fontColor(Theme.muted)
                        }
                        DetailLink({ title: this.thumbnail === 'available' ? '重建缩略图' : '从原图重建缩略图', icon: Icons.importPhoto, interactive: !this.state.busy && !this.state.staleScopes.length,
                            action: (): void => {
                                void this.repair(true);
                            }
                        })
                    }
                }
                    .width('100%').alignItems(HorizontalAlign.Start).opacity(this.entrance.step >= 1 ? 1 : 0).translate({ y: this.entrance.step >= 1 ? 0 : 20 })
                Column({ space: Theme.sectionSpacing }) {
                    if (this.repairError || this.state.error) {
                        Text(this.repairError || this.state.error).fontSize(14).fontColor(Theme.danger)
                    }
                    Column() {
                        DetailLink({ title: '照片说明', subtitle: this.photo.caption || '尚未填写，点击补充', icon: Icons.edit, interactive: !this.state.busy && !this.state.staleScopes.length,
                            action: (): void => {
                                this.edit('photo', this.photo.id, this.photo.projectId);
                            }
                        })
                        Divider().color(Theme.line)
                        Row({ space: 12 }) {
                            Text('照片状态').fontSize(16).fontColor(Theme.ink).layoutWeight(1)
                            Select(PHOTO_LABELS.map((label: string): SelectOption => {
                                return { value: label };
                            }))
                                .value(photoStatusLabel(this.photo.status))
                                .constraintSize({ minHeight: 48 })
                                .enabled(!this.state.busy && !this.state.staleScopes.length)
                                .onSelect((index: number): void => {
                                    vibration.dotVibration();
                                    this.state.setPhotoStatus(this.photo, PHOTO_STATUSES[index]);
                                }).accessibilityText('照片业务状态')
                        }.width('100%').padding({ top: 8, bottom: 8 })
                        Divider().color(Theme.line)
                        DetailLink({ title: displayName(this.state.projectName(this.photo.projectId)), subtitle: '所属计划', icon: Icons.plan, action: (): void => {
                                this.open('project', this.photo.projectId);
                            }
                        })
                    }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
                }
                    .width('100%').alignItems(HorizontalAlign.Start).opacity(this.entrance.step >= 2 ? 1 : 0).translate({ y: this.entrance.step >= 2 ? 0 : 20 })
                Blank().height(Theme.detailBottom).width('100%')
            }
                .constraintSize({ maxWidth: Theme.readingMaxWidth })
                .width('100%')
                .padding({ left: Theme.pagePadding, right: Theme.pagePadding })
                .alignItems(HorizontalAlign.Start)
        }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top).transition(pageTransition())
    }
}
