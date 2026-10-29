import { ApiError } from '../common/ApiError';
import { RepoReadRepository } from '../repository/Ports';
import { LoadState } from './SessionStore';
import { CheckRun, RepoEntry, RepoFileContent, RepoSummary } from '../model/Entities';

@ObservedV2
export class RepoBrowseStore {
  @Trace state: LoadState = LoadState.Idle;
  @Trace repo: RepoSummary | undefined = undefined;
  @Trace entries: RepoEntry[] = [];
  @Trace file: RepoFileContent | undefined = undefined;
  @Trace checks: CheckRun[] = [];
  @Trace errorMessage: string = '';
  // 空串表示仓库根
  @Trace currentPath: string = '';

  private readonly dataSource: RepoReadRepository;
  private ciPage: number = 1;

  constructor(dataSource: RepoReadRepository) {
    this.dataSource = dataSource;
  }

  async open(owner: string, name: string): Promise<void> {
    this.state = LoadState.Loading;
    this.errorMessage = '';
    this.currentPath = '';
    this.file = undefined;
    this.repo = undefined;
    this.entries = [];
    this.checks = [];
    this.ciPage = 1;
    try {
      this.repo = await this.dataSource.repoDetail(owner, name);
      this.entries = await this.dataSource.listDir(this.repo.owner, this.repo.name, '');
      await this.loadChecks();
      this.state = LoadState.Ready;
    } catch (err) {
      this.errorMessage = err instanceof ApiError ? err.toUserMessage() : '加载失败';
      this.state = LoadState.Error;
    }
  }

  async enterDir(path: string): Promise<void> {
    if (this.repo === undefined) {
      return;
    }
    this.state = LoadState.Loading;
    this.file = undefined;
    try {
      this.entries = await this.dataSource.listDir(this.repo.owner, this.repo.name, path);
      this.currentPath = path;
      this.errorMessage = '';
      this.state = LoadState.Ready;
    } catch (err) {
      this.errorMessage = err instanceof ApiError ? err.toUserMessage() : '打开目录失败';
      this.state = LoadState.Error;
    }
  }

  async goUp(): Promise<boolean> {
    if (this.currentPath.length === 0 || this.repo === undefined) {
      return false;
    }
    const idx = this.currentPath.lastIndexOf('/');
    const parent = idx <= 0 ? '' : this.currentPath.substring(0, idx);
    await this.enterDir(parent);
    return true;
  }

  async openFile(path: string): Promise<void> {
    if (this.repo === undefined) {
      return;
    }
    this.state = LoadState.Loading;
    try {
      this.file = await this.dataSource.fileContent(this.repo.owner, this.repo.name, path);
      this.errorMessage = '';
      this.state = LoadState.Ready;
    } catch (err) {
      this.errorMessage = err instanceof ApiError ? err.toUserMessage() : '打开文件失败';
      this.state = LoadState.Error;
    }
  }

  closeFile(): void {
    this.file = undefined;
  }

  async loadChecks(): Promise<void> {
    if (this.repo === undefined) {
      return;
    }
    try {
      const res = await this.dataSource.checkRuns(this.repo.owner, this.repo.name,
        this.repo.defaultBranch, this.ciPage, 20);
      this.checks = this.ciPage === 1 ? res.items : this.checks.concat(res.items);
      this.ciPage++;
      this.errorMessage = '';
    } catch (err) {
      this.errorMessage = err instanceof ApiError ? err.toUserMessage() : '流水线状态不可用';
    }
  }

  rootLabel(): string {
    if (this.repo === undefined) {
      return '';
    }
    return this.currentPath.length === 0 ? this.repo.fullName : this.currentPath;
  }
}
