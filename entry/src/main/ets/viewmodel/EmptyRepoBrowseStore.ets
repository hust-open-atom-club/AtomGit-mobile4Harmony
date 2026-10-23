import { HttpClient, defaultConfig } from '../network/HttpClient';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { RepoBrowseStore } from './RepoBrowseStore';
import { LoadState } from './SessionStore';

@ObservedV2
export class EmptyRepoBrowseStore extends RepoBrowseStore {
  constructor() {
    super(new AtomGitRepository(new HttpClient(defaultConfig())));
    this.state = LoadState.Idle;
  }
}
