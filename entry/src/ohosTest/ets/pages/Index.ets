import { ActivityPage } from '../../../main/ets/pages/activity/ActivityPage';
import { LoginPage } from '../../../main/ets/pages/login/LoginPage';
import { AccountGuard } from '../../../main/ets/security/TokenEnvelope';
import { ActivityStore } from '../../../main/ets/viewmodel/ActivityStore';
import { SessionStore } from '../../../main/ets/viewmodel/SessionStore';
import {
  E2EActivityRepository,
  E2ECacheCleaner,
  E2ECredentialStore,
  E2ESessionRepository,
  E2ESettingsCleaner
} from '../testability/E2EFakes';

@Entry
@ComponentV2
struct Index {
  @Local session: SessionStore = new SessionStore(
    new E2ESessionRepository(),
    new E2ECredentialStore(),
    new E2ECacheCleaner(),
    new E2ESettingsCleaner(),
    new AccountGuard()
  );
  @Local activity: ActivityStore = new ActivityStore(new E2EActivityRepository());

  build() {
    Column() {
      if (this.session.loggedIn) {
        ActivityPage({
          store: this.activity,
          session: this.session,
          onOpenRepo: (owner: string, name: string) => {
          }
        })
      } else {
        LoginPage({
          session: this.session,
          onLoggedIn: () => {
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .id('e2e_host')
  }
}
