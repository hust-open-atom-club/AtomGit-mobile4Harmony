import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@kit.TestKit';

import {
  E2E_PERSONAL_TITLE,
  E2E_PROJECT_TITLE,
  E2E_TOKEN
} from '../testability/E2EFakes';

const UI_WAIT_MS: number = 10000;

export default function loginActivityE2E() {
  describe('LoginActivityE2E', () => {
    it('logs_in_and_opens_personal_and_project_activity', 0, async () => {
      const driver = Driver.create();
      const input = await driver.waitForComponent(ON.id('login_token_input'), UI_WAIT_MS);
      await input.inputText(E2E_TOKEN);
      await driver.pressBack();

      const submit = await driver.waitForComponent(ON.id('login_submit'), UI_WAIT_MS);
      await submit.click();

      await driver.waitForComponent(ON.id('activity_page'), UI_WAIT_MS);
      await driver.assertComponentExist(ON.text(E2E_PERSONAL_TITLE));

      const projects = await driver.waitForComponent(ON.id('activity_source_projects'), UI_WAIT_MS);
      await projects.click();
      await driver.waitForComponent(ON.text(E2E_PROJECT_TITLE), UI_WAIT_MS);

      expect(true).assertTrue();
    });
  });
}
