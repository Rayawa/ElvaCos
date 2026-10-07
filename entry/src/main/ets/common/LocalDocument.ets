/** 将本地 HTML 的可见正文投影为原生文本块，不执行脚本，也不加载外部资源。 */
export interface DocumentBlock {
  text: string;
  heading: boolean;
}

interface DocumentTag {
  name: string;
  hidden: boolean;
}

function attribute(tag: string, name: string): string {
  const match = new RegExp('\\b' + name + '\\s*=\\s*["\']([^"\']*)["\']', 'i').exec(tag);
  return match ? match[1] : '';
}

function decodeEntities(text: string): string {
  return text.replace(/&#(x[0-9a-f]+|[0-9]+);/gi, (_whole: string, value: string): string => {
    const code = value.toLowerCase().startsWith('x') ? parseInt(value.slice(1), 16) : parseInt(value, 10);
    return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : '';
  }).replace(/&nbsp;/gi, ' ').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"').replace(/&apos;/gi, "'").replace(/&amp;/gi, '&');
}

export function parseLocalDocument(html: string): DocumentBlock[] {
  const blocks: DocumentBlock[] = [];
  const tags: DocumentTag[] = [];
  const hiddenIds: string[] = [];
  // 当前文档使用内联样式及 ID 规则隐藏模板占位；不将这些占位播报给用户。
  const rules = html.match(/#[\w-]+\s*\{[^}]*display\s*:\s*none[^}]*\}/gi) || [];
  for (const rule of rules) {
    const id = /#([\w-]+)/.exec(rule);
    if (id) { hiddenIds.push(id[1]); }
  }
  const tokens = html.replace(/<!--[\s\S]*?-->/g, '').match(/<[^>]*>|[^<]+/g) || [];
  let body: boolean = false;
  let text: string = '';
  let heading: boolean = false;
  const flush = (): void => {
    const value = decodeEntities(text).replace(/\s+/g, ' ').trim();
    if (value) { blocks.push({ text: value, heading: heading }); }
    text = '';
    heading = false;
  };
  for (const token of tokens) {
    if (!token.startsWith('<')) {
      if (body && !tags.some((tag: DocumentTag): boolean => tag.hidden)) { text += token; }
      continue;
    }
    const match = /^<\s*(\/?)\s*([\w-]+)/.exec(token);
    if (!match) { continue; }
    const closing = match[1] === '/';
    const name = match[2].toLowerCase();
    if (name === 'body') { if (closing) { flush(); } body = !closing; continue; }
    if (!body) { continue; }
    const boundary = /^(p|h[1-6]|li|div|section|article|br)$/.test(name);
    if (closing) {
      if (boundary) { flush(); }
      // Closing a nested span must not unhide its parent.
      for (let index = tags.length - 1; index >= 0; index--) {
        if (tags[index].name === name) { tags.splice(index); break; }
      }
    } else {
      if (boundary) { flush(); }
      const hidden = /^(script|style|svg|noscript|template)$/.test(name) ||
        /\s(?:hidden|aria-hidden\s*=\s*["']true["'])(?:\s|>|\/)/i.test(token) ||
        /display\s*:\s*none|visibility\s*:\s*hidden/i.test(attribute(token, 'style')) ||
        hiddenIds.includes(attribute(token, 'id'));
      if (!/^(br|hr|img|input|meta|link)$/.test(name) && !/\/\s*>$/.test(token)) {
        tags.push({ name: name, hidden: hidden });
      }
      if (/^h[1-6]$/.test(name)) { heading = true; }
    }
  }
  flush();
  return blocks;
}
