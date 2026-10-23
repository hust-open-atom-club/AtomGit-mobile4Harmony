import localUnitTest from './LocalUnit.test';
import apiErrorTest from './ApiError.test';
import pagerTest from './Pager.test';
import redactTest from './Redact.test';
import networkPolicyTest from './NetworkPolicy.test';
import tokenEnvelopeTest from './TokenEnvelope.test';
import jsonTest from './Json.test';
import apiContractTest from './ApiContract.test';
import requestSpecTest from './RequestSpec.test';
import codecTest from './Codec.test';
import viewModelTest from './ViewModel.test';
import repositoryTest from './Repository.test';
import cacheScopeTest from './CacheScope.test';
import checkStatusDisplayTest from './CheckStatusDisplay.test';
import displayMetricsTest from './DisplayMetrics.test';

export default function testsuite() {
  localUnitTest();
  apiErrorTest();
  pagerTest();
  redactTest();
  networkPolicyTest();
  tokenEnvelopeTest();
  jsonTest();
  apiContractTest();
  requestSpecTest();
  codecTest();
  viewModelTest();
  repositoryTest();
  cacheScopeTest();
  checkStatusDisplayTest();
  displayMetricsTest();
}