import { ComingSoonView } from '../../components/ComingSoonView';

@ComponentV2
export struct NotificationPage {
  build() {
    ComingSoonView({
      title: '通知',
      subtitle: '项目通知按已选仓库聚合，支持未读筛选与批量已读回执。',
      symbol: $r('sys.symbol.bell'),
      viewId: 'notification_placeholder',
      features: ['未读筛选', '按仓库聚合', '批量已读', '并发上限'],
      apiHint: '接口已核实 · 等待协作模块接入'
    })
  }
}
