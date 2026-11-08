import { ActivityItem } from './CollaborationEntities';

export function activityActionLabel(item: ActivityItem): string {
  const action = item.actionName.trim().toLowerCase();
  if (action === 'opened') {
    if (item.kind === 'issue') {
      return 'opened an issue';
    }
    if (item.kind === 'pull_request') {
      return 'opened a pull request';
    }
    return 'opened an item';
  }
  if (action === 'commented on' || action === 'commented') {
    return 'commented on';
  }
  if (action === 'pushed to' || action === 'pushed new') {
    return 'pushed to';
  }
  if (action === 'merged') {
    return 'merged a pull request';
  }
  if (action === 'closed') {
    return 'closed an item';
  }
  if (action === 'reopened') {
    return 'reopened an item';
  }
  if (action === 'approved') {
    return 'approved a pull request';
  }
  if (action === 'assigned') {
    return 'assigned an item';
  }
  if (action.length > 0) {
    return action;
  }
  return 'updated';
}

export function activityKindLabel(item: ActivityItem): string {
  if (item.kind === 'issue') {
    return 'Issue';
  }
  if (item.kind === 'pull_request') {
    return 'Pull request';
  }
  if (item.kind === 'push') {
    return 'Commit';
  }
  if (item.kind === 'comment') {
    return 'Comment';
  }
  return 'Update';
}

export function actorInitial(item: ActivityItem): string {
  return item.actor.length > 0 ? item.actor.substring(0, 1).toUpperCase() : '?';
}

export function activityClock(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '';
  }
  return twoDigits(date.getHours()) + ':' + twoDigits(date.getMinutes());
}

function twoDigits(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}
