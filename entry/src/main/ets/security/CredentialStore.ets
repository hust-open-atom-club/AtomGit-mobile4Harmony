export interface CredentialStore {
  save(token: string): Promise<void>;
  load(): Promise<string | undefined>;
  remove(): Promise<void>;
}
