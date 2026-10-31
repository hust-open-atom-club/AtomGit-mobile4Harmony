/** Cancellation signal shared by business ports and transport implementations. */
export interface CancellationSignal {
  isCanceled(): boolean;
  cancel(): void;
  wait(): Promise<void>;
}
