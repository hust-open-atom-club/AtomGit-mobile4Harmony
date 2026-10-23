export type WidthBp = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

export type HeightBp = 'sm' | 'md' | 'lg';

export type LegacyBreakpoint = 'sm' | 'md' | 'lg';

@ObservedV2
export class DisplayMetrics {
  private static shared: DisplayMetrics | undefined = undefined;

  static instance(): DisplayMetrics {
    if (DisplayMetrics.shared === undefined) {
      DisplayMetrics.shared = new DisplayMetrics();
    }
    return DisplayMetrics.shared as DisplayMetrics;
  }

  @Trace topInsetVp: number = 0;
  @Trace bottomInsetVp: number = 0;
  @Trace widthVp: number = 360;
  @Trace widthBp: WidthBp = 'sm';
  @Trace heightBp: HeightBp = 'md';
  @Trace breakpoint: LegacyBreakpoint = 'sm';

  setTopInset(topVp: number): void {
    if (topVp >= 0) {
      this.topInsetVp = topVp;
    }
  }

  setBottomInset(bottomVp: number): void {
    if (bottomVp >= 0) {
      this.bottomInsetVp = bottomVp;
    }
  }

  applyInsets(topVp: number, bottomVp: number): void {
    this.setTopInset(topVp);
    this.setBottomInset(bottomVp);
  }

  applyBreakpoints(widthBp: WidthBp, heightBp: HeightBp): void {
    this.widthBp = widthBp;
    this.heightBp = heightBp;
    if (widthBp === 'xs' || widthBp === 'sm') {
      this.breakpoint = 'sm';
    } else if (widthBp === 'md') {
      this.breakpoint = 'md';
    } else {
      this.breakpoint = 'lg';
    }
  }

  applyWidth(widthVp: number): void {
    if (widthVp <= 0) {
      return;
    }
    this.widthVp = widthVp;
    if (widthVp < 320) {
      this.applyBreakpoints('xs', this.heightBp);
    } else if (widthVp < 600) {
      this.applyBreakpoints('sm', this.heightBp);
    } else if (widthVp < 840) {
      this.applyBreakpoints('md', this.heightBp);
    } else if (widthVp < 1440) {
      this.applyBreakpoints('lg', this.heightBp);
    } else {
      this.applyBreakpoints('xl', this.heightBp);
    }
  }

  isCompact(): boolean {
    return this.widthBp === 'xs' || this.widthBp === 'sm';
  }

  isWide(): boolean {
    return !this.isCompact();
  }

  isMedium(): boolean {
    return this.widthBp === 'md';
  }

  isExpanded(): boolean {
    return this.widthBp === 'lg' || this.widthBp === 'xl';
  }

  pagePadding(): number {
    if (this.isCompact()) {
      return 16;
    }
    return this.isMedium() ? 24 : 32;
  }

  sectionGap(): number {
    if (this.isCompact()) {
      return 12;
    }
    return this.isMedium() ? 16 : 20;
  }

  contentMaxWidth(): number {
    if (this.isCompact()) {
      return 720;
    }
    return this.isMedium() ? 1000 : 1280;
  }

  cardColumns(): number {
    if (this.isCompact()) {
      return 1;
    }
    return this.isMedium() ? 2 : 3;
  }

  desktopDockInset(): number {
    return this.isExpanded() ? 72 : 0;
  }

  sideNavWidth(): number {
    if (this.isMedium()) {
      return 208;
    }
    return this.widthBp === 'xl' ? 260 : 240;
  }
}
