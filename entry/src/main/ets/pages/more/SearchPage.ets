import { displayName } from '../../common/format';
import { ContextRow } from '../../component/ContextRow';
import { AppState } from '../../model/ApplicationState';
import { SearchRoute, SearchHit, SearchSummary, globalSearch, searchRows, SEARCH_SECTIONS, SEARCH_RESOURCE_KINDS, SEARCH_RESOURCE_LABELS } from '../../model/GlobalSearch';
import { DashboardSearch } from '../../component/DashboardSearch';
import { EmptyState } from '../../component/Surfaces';
import { Theme } from '../../common/Theme';
import { scrollByAxis } from '../../common/scroll';

@ComponentV2
export struct SearchPage {
  @Require @Param state: AppState;
  @Require @Param route: SearchRoute;
  @Event open: (hit: SearchHit) => void = () => {};
  @Event library: () => void = () => {};
  private scroller: Scroller = new Scroller();
  private restoreTimer: number = -1;
  private measured: boolean = false;
  private restoring: boolean = true;
  @Computed get summary(): SearchSummary { return globalSearch(this.state, this.route.query); }
  @Computed get rows(): SearchHit[] { return searchRows(this.summary, this.route); }
  aboutToAppear(): void { this.route.reconcile(this.rows); this.restoreOffset(); }
  aboutToDisappear(): void { if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); this.restoreTimer = -1; } }
  @Monitor('route.restoreVersion')
  restoreChanged(): void { this.route.reconcile(this.rows); this.restoreOffset(); }
  @Monitor('rows')
  resultsChanged(): void { this.route.reconcile(this.rows); }
  private restoreOffset(): void {
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoring = true; if (!this.measured) { return; }
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1; this.scroller.scrollTo({ xOffset: 0, yOffset: this.route.offsets[this.route.section], animation: false }); this.restoring = false;
    }, 0);
  }
  build() {
    List({ space: 12, scroller: this.scroller }) {
      ListItem() {
        Column({ space: 12 }) {
          Blank().height(Theme.detailTop).width('100%')
          DashboardSearch({ value: this.route.query, placeholder: '输入名称、说明或地点', label: '全局搜索关键词', componentId: 'global-search-input', changed: (value: string): void => { this.route.setQuery(value); } })
          if (this.route.section === 3) {
            Select(SEARCH_RESOURCE_LABELS.map((value: string): SelectOption => { return { value: value }; }))
              .id('search-resource-filter').value(SEARCH_RESOURCE_LABELS[SEARCH_RESOURCE_KINDS.indexOf(this.route.resourceKind)]).constraintSize({ minHeight: 48 })
              .onSelect((index: number): void => { this.route.setResourceKind(SEARCH_RESOURCE_KINDS[index]); }).accessibilityText('搜索资源类型')
          }
          ContextRow({ label: SEARCH_SECTIONS[this.route.section], text: this.rows.length + ' 条结果' }).id('search-result-count')
          if (this.route.section === 1 || !this.route.query.trim()) { Button('打开角色库').id('search-role-library').width('100%').constraintSize({ minHeight: 48 }).backgroundColor(Theme.tint).fontColor(Theme.accent).onClick(this.library) }
          if (this.route.feedback) { Text(this.route.feedback).fontSize(16).fontColor(Theme.accent) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      ForEach(this.rows, (hit: SearchHit) => {
        ListItem() {
          Button() {
            Column({ space: 8 }) {
              Text(displayName(hit.title)).fontSize(18).fontColor(Theme.ink).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              ContextRow({ label: hit.label, text: displayName(hit.detail) })
            }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
          }.id('search-result:' + hit.key()).width('100%').constraintSize({ minHeight: 64 }).type(ButtonType.Normal).backgroundColor(Theme.surface).borderRadius(Theme.cardRadius)
            .onClick((): void => { this.route.anchorKey = hit.key(); this.open(hit); }).accessibilityText('打开' + hit.title + '，' + hit.detail)
        }
      }, (hit: SearchHit) => hit.key())
      if (!this.rows.length) {
        ListItem() {
          if (this.route.query.trim()) { EmptyState({ title: '当前范围没有匹配结果', message: '可切换标题分段、调整关键词或清除搜索。', button: '清除搜索', action: (): void => { this.route.setQuery(''); } }) }
          else { Text('查找计划、角色与版本、活动、装备、照片说明或收录；参考图在所属计划或角色的参考区查看。').fontSize(16).fontColor(Theme.muted) }
        }
      }
      ListItem() { Column() { Blank().height(Theme.contentBottom).width('100%') }.width('100%') }
    }.id('search-results').width('100%').height('100%').constraintSize({ maxWidth: Theme.contentMaxWidth }).padding({ left: Theme.pagePadding, right: Theme.pagePadding }).scrollBar(BarState.Off)
      .onAreaChange((_old: Area, area: Area): void => { if (!this.measured && Number(area.height) > 0) { this.measured = true; this.restoreOffset(); } })
      .onDidScroll((): void => { if (this.measured && !this.restoring) { this.route.offsets[this.route.section] = this.scroller.currentOffset().yOffset; } })
      .onAxisEvent((event: AxisEvent): void => { scrollByAxis(this.scroller, event); })
  }
}
