import { describe, it, expect } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { parseLocalDocument, DocumentBlock } from '../../../main/ets/common/LocalDocument';
import { getApplicationState } from '../../../main/ets/common/appState';
import { AppState } from '../../../main/ets/model/ApplicationState';
import { TestContext } from '../testability/TestContext';

export default function structureTest(): void {
  describe('StructureAndLocalDocument', () => {
    it('sharedStateConnectsWithoutOpeningProductionDatabase', 0, () => {
      const first = getApplicationState();
      const second = getApplicationState();
      expect(first === second).assertTrue();
      expect(first.ready).assertFalse();
      expect(first.busy).assertFalse();
    });
    it('disposeWaitsForAnActiveOperationBeforeResettingState', 0, async () => {
      const state = new AppState();
      let release: () => void = () => {};
      let finished = false;
      const pending = new Promise<void>((resolve): void => { release = resolve; });
      const operation = state.perform(async (): Promise<void> => {
        await pending;
        finished = true;
        state.ready = true;
      }, false);
      const closing = state.dispose();
      expect(state.busy).assertTrue();
      expect(finished).assertFalse();
      expect(await state.perform(async (): Promise<void> => {}, false)).assertFalse();
      release();
      expect(await operation).assertTrue();
      await closing;
      expect(finished).assertTrue();
      expect(state.ready).assertFalse();
      expect(state.busy).assertFalse();
    });
    it('documentSkipsNestedHiddenTemplatesScriptsAndExternalMarkup', 0, () => {
      const html = '<html><head><style>#permissions { display:none }</style></head><body>' +
        '<h1>声明</h1><p>可见<span>正文</span>&amp;内容</p>' +
        '<div style="display:none"><p>模板<span>隐藏</span></p></div>' +
        '<div id="permissions"><p>权限占位</p></div>' +
        '<script>发送数据()</script><svg><text>图标</text></svg>' +
        '<p>尾段&#x4e2d;&#25991;</p></body></html>';
      const blocks = parseLocalDocument(html);
      expect(blocks.length).assertEqual(3);
      expect(blocks[0].heading).assertTrue();
      expect(blocks[1].text).assertEqual('可见正文&内容');
      expect(blocks[2].text).assertEqual('尾段中文');
    });
    it('documentPreservesInlineTextAndRejectsEmptyBody', 0, () => {
      const blocks = parseLocalDocument('<body><p>甲<strong>乙</strong>丙<br>丁</p><div aria-hidden="true">隐藏</div></body>');
      expect(blocks[0].text).assertEqual('甲乙丙');
      expect(blocks[1].text).assertEqual('丁');
      expect(parseLocalDocument('<head><title>不作为正文</title></head>').length).assertEqual(0);
    });
    it('bundledPolicyUsesTheOnlySourceAndHasNoTemplatePlaceholders', 0, async () => {
      if (!TestContext.value) { throw new Error('Missing module context'); }
      const context = TestContext.value.createModuleContext('entry');
      const data = await context.resourceManager.getRawFileContent('privacy.html');
      const source = new util.TextDecoder('utf-8', { fatal: true }).decodeToString(data);
      const blocks = parseLocalDocument(source);
      const text = blocks.map((block: DocumentBlock): string => block.text).join('\n');
      expect(text.includes('关于绮秀与隐私的声明')).assertTrue();
      expect(text.includes('rayawa.work@outlook.com')).assertTrue();
      expect(text.includes('2026')).assertTrue();
      expect(text.includes('undefined')).assertFalse();
      expect(text.includes('function')).assertFalse();
      expect(blocks.length > 10).assertTrue();
    });
  });
}
