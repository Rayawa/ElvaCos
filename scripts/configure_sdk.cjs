#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');

// Change only SDK literal properties; keep signing, product options and JSON5 comments intact.
function sdkProfile(source) {
    const values = { targetSdkVersion: '26.0.0', compatibleSdkVersion: '6.0.0(20)' };
    for (const [key, value] of Object.entries(values)) {
        const property = new RegExp(`((?:["']?${key}["']?)\\s*:\\s*)(?:(["'])[^"']*\\2|\\d+)`, 'g');
        let found = false;
        source = source.replace(property, (_match, prefix) => { found = true; return prefix + JSON.stringify(value); });
        if (!found) throw new Error(`Build profile is missing ${key}; configure the API20/API26 product explicitly.`);
    }
    return source;
}

if (require.main === module) {
    const root = path.resolve(__dirname, '..');
    const profile = path.join(root, 'build-profile.json5');
    const source = fs.readFileSync(fs.existsSync(profile) ? profile : path.join(root, 'build-profile.example.json5'), 'utf8');
    const updated = sdkProfile(source);
    if (!fs.existsSync(profile) || updated !== source) fs.writeFileSync(profile, updated);
    console.log('Build SDK: compatible API20; target API26.');
}
module.exports = { sdkProfile };
