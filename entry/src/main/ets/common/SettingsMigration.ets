import { DiskStorageInstance } from './DiskStorage';

export async function migrateElvaPreferences(target: DiskStorageInstance, legacy: DiskStorageInstance): Promise<void> {
        for (const key of ['theme', 'effects', 'hand']) {
            if (!(await target.has(key)) && await legacy.has(key)) { await target.set(key, await legacy.get(key, '')); }
        }
        if (!(await target.has('vibrationLevel')) && await legacy.has('haptic')) {
            const enabled = await legacy.get('haptic', true) as boolean;
            const level = await legacy.get('hapticLevel', 1) as number;
            await target.set('vibrationLevel', enabled ? level : 0);
        }
        if (!(await target.has('lightFieldLevel')) && await legacy.has('lightFieldLevel')) {
            await target.set('lightFieldLevel', await legacy.get('lightFieldLevel', 1));
        }
        if (!(await target.has('immersiveMaterialLevel')) && await legacy.has('materialLevel')) {
            await target.set('immersiveMaterialLevel', await legacy.get('materialLevel', 1));
        }
        if (!(await target.has('holdCheckON')) && await legacy.has('grip')) {
            await target.set('holdCheckON', await legacy.get('grip', false));
        }
}

// v2 unifies the former independent switches with material/hand choices.
// Business records are not involved; run once on the existing Preferences file.
export async function migrateUxPreferences(target: DiskStorageInstance): Promise<void> {
    if (await target.get('ux_preferences_v2', false) as boolean) { return; }
    const level = await target.get('immersiveMaterialLevel', 1) as number;
    const effects = await target.get('effects', true) as boolean;
    const material = !effects || level === 2 ? 2 : level === 0 ? 0 : 1;
    const hand = await target.get('hand', 'auto') as string;
    const grip = await target.get('holdCheckON', false) as boolean;
    const right = await target.get('buttonPositionRIGHT', false) as boolean;
    const selectedHand = hand === 'left' || hand === 'right' ? hand : grip ? 'auto' : right ? 'right' : 'left';
    await target.set('immersiveMaterialLevel', material);
    await target.set('effects', material !== 2);
    await target.set('hand', selectedHand);
    await target.set('holdCheckON', selectedHand === 'auto');
    await target.set('buttonPositionRIGHT', selectedHand === 'right');
    await target.set('theme', 'system');
    await target.set('ux_preferences_v2', true);
}
