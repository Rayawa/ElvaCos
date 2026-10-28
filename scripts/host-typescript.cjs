const Module = require('node:module');

// Host model checks can also run on Node 24 without a local DevEco installation.
// Native ArkUI builders are deliberately excluded from this execution path.
function transpileModule(source) {
    const observed = [...source.matchAll(/@ObservedV2\s+export\s+class\s+(\w+)/g)].map(match => match[1]);
    const names = [...source.matchAll(/export\s+(?:async\s+)?(?:class|function|const|let|enum)\s+(\w+)/g)].map(match => match[1]);
    let input = source.replace(/@(ObservedV2|Trace|Computed)\b\s*/g, '');
    input = Module.stripTypeScriptTypes(input, { mode: 'transform', sourceMap: false });
    input = input.replace(/import\s+\{([^}]+)\}\s+from\s+(['"][^'"]+['"])\s*;/g,
        (_match, members, id) => `const { ${members.replace(/\bas\b/g, ':')} } = require(${id});`);
    input = input.replace(/import\s+([\w]+)\s+from\s+(['"][^'"]+['"])\s*;/g,
        (_match, name, id) => `const ${name} = require(${id});`);
    input = input.replace(/export\s+\{([^}]+)\}\s+from\s+(['"][^'"]+['"])\s*;/g,
        (_match, members, id) => members.split(',').map(name => `exports.${name.trim()} = require(${id}).${name.trim()};`).join('\n'));
    input = input.replace(/\bexport\s+(?=(?:async\s+)?(?:class|function|const|let|var)\b)/g, '');
    return { outputText: input + '\n' + observed.map(name => `${name} = global.ObservedV2(${name}) || ${name};`).join('\n') + '\n' + names.map(name => `exports.${name} = ${name};`).join('\n') };
}
module.exports = { transpileModule, ModuleKind: { CommonJS: 1 }, ScriptTarget: { ES2021: 1 } };
