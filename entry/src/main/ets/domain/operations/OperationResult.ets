export type OperationStatus = 'ok' | 'partial' | 'failed' | 'savedNotRefreshed';

export interface OperationResult {
    status: OperationStatus;
    detail?: string;
}

export function operationCommitted(result: OperationResult): boolean {
    return result.status === 'ok' || result.status === 'partial' || result.status === 'savedNotRefreshed';
}
// The refresh retry never executes the write again.

export async function executeOperation(write: () => Promise<void>, refresh: () => Promise<void>): Promise<OperationResult> {
    try {
        await write();
    } catch (error) {
        return { status: 'failed', detail: (error as Error).message || '操作失败，请重试' };
    }
    try {
        await refresh();
        return { status: 'ok' };
    } catch (error) {
        return { status: 'savedNotRefreshed', detail: '记录已保存，但显示未更新，请重新加载。无需重复提交。' };
    }
}
