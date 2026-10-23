import { CancelToken, HttpResult } from './HttpClient';
import { RequestSpec } from './RequestSpec';

export interface HttpPort {
  request(spec: RequestSpec, cancel?: CancelToken): Promise<HttpResult>;
}
