import { ApiError, ApiErrorKind } from '../common/ApiError';
import { HttpClient, defaultConfig } from '../network/HttpClient';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { LoadState, SessionStore } from './SessionStore';

@ObservedV2
export class EmptySessionStore extends SessionStore {
  constructor() {
    super(new AtomGitRepository(new HttpClient(defaultConfig())),
      new TokenCipher(), new CacheStore(new AccountGuard()),
      new SettingsStore(), new AccountGuard());
    this.state = LoadState.Idle;
  }
}
