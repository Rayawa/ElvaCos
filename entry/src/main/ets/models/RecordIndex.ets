/** Build relation indexes once per data revision, outside UI builders. */

export function indexById<T>(items: T[], key: (item: T) => string): Map<string, T> {
    const index = new Map<string, T>();
    for (const item of items) {
        index.set(key(item), item);
    }
    return index;
}

export function groupBy<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
    const groups = new Map<string, T[]>();
    for (const item of items) {
        const id = key(item);
        const group = groups.get(id);
        if (group) {
            group.push(item);
        } else {
            groups.set(id, [item]);
        }
    }
    return groups;
}
