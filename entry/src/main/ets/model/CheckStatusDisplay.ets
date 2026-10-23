import { CheckStatus } from './Entities';

export type StatusTone = 'success' | 'error' | 'warning' | 'neutral';

export function checkStatusLabel(s: CheckStatus): string {
  if (s === CheckStatus.Success) {
    return '成功';
  }
  if (s === CheckStatus.Failure) {
    return '失败';
  }
  if (s === CheckStatus.Running) {
    return '进行中';
  }
  if (s === CheckStatus.Other) {
    return '已取消';
  }
  return '未知';
}

export function checkStatusTone(s: CheckStatus): StatusTone {
  if (s === CheckStatus.Success) {
    return 'success';
  }
  if (s === CheckStatus.Failure) {
    return 'error';
  }
  if (s === CheckStatus.Running) {
    return 'warning';
  }
  return 'neutral';
}
