import { CancellationSignal } from '../common/Cancellation';
import { HttpResult } from './HttpClient';
import { RequestSpec } from './RequestSpec';

export interface HttpPort {
  request(spec: RequestSpec, cancel?: CancellationSignal): Promise<HttpResult>;
}
