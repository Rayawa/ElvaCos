import { ProjectShot, ShotReadiness, buildShotReadiness } from '../../models/Shot';
import { Asset, AssetStatus, ChecklistItem, CosEvent, CosProject, PhotoAsset, ProjectAsset, ProjectStatus } from '../../models/Entities';
import { PreparationTask } from '../../models/Preparation';
import { Expense } from '../../models/Planning';
import { planDate } from './Rules';
import { photoStageCounts } from '../photos/PhotoStages';

export class PreparationReadiness {
    items: PreparationTask[] = [];
    done: number = 0;
    total: number = 0;
    waiting: number = 0;
    overdue: PreparationTask[] = [];
    today: PreparationTask[] = [];
    upcoming: PreparationTask[] = [];
    undated: PreparationTask[] = [];
    waitingItems: PreparationTask[] = [];
    pending: PreparationTask[] = [];
    next?: PreparationTask;
    percent: number = 0;
    categories: PreparationCategoryReadiness[] = [];
}

export class PreparationCategoryReadiness {
    id: string = '';
    done: number = 0;
    total: number = 0;
}

export class PackingReadiness {
    packed: number = 0;
    total: number = 0;
    pending: ChecklistItem[] = [];
    percent: number = 0;
}

export class EquipmentReadiness {
    available: number = 0;
    total: number = 0;
    unavailable: Asset[] = [];
    waiting: Asset[] = [];
    percent: number = 0;
}

export class MoneyReadiness {
    spentCents: number = 0;
    budgetCents: number = 0;
    budgetConfigured?: boolean;
}

export class PhotoReadiness {
    byStage: number[] = [0, 0, 0, 0, 0, 0];

    get total(): number {
        return this.byStage.reduce((sum: number, count: number) => sum + count, 0);
    }
}

export class ReadinessHint {
    label: string;
    text: string;

    constructor(label: string, text: string) {
        this.label = label;
        this.text = text;
    }
}

export class PlanReadiness {
    id: string = '';
    date: string = '';
    dateFromEvent: boolean = false;
    active: boolean = true;
    prep: PreparationReadiness = new PreparationReadiness();
    pack: PackingReadiness = new PackingReadiness();
    equipment: EquipmentReadiness = new EquipmentReadiness();
    shots: ShotReadiness = new ShotReadiness();
    photos: PhotoReadiness = new PhotoReadiness();
    money: MoneyReadiness = new MoneyReadiness();
    hint?: ReadinessHint;
}

export function isWaiting(task: PreparationTask): boolean {
    return !task.done && Boolean(task.waitingOn || task.waitingUntil);
}

export function budgetLabel(configured: boolean | undefined, cents: number): string {
    return configured === true ? '预算 ¥' + (cents / 100).toFixed(2) : configured === false ? '未设置预算' : '历史预算未明确';
}

export function buildPlanReadiness(project: CosProject, tasks: PreparationTask[], checklist: ChecklistItem[], assets: Asset[], links: ProjectAsset[], photos: PhotoAsset[], expenses: Expense[], events: CosEvent[], date: string, shots: ProjectShot[] = []): PlanReadiness {
    const result = new PlanReadiness();
    result.id = project.id;
    result.date = planDate(project, events);
    result.dateFromEvent = !project.targetDate && Boolean(result.date);
    result.active = project.status !== ProjectStatus.COMPLETED && project.status !== ProjectStatus.ARCHIVED;
    const week = new Date(date + 'T12:00:00');
    week.setDate(week.getDate() + 7);
    const weekEnd = String(week.getFullYear()) + '-' + String(week.getMonth() + 1)
        .padStart(2, '0') + '-' + String(week.getDate())
        .padStart(2, '0');
    const preparation = tasks.filter((task: PreparationTask) => task.projectId === project.id);
    result.prep.items = preparation;
    result.prep.total = preparation.length;
    result.prep.done = preparation.filter((task: PreparationTask) => task.done).length;
    const categories = new Map<string, PreparationCategoryReadiness>();
    for (const task of preparation) {
        let category = categories.get(task.categoryId);
        if (!category) {
            category = new PreparationCategoryReadiness();
            category.id = task.categoryId;
            categories.set(task.categoryId, category);
            result.prep.categories.push(category);
        }
        category.total++;
        if (task.done) {
            category.done++;
        }
    }
    result.prep.waitingItems = preparation.filter(isWaiting);
    result.prep.waiting = result.prep.waitingItems.length;
    result.prep.pending = preparation.filter((task: PreparationTask) => !task.done && !isWaiting(task))
        .sort((a: PreparationTask, b: PreparationTask) => (a.dueDate || '9999').localeCompare(b.dueDate || '9999') || a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
    result.prep.next = result.prep.pending[0];
    if (result.active) {
        result.prep.overdue = result.prep.pending.filter((task: PreparationTask) => Boolean(task.dueDate) && task.dueDate < date);
        result.prep.today = result.prep.pending.filter((task: PreparationTask) => task.dueDate === date);
        result.prep.upcoming = result.prep.pending.filter((task: PreparationTask) => task.dueDate > date && task.dueDate <= weekEnd);
        result.prep.undated = result.prep.pending.filter((task: PreparationTask) => !task.dueDate);
    }
    result.prep.percent = result.prep.total ? Math.round(result.prep.done * 100 / result.prep.total) : 0;
    const packing = checklist.filter((item: ChecklistItem) => item.projectId === project.id);
    result.pack.total = packing.length;
    result.pack.packed = packing.filter((item: ChecklistItem) => item.done).length;
    result.pack.pending = packing.filter((item: ChecklistItem) => !item.done)
        .sort((a: ChecklistItem, b: ChecklistItem) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
    result.pack.percent = result.pack.total ? Math.round(result.pack.packed * 100 / result.pack.total) : 0;
    const ids = new Set<string>(links.filter((link: ProjectAsset) => link.projectId === project.id).map((link: ProjectAsset) => link.assetId));
    const equipment = assets.filter((asset: Asset) => ids.has(asset.id));
    result.equipment.total = equipment.length;
    result.equipment.unavailable = equipment.filter((asset: Asset) => asset.status !== AssetStatus.OWNED);
    result.equipment.waiting = equipment.filter((asset: Asset) => [AssetStatus.ORDERED, AssetStatus.REPAIR, AssetStatus.LENT].includes(asset.status));
    result.equipment.available = equipment.length - result.equipment.unavailable.length;
    result.equipment.percent = equipment.length ? Math.round(result.equipment.available * 100 / equipment.length) : 0;
    result.shots = buildShotReadiness(shots, project.id);
    result.photos.byStage = photoStageCounts(photos.filter((photo: PhotoAsset) => photo.projectId === project.id));
    result.money.spentCents = expenses.filter((expense: Expense) => expense.projectId === project.id)
        .reduce((sum: number, expense: Expense) => sum + expense.amountCents, 0);
    result.money.budgetCents = project.budgetCents;
    result.money.budgetConfigured = project.budgetConfigured;
    if (result.prep.waitingItems.length) {
        result.hint = new ReadinessHint('在途', result.prep.waitingItems[0].label);
    } else if (result.equipment.unavailable.length) {
        result.hint = new ReadinessHint('装备不可用', result.equipment.unavailable[0].name);
    } else if (!result.date) {
        result.hint = new ReadinessHint('日程', '日期待定');
    } else if (result.prep.next) {
        result.hint = new ReadinessHint('下一项', result.prep.next.label);
    }
    return result;
}
