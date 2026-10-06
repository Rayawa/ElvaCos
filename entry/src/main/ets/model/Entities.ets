import { util } from '@kit.ArkTS';

export enum ProjectStatus { IDEA = 'Idea', PLANNING = 'Planning', PREPARING = 'Preparing', READY = 'Ready', EVENT = 'Event', SHOOTING = 'Shooting', POST = 'PostProduction', COMPLETED = 'Completed', ARCHIVED = 'Archived' }
export enum AssetType { COSTUME = 'Costume', WIG = 'Wig', SHOES = 'Shoes', PROP = 'Prop', ACCESSORY = 'Accessory', LENS = 'ContactLens', MAKEUP = 'Makeup', OTHER = 'Other' }
export enum AssetStatus { WISH = 'Wish', ORDERED = 'Ordered', OWNED = 'Owned', REPAIR = 'Repair', LENT = 'Lent', RETIRED = 'Retired' }
export enum PhotoStatus { IMPORTED = 'Imported', RAW = 'Raw', SELECTED = 'Selected', WAITING = 'WaitingForRetouch', RETOUCHED = 'Retouched', FINAL = 'Final', PUBLISHED = 'Published', ARCHIVED = 'Archived' }
export const PROJECT_STATUSES: ProjectStatus[] = [ProjectStatus.IDEA, ProjectStatus.PLANNING, ProjectStatus.PREPARING, ProjectStatus.READY, ProjectStatus.EVENT, ProjectStatus.SHOOTING, ProjectStatus.POST, ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED];
export const PROJECT_LABELS: string[] = ['灵感', '规划中', '准备中', '已就绪', '出展中', '拍摄中', '后期中', '已完成', '已归档'];
export const ASSET_TYPES: AssetType[] = [AssetType.COSTUME, AssetType.WIG, AssetType.SHOES, AssetType.PROP, AssetType.ACCESSORY, AssetType.LENS, AssetType.MAKEUP, AssetType.OTHER];
export const ASSET_TYPE_LABELS: string[] = ['服装', '假发', '鞋', '道具', '配饰', '美瞳', '妆品', '其他'];
export const ASSET_STATUSES: AssetStatus[] = [AssetStatus.WISH, AssetStatus.ORDERED, AssetStatus.OWNED, AssetStatus.REPAIR, AssetStatus.LENT, AssetStatus.RETIRED];
export const ASSET_STATUS_LABELS: string[] = ['想买', '已下单', '可用', '待维修', '已借出', '已退役'];
export const PHOTO_STATUSES: PhotoStatus[] = [PhotoStatus.IMPORTED, PhotoStatus.RAW, PhotoStatus.SELECTED, PhotoStatus.WAITING, PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED];
export const PHOTO_LABELS: string[] = ['已导入', '原片', '已选中', '待修图', '已精修', '最终作品', '已发布', '已归档'];
export function newId(): string { return util.generateRandomUUID(true); }
export class Character { id: string = newId(); name: string = ''; workName: string = ''; description: string = ''; cover: string = ''; favorite: boolean = false; status: string = 'Wishlist'; createdAt: number = Date.now(); updatedAt: number = Date.now(); }
export class CharacterVariant { id: string = newId(); characterId: string = ''; name: string = ''; notes: string = ''; }
export class CosProject { id: string = newId(); characterId: string = ''; variantId: string = ''; eventId: string = ''; name: string = ''; status: ProjectStatus = ProjectStatus.PREPARING; notes: string = ''; targetDate: string = ''; budgetCents: number = 0; createdAt: number = Date.now(); updatedAt: number = Date.now(); }
export class Asset { id: string = newId(); name: string = ''; type: AssetType = AssetType.COSTUME; status: AssetStatus = AssetStatus.OWNED; location: string = ''; brand: string = ''; size: string = ''; priceCents: number = 0; purchaseUrl: string = ''; notes: string = ''; createdAt: number = Date.now(); }
export class ProjectAsset { projectId: string = ''; assetId: string = ''; }
export class CosEvent { id: string = newId(); name: string = ''; date: string = ''; city: string = ''; venue: string = ''; url: string = ''; status: string = 'Planned'; ticketPurchased: boolean = false; notes: string = ''; createdAt: number = Date.now(); }
export class ChecklistItem { id: string = newId(); projectId: string = ''; assetId: string = ''; label: string = ''; done: boolean = false; sortOrder: number = 0; }
export class PhotoAsset { id: string = newId(); projectId: string = ''; sourceUri: string = ''; localPath: string = ''; thumbnailPath: string = ''; status: PhotoStatus = PhotoStatus.IMPORTED; caption: string = ''; createdAt: number = Date.now(); }
export class PhotoVersion { id: string = newId(); photoId: string = ''; name: string = 'Original'; recipe: string = '{}'; renderedPath: string = ''; createdAt: number = Date.now(); }
export class DiaryEntry { id: string = newId(); projectId: string = ''; text: string = ''; createdAt: number = Date.now(); }
export class AppSettings { username: string = ''; hapticLevel: number = 1; lightFieldLevel: number = 1; materialLevel: number = 1; haptic: boolean = true; effects: boolean = true; hand: string = 'left'; grip: boolean = false; /** sky=浅色，mist=深色，system=跟随系统 */ appearance: string = 'system'; }
/** 华为账号登录态；未登录时 signedIn 为 false，其余字段为空。 */
export class HuaweiAccount { signedIn: boolean = false; openId: string = ''; unionId: string = ''; displayName: string = ''; signedAt: number = 0; }
export interface ProjectProgress { ready: number; total: number; percent: number; }
