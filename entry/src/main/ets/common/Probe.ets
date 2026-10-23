import { TokenCipher } from '../security/TokenCipher';
import { HttpClient, TokenSource, defaultConfig } from '../network/HttpClient';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { fromBase64, toBase64, utf8Decode, utf8Encode } from './Codec';
import { safeParse, safeParseArray } from './Json';

class ProbeTokenSource implements TokenSource {
  currentToken(): string | undefined {
    return 'probe-token';
  }
}

export function probeWiring(): number {
  const client = new HttpClient(defaultConfig());
  client.setTokenSource(new ProbeTokenSource());
  const repo = new AtomGitRepository(client);
  const guard = new AccountGuard();
  const cipher = new TokenCipher();
  const cache = new CacheStore(guard);
  const settings = new SettingsStore();
  const session = new SessionStore(repo, cipher, cache, settings, guard);
  const browse = new RepoBrowseStore(repo);
  return utf8Decode(utf8Encode('x')).length
    + fromBase64(toBase64(utf8Encode('y'))).length
    + (safeParse('{}') === undefined ? 0 : 1)
    + (safeParseArray('[]') === undefined ? 0 : 1)
    + (session.isLoggedIn() ? 1 : 0)
    + (browse.rootLabel().length);
}
