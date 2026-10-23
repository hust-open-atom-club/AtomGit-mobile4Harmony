export interface CacheCleaner {
  clearCurrentAccount(): Promise<void>;
}

export interface SettingsCleaner {
  clear(): Promise<void>;
}
