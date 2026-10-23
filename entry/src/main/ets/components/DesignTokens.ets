// 间距阶梯（vp）
export class Dimens {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
}

// 圆角阶梯（vp）
export class Radius {
  static readonly chip: number = 12;
  static readonly card: number = 16;
  static readonly bar: number = 28;
}

// 字号阶梯（fp）
export class FontSize {
  static readonly caption: number = 12;
  static readonly body: number = 14;
  static readonly bodyLarge: number = 15;
  static readonly title: number = 16;
  static readonly headline: number = 22;
  static readonly display: number = 28;
}

// 动效时长（ms）
export class Motion {
  static readonly fast: number = 160;
  static readonly normal: number = 240;
  static readonly slow: number = 420;
}

// 阴影半径（px），颜色由 ag_glass_shadow 资源提供
export class Elevation {
  static readonly card: number = 20;
  static readonly hero: number = 28;
}
