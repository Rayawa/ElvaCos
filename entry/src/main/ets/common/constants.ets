import { deviceInfo } from '@kit.BasicServicesKit';
import { ProjectStatus, AssetType, AssetStatus, PhotoStatus } from '../model/Entities';
import { CategoryTemplate, TaskTemplate, ReleaseNote } from './types';

// Reused from dashboard-HarmonyOS; Preferences remain the persistent source.
export const STORAGE_KEY_VIBRATION_LEVEL = 'vibrationLevel';
export const STORAGE_KEY_LIGHT_FIELD_LEVEL = 'lightFieldLevel';
export const STORAGE_KEY_IMMERSIVE_MATERIAL_LEVEL = 'immersiveMaterialLevel';
export const STORAGE_KEY_APPEARANCE = 'appearance';
export const STORAGE_KEY_THEME_COLOR = 'themeColor';
export const STORAGE_KEY_HAND = 'hand';
export const STORAGE_KEY_ACCOUNT_OPEN_ID = 'accountOpenId';
export const STORAGE_KEY_ACCOUNT_UNION_ID = 'accountUnionId';
export const STORAGE_KEY_ACCOUNT_NAME = 'accountName';
export const STORAGE_KEY_ACCOUNT_SIGNED_AT = 'accountSignedAt';
export const DEFAULT_VIBRATION_LEVEL = 1;
export const DEFAULT_LIGHT_FIELD_LEVEL = 1;
export const DEFAULT_IMMERSIVE_MATERIAL_LEVEL = 1;
export const DEFAULT_APPEARANCE = 'system';
export const DEFAULT_THEME_COLOR = 'blue';
export const DEFAULT_HAND = 'left';
export const PAGE_TRANSITION_DURATION_MS = 300;
export const PAGE_EXIT_DURATION_MS = 220;
export const STAGGER_ENTER_DURATION_MS = 500;
export const STAGGER_ENTER_DELAY_MS = 100;
export const STAGGER_ENTER_INTERVAL_MS = 125;

export const APP_VERSION = '1.0.0-beta.1';

// 品牌名称引用资源；版本、构建号与署名集中提供。
export const APP_NAME_EN: Resource = $r('app.string.app_display_name_en');
export const APP_AUTHOR = 'Designed & Developed by Ray Chen (Rayawa)';
export const APP_COPYRIGHT = 'Copyright © 2026. All rights reserved.';
export const APP_SITE = '本应用备案域名：rayawa.top';

export const DEFAULT_BUTTON_RIGHT = false;

export const DEFAULT_HOLD_CHECK_ENABLED = false;

export const LEGACY_APP_SETTINGS_FILE_NAME = 'myAppSettings';

export const LEGACY_PROFILE_FILE_NAME = 'profile';

export const LEGACY_SETTINGS_FILE_NAME = 'settings';

export const STORAGE_FILE_NAME = 'app_storage';

export const STORAGE_KEY_BUTTON_RIGHT = 'buttonPositionRIGHT';

export const STORAGE_KEY_FIRST_LAUNCH = 'isFirstLaunch';

export const STORAGE_KEY_HOLD_CHECK = 'holdCheckON';

export const STORAGE_KEY_LEGACY_MIGRATED = 'legacy_migrated';



export const STORAGE_KEY_USERNAME = 'username';

export const LIST_ITEM_DIVIDER_HORIZONTAL_MARGIN = 16;

export const LIST_ITEM_PREFIX_MARGIN = 8;

export const LIST_ITEM_SUFFIX_MARGIN = 8;

export const APPEARANCE_LIGHT: string = 'sky';
export const APPEARANCE_DARK: string = 'mist';
export const APPEARANCE_SYSTEM: string = 'system';
export const APPEARANCE_VALUES: string[] = [APPEARANCE_LIGHT, APPEARANCE_SYSTEM, APPEARANCE_DARK];
export const APPEARANCE_LABELS: string[] = ['浅色', '跟随系统', '深色'];
export const HAND_VALUES: string[] = ['left', 'auto', 'right'];
export const HAND_LABELS: string[] = ['左手', '智感握持', '右手'];
export const PROJECT_STATUSES: ProjectStatus[] = [ProjectStatus.IDEA, ProjectStatus.PLANNING, ProjectStatus.PREPARING, ProjectStatus.READY, ProjectStatus.EVENT, ProjectStatus.SHOOTING, ProjectStatus.POST, ProjectStatus.COMPLETED, ProjectStatus.ARCHIVED];
export const PROJECT_LABELS: string[] = ['灵感', '规划中', '准备中', '已就绪', '出展中', '拍摄中', '后期中', '已完成', '已归档'];
export const ASSET_TYPES: AssetType[] = [AssetType.COSTUME, AssetType.WIG, AssetType.SHOES, AssetType.PROP, AssetType.ACCESSORY, AssetType.LENS, AssetType.MAKEUP, AssetType.OTHER];
export const ASSET_TYPE_LABELS: string[] = ['服装', '假发', '鞋', '道具', '配饰', '美瞳', '妆品', '其他'];
export const ASSET_STATUSES: AssetStatus[] = [AssetStatus.WISH, AssetStatus.ORDERED, AssetStatus.OWNED, AssetStatus.REPAIR, AssetStatus.LENT, AssetStatus.RETIRED];
export const ASSET_STATUS_LABELS: string[] = ['想买', '已下单', '可用', '待维修', '已借出', '已退役'];
export const PHOTO_STATUSES: PhotoStatus[] = [PhotoStatus.IMPORTED, PhotoStatus.RAW, PhotoStatus.SELECTED, PhotoStatus.WAITING, PhotoStatus.RETOUCHED, PhotoStatus.FINAL, PhotoStatus.PUBLISHED, PhotoStatus.ARCHIVED];
export const PHOTO_LABELS: string[] = ['已导入', '原片', '已选中', '待修图', '已精修', '最终作品', '已发布', '已归档'];
export const TEAM_ROLES: string[] = ['毛娘', '妆娘', '摄影', '后勤', '后期', '其他'];
export const EXPENSE_CATEGORIES: string[] = ['服装', '假发', '美瞳', '妆造', '摄影', '后期', '门票', '交通', '住宿', '道具', '其他'];
export const DATE_MODES: string[] = ['pending', 'single', 'multiple'];
export const DATE_MODE_LABELS: string[] = ['日期待定', '单日', '多日'];
export const TIME_MODES: string[] = ['none', 'start', 'range'];
export const TIME_MODE_LABELS: string[] = ['不标记时间', '开始时间', '时间段'];
export const EVENT_TYPES: string[] = ['漫展', '拍摄', '妆造', '聚会', '其他'];
export const PREPARATION_TEMPLATES: CategoryTemplate[] = [
  new CategoryTemplate('假发', [new TaskTemplate('wig-buy', '购买', true), new TaskTemplate('wig-receive', '收货', true), new TaskTemplate('wig-style', '造型')]),
  new CategoryTemplate('服装', [new TaskTemplate('costume-buy', '购买', true), new TaskTemplate('costume-receive', '收货', true), new TaskTemplate('costume-fit', '试穿')]),
  new CategoryTemplate('鞋子', [new TaskTemplate('shoe-buy', '购买', true), new TaskTemplate('shoe-receive', '收货', true), new TaskTemplate('shoe-fit', '试穿')]),
  new CategoryTemplate('美瞳', [new TaskTemplate('lens-buy', '购买', true), new TaskTemplate('lens-receive', '收货', true)]),
  new CategoryTemplate('化妆', [new TaskTemplate('makeup', '确认妆容')]),
  new CategoryTemplate('拍摄', [new TaskTemplate('photographer', '预约摄影')]),
  new CategoryTemplate('后期', [new TaskTemplate('retoucher', '预约后期')])
];

export const APP_BUILD_NUMBER = 10000001;
export const STORAGE_KEY_APPLICATION_STATE = 'applicationState';
export const SETTINGS_ENTRANCE_KEY = 'SettingsPage';
// 版本号连点进入开发者选项：窗口内未点满就重置，避免误触累积。
export const DEVELOPER_ENTRANCE_TAPS = 5;
export const DEVELOPER_ENTRANCE_WINDOW_MS = 1600;
export const DEVELOPER_PAGE_TITLE = '开发者选项';
export const PRIVACY_RAWFILE = 'privacy.html';
export const READING_MAX_WIDTH = 840;
export const MAIN_PAGE_TITLES: string[] = ['首页', 'Cos', '活动', '衣柜', '我的'];

export const APP_LOG: ReleaseNote[] = [{
  version: APP_VERSION,
  type: 'beta',
  buildNumber: APP_BUILD_NUMBER,
  date: '2026-10-08',
  changes: [
    '按 Dashboard 整理 ability、common、component 与 pages/main、detail、more，保留独立领域、数据库和媒体层。',
    '统一应用公共状态入口，设置沿用 Preferences 与 StorageLink，移除页面默认创建的业务状态。',
    '新增支持 Beta、RC、正式版独立筛选的更新日志和原生隐私政策阅读页；隐私正文直接读取本地 privacy.html。',
    '根据容器宽高切换布局，补齐短横屏滚动、阅读宽度和花费分类交互。',
    '启动数据加载与维护分阶段执行，取消过期握姿监听和异步界面回写，补齐中文无障碍标签。',
    '设置页与主页共享启动期入场记录，只在首次打开时播放；设置列表使用原生触摸反馈，移除叠加按压特效。',
    '提供蓝、薄荷绿、樱花粉、杏橙、珊瑚红五组浅深配色，外观独立选择浅色、跟随系统或深色。',
    '增加月度花费趋势与照片处理分布，修复照片筛选刷新、卡片留白、活动倒计时和日历按压光效。',
    '内置原神与绝区零离线示例，可在开发者选项中追加；仅调试构建首次空库自动加载，Release 构建保持空白。',
    '工程文档改为现状与参考说明，后续开发以当次任务为准。',
  ],
}];

export const SUPPORTS_HARMONY_API_23: boolean = deviceInfo.sdkApiVersion >= 23 && deviceInfo.distributionOSApiVersion >= 60100;
export const HDS_MATERIAL_TYPE_ADAPTIVE: number = 100;
export const HDS_TITLE_SIZE_SMALL: number = 0;

export const SCHEMA_VERSION = 3;
export const MIN_SPLIT_HEIGHT = 600;
export const LAYOUT_CONTENT_TOP: number = 100;
export const LAYOUT_DETAIL_TOP: number = 90;
export const LAYOUT_DETAIL_TOP_WITH_SEGMENT: number = 112;
export const LAYOUT_CONTENT_BOTTOM: number = 90;
export const LAYOUT_HOME_CONTENT_BOTTOM: number = 96;
export const LAYOUT_TOOLBAR_BOTTOM_RESERVATION: number = 96;
export const LAYOUT_SECTION_SPACING: number = 14;
export const LAYOUT_SECTION_CONTENT_GAP: number = 8;
export const LAYOUT_SECTION_TITLE_PADDING: number = 4;
export const LAYOUT_CARD_RADIUS: number = 16;
export const LAYOUT_PAGE_PADDING: number = 14;
export const LAYOUT_WIDE_BREAKPOINT: number = 840;
export const LAYOUT_CONTENT_MAX_WIDTH: number = 1440;
export const LAYOUT_WIDE_OVERVIEW_TOP: number = 80;
export const LAYOUT_WIDE_SCROLL_TOP: number = 110;
export const LAYOUT_MAIN_TABS_WIDTH: number = 250 * 5 / 4;
export const LAYOUT_TITLE_SEGMENT_WIDTH: Length = '50%';

export const STORAGE_KEY_VISUAL_EFFECTS = 'visualEffectsEnabled';
