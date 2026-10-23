import { ApiError } from '../../main/ets/common/ApiError';
import { HttpResult } from '../../main/ets/network/HttpClient';
import { HttpPort } from '../../main/ets/network/HttpPort';
import { RequestSpec, buildUrl } from '../../main/ets/network/RequestSpec';

// 键为「方法+路径」或路径
export class FakeHttp implements HttpPort {
  bodies: Map<string, string> = new Map();
  errors: Map<string, ApiError> = new Map();
  requestedUrls: string[] = [];
  lastHeaders: Map<string, string> = new Map();
  token: string | undefined = 'TEST-TOKEN';

  onJson(path: string, json: string): FakeHttp {
    this.bodies.set(path, json);
    return this;
  }

  onError(path: string, err: ApiError): FakeHttp {
    this.errors.set(path, err);
    return this;
  }

  async request(spec: RequestSpec): Promise<HttpResult> {
    const url = buildUrl(spec);
    this.requestedUrls.push(url);
    // 只记录 path 部分，避免 query 影响匹配
    const path = url.substring(url.indexOf('/api/')).split('?')[0];
    this.lastHeaders = new Map();
    if (this.token !== undefined) {
      this.lastHeaders.set('Authorization', 'Bearer ' + this.token);
    }
    const err = this.errors.get(path);
    if (err !== undefined) {
      throw err;
    }
    const body = this.bodies.get(path);
    if (body === undefined) {
      throw new ApiError('Unknown' as never, 404, 404, 'no fake for ' + path, '', path);
    }
    return new HttpResult(body, 200, undefined, false);
  }
}
