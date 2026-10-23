import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@ComponentV2
struct Index {
  @Local message: string = 'AtomGit test host';

  build() {
    Column({ space: 12 }) {
      Text(this.message)
        .id('test_host_title')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Button('Run sample')
        .id('test_host_button')
        .onClick(() => {
          this.message = 'clicked';
          hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'test host button clicked');
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
