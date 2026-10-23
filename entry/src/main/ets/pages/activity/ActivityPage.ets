import { ComingSoonView } from '../../components/ComingSoonView';

@ComponentV2
export struct ActivityPage {
  build() {
    ComingSoonView({
      title: '动态',
      subtitle: '你关注的人与项目的活动，会按时间线汇总在这里。',
      symbol: $r('sys.symbol.wave'),
      viewId: 'activity_placeholder',
      features: ['用户动态', '项目动态', '游标分页', '筛选与作者'],
      apiHint: '接口已实测连通 · 等待协作模块接入'
    })
  }
}
