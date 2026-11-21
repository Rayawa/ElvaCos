import { ReferenceImage } from '../models/Planning';
import { shotReferences } from '../models/Shot';
import { CosProject } from '../models/Entities';
import { AppState } from '../viewmodels/ApplicationState';
import { Theme } from '../ui/Theme';
import { vibration } from '../ui/vibration';
import { EditDraft, FormIssue } from '../viewmodels/EditDraft';

@ComponentV2
export struct ShotFields {
    @Require @Param state: AppState;
    @Require @Param draft: EditDraft;
    @Param issues: FormIssue[] = [];
    @Event area: (field: string, area: Area) => void = () => {};
    @Event focused: (field: string) => void = () => {};

    private issue(field: string): string {
        return this.issues.find((issue: FormIssue) => issue.field === field)?.message || '';
    }

    @Builder fieldIssue(field: string) {
        if (this.issue(field)) {
            Text(this.issue(field)).fontSize(14).fontColor(Theme.danger).accessibilityText(this.issue(field))
        }
    }

    private references(): ReferenceImage[] {
        const project = this.state.projects.find((item: CosProject) => item.id === this.draft.parentId);
        return project ? shotReferences(this.state.references, project) : [];
    }

    build() {
        Column({ space: Theme.fieldSpacing }) {
            Text('参考图（可选）').fontSize(13).fontColor(Theme.muted)
            Select(new Array<SelectOption>({ value: '不关联参考图' }).concat(this.references().map((reference: ReferenceImage): SelectOption => {
                return { value: (reference.caption || '参考图') + (reference.projectId ? '（此计划）' : '（此角色）') };
            })))
                .value(this.draft.referenceId ? (this.references().find((reference: ReferenceImage) => reference.id === this.draft.referenceId)?.caption || (this.references().some((reference: ReferenceImage) => reference.id === this.draft.referenceId) ? '参考图' : '参考图已不存在，请重新选择')) : '不关联参考图')
                .width('100%')
                .constraintSize({ minHeight: Theme.controlHeight })
                .backgroundColor(Theme.tint)
                .borderRadius(12)
                .border({ width: 1, color: Theme.line })
                .font({ size: 15, weight: FontWeight.Medium })
                .fontColor(Theme.ink)
                .id('form-input:referenceId')
                .accessibilityText('拍摄参考图')
                .onSelect((index: number): void => {
                    vibration.dotVibration();
                    this.draft.referenceId = index === 0 ? '' : this.references()[index - 1].id;
                })
                .onAreaChange((_, area: Area): void => {
                    this.area('referenceId', area);
                })
            this.fieldIssue('referenceId')
            Text('拍摄勾选独立于准备任务、装包与照片处理状态。').fontSize(14).fontColor(Theme.muted)
        }.width('100%').alignItems(HorizontalAlign.Start)
    }
}
