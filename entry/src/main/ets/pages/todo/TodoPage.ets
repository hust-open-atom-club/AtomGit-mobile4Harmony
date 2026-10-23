import { ComingSoonView } from '../../components/ComingSoonView';

@ComponentV2
export struct TodoPage {
  build() {
    ComingSoonView({
      title: '待办',
      subtitle: '分派给你的 Issue、待评审与待审批的 PR，会集中在这里处理。',
      symbol: $r('sys.symbol.checkmark_square'),
      viewId: 'todo_placeholder',
      features: ['我的 Issue', '待审批 PR', '待评审 PR', '状态回读'],
      apiHint: '接口已实测连通 · 等待协作模块接入'
    })
  }
}
