// 悬浮胶囊高度（vp）
export const TAB_BAR_HEIGHT: number = 56;
// 左右留边（vp）
export const TAB_BAR_SIDE_MARGIN: number = 16;
// 与屏幕底部的间距（vp，不含系统导航条）
export const TAB_BAR_BOTTOM_GAP: number = 8;

// 内容底部让位 = 高度 + 留边×2 + 间距
export const TAB_BAR_CONTENT_INSET: number =
  TAB_BAR_HEIGHT + TAB_BAR_SIDE_MARGIN * 2 + TAB_BAR_BOTTOM_GAP;
