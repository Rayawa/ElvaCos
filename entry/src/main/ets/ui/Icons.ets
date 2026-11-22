import { SymbolGlyphModifier } from '@kit.ArkUI';
import { Theme } from './Theme';
/**
* 图标集中定义。
*
* - 设置页 HdsListItemCard 的图标一律使用 app.media 里的浅/深两版 PNG，
*   与 Dashboard 的 MyPage / SettingsPanel 用法一致（user / vibrate / immersive / light /
*   trash / tutorial / privacy / right / cloud / export / load）。
* - 导航、标题菜单与详情动作栏继续使用系统符号，跟随系统色调。
*/

export class Icons {
    static tabHome: Resource = $r('sys.symbol.house');
    static tabPlan: Resource = $r('sys.symbol.square_and_pencil');
    static tabEvent: Resource = $r('sys.symbol.calendar');
    static tabLibrary: Resource = $r('sys.symbol.archivebox');
    static tabPhoto: Resource = $r('sys.symbol.picture');
    static tabProfile: Resource = $r('sys.symbol.person');
    static tabSettings: Resource = $r('sys.symbol.gearshape');
    static tabCheck: Resource = $r('sys.symbol.checkmark');
    static tabHelp: Resource = $r('sys.symbol.questionmark_circle');

    static tabBar(icon: Resource, label: string, id: string = ''): BottomTabBarStyle {
        const style = new BottomTabBarStyle({
            normal: new SymbolGlyphModifier(icon).fontColor([Theme.muted]),
            selected: new SymbolGlyphModifier(icon).fontColor([Theme.accent]),
        }, label).labelStyle({ selectedColor: Theme.accent, unselectedColor: Theme.muted });
        return id ? style.id(id) : style;
    }

    // 一级导航与标题菜单（统一使用系统矢量符号）
    static home: Resource = $r('sys.symbol.house');
    static plan: Resource = $r('sys.symbol.square_and_pencil');
    static location: Resource = $r('sys.symbol.local');
    static event: Resource = $r('sys.symbol.calendar');
    static library: Resource = $r('sys.symbol.archivebox');
    static profile: Resource = $r('sys.symbol.person_2');
    static settings: Resource = $r('sys.symbol.gearshape');
    static search: Resource = $r('sys.symbol.magnifyingglass');
    static wallet: Resource = $r('sys.symbol.wallet');
    static creditcard: Resource = $r('sys.symbol.creditcard');
    static folder: Resource = $r('sys.symbol.folder');
    static link: Resource = $r('sys.symbol.link');
    static note: Resource = $r('sys.symbol.doc_plaintext');
    static bell: Resource = $r('sys.symbol.bell');
    static clock: Resource = $r('sys.symbol.clock');
    static list: Resource = $r('sys.symbol.list_bullet');
    static alert: Resource = $r('sys.symbol.exclamationmark_triangle');
    static camera: Resource = $r('sys.symbol.camera');
    static bookmark: Resource = $r('sys.symbol.bookmark');
    static star: Resource = $r('sys.symbol.star');
    static starFill: Resource = $r('sys.symbol.star_fill');
    static chevronLeftSymbol: Resource = $r('sys.symbol.chevron_left');
    static chevronRightSymbol: Resource = $r('sys.symbol.chevron_right');
    // 设置页列表项图标（app.media，浅/深各一版）
    static user: Resource = $r('app.media.user');
    static vibration: Resource = $r('app.media.vibrate');
    static material: Resource = $r('app.media.immersive');
    static light: Resource = $r('app.media.light');
    static trash: Resource = $r('app.media.trash');
    static help: Resource = $r('app.media.question');
    static tutorial: Resource = $r('app.media.tutorial');
    static appLog: Resource = $r('app.media.app_log');
    static privacy: Resource = $r('app.media.privacy');
    static cloud: Resource = $r('app.media.cloud');
    static exportData: Resource = $r('app.media.export');
    static restoreData: Resource = $r('app.media.load');
    static theme: Resource = $r('app.media.theme');
    static hand: Resource = $r('app.media.hand');
    static chevronRight: Resource = $r('app.media.right');
    // 更新日志发布类型，复用 Dashboard 的开启/关闭图标与浅深色资源。
    static beta: Resource = $r('app.media.beta');
    static betaOn: Resource = $r('app.media.betaON');
    static rc: Resource = $r('app.media.rc');
    static rcOn: Resource = $r('app.media.rcON');
    static release: Resource = $r('app.media.release');
    static releaseOn: Resource = $r('app.media.releaseON');
    // 详情与表单动作（统一使用系统矢量符号）
    static add: Resource = $r('sys.symbol.plus');
    static edit: Resource = $r('sys.symbol.square_and_pencil');
    static share: Resource = $r('sys.symbol.share');
    static check: Resource = $r('sys.symbol.checkmark');
    static selectCircle: Resource = $r('sys.symbol.checkmark_circle');
    static closeCircle: Resource = $r('sys.symbol.xmark_circle');
    static done: Resource = $r('sys.symbol.checkmark_circle_fill');
    static pending: Resource = $r('sys.symbol.circle');
    static remove: Resource = $r('sys.symbol.trash');
    static close: Resource = $r('sys.symbol.xmark');
    static importPhoto: Resource = $r('sys.symbol.picture');
    static ai: Resource = $r('sys.symbol.wand_and_stars');

    static assetTypeSymbol(type: string): Resource {
        if (type === 'Costume') {
            return $r('sys.symbol.bag');
        }
        if (type === 'Wig') {
            return $r('sys.symbol.person');
        }
        if (type === 'Shoes') {
            return $r('sys.symbol.shoe');
        }
        if (type === 'Prop') {
            return $r('sys.symbol.wrench_and_screwdriver');
        }
        if (type === 'Accessory') {
            return $r('sys.symbol.star');
        }
        if (type === 'ContactLens') {
            return $r('sys.symbol.eyedropper');
        }
        if (type === 'Makeup') {
            return $r('sys.symbol.paintpalette');
        }
        return $r('sys.symbol.archivebox');
    }

    static entryKindSymbol(kind: string): Resource {
        if (kind === 'link') {
            return $r('sys.symbol.link');
        }
        if (kind === 'ticket') {
            return $r('sys.symbol.creditcard');
        }
        if (kind === 'map') {
            return $r('sys.symbol.map');
        }
        if (kind === 'idea') {
            return $r('sys.symbol.bookmark');
        }
        if (kind === 'image') {
            return $r('sys.symbol.picture');
        }
        return $r('sys.symbol.doc_plaintext');
    }

    static toolbarAdd(): SymbolGlyphModifier {
        return new SymbolGlyphModifier($r('sys.symbol.plus')).fontColor([$r('sys.color.icon_primary')]);
    }

    static toolbarCover(): SymbolGlyphModifier {
        return new SymbolGlyphModifier($r('sys.symbol.picture')).fontColor([$r('sys.color.icon_primary')]);
    }
}
