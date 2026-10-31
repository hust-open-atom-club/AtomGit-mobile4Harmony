import { hilog } from '@kit.PerformanceAnalysisKit';

export enum RefreshDomain {
  Activity = 'activity',
  Todo = 'todo',
  Notifications = 'notifications',
  Issue = 'issue',
  PullRequest = 'pullRequest'
}

export class RefreshEvent {
  readonly domain: RefreshDomain;
  readonly accountId: string;
  readonly reason: string;
  readonly repositoryKey: string;
  readonly itemKey: string;
  readonly revision: number;

  constructor(domain: RefreshDomain, accountId: string, reason: string,
    repositoryKey: string, itemKey: string, revision: number) {
    this.domain = domain;
    this.accountId = accountId;
    this.reason = reason;
    this.repositoryKey = repositoryKey;
    this.itemKey = itemKey;
    this.revision = revision;
  }
}

export type RefreshListener = (event: RefreshEvent) => void;

export class RefreshFilter {
  readonly domain?: RefreshDomain;
  readonly accountId?: string;

  constructor(domain?: RefreshDomain, accountId?: string) {
    this.domain = domain;
    this.accountId = accountId;
  }
}

class RefreshSubscription {
  readonly listener: RefreshListener;
  readonly filter: RefreshFilter | undefined;

  constructor(listener: RefreshListener, filter?: RefreshFilter) {
    this.listener = listener;
    this.filter = filter;
  }

  accepts(event: RefreshEvent): boolean {
    if (this.filter === undefined) return true;
    return (this.filter.domain === undefined || this.filter.domain === event.domain)
      && (this.filter.accountId === undefined || this.filter.accountId === event.accountId);
  }
}

/** In-process invalidation. Subscribers can filter by account and feature domain. */
export class RefreshCoordinator {
  private readonly listeners: Map<number, RefreshSubscription> = new Map<number, RefreshSubscription>();
  private revision: number = 0;
  private nextListenerId: number = 1;

  subscribe(listener: RefreshListener, filter?: RefreshFilter): number {
    const id = this.nextListenerId++;
    this.listeners.set(id, new RefreshSubscription(listener, filter));
    return id;
  }

  unsubscribe(id: number): void { this.listeners.delete(id); }

  publish(domain: RefreshDomain, accountId: string, reason: string,
    repositoryKey: string = '', itemKey: string = ''): RefreshEvent {
    this.revision++;
    const event = new RefreshEvent(domain, accountId, reason, repositoryKey, itemKey, this.revision);
    this.listeners.forEach((subscription: RefreshSubscription) => {
      if (!subscription.accepts(event)) return;
      try {
        subscription.listener(event);
      } catch (err) {
        hilog.error(0x0000, 'AtomGit', 'refresh listener failed: %{public}s',
          err instanceof Error ? err.message : 'unknown error');
      }
    });
    return event;
  }
}
