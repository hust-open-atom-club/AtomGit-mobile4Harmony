import { CustomLayoutAlgorithm, DynamicLayout, FrameNode,
  LayoutConstraint, Position } from '@kit.ArkUI';

import { RepoSummary } from '../model/Entities';

// chip 间距（vp），onMeasure 内换算 px
const CHIP_GAP_VP: number = 8;
// chip 高度（vp）
const CHIP_HEIGHT_VP: number = 26;

class ChipItem {
  // sys.symbol 图标；undefined 为纯文字
  readonly icon: Resource | undefined;
  readonly label: string;

  constructor(icon: Resource | undefined, label: string) {
    this.icon = icon;
    this.label = label;
  }
}

function buildChips(r: RepoSummary): ChipItem[] {
  const chips: ChipItem[] = [];
  if (r.isPrivate) {
    chips.push(new ChipItem($r('sys.symbol.lock_fill'), '私有'));
  }
  chips.push(new ChipItem($r('sys.symbol.star'), r.stars.toString()));
  chips.push(new ChipItem($r('sys.symbol.arrow_up_right'), 'Fork ' + r.forks.toString()));
  chips.push(new ChipItem($r('sys.symbol.exclamationmark_circle'), 'Issue ' + r.openIssues.toString()));
  return chips;
}

class WrapLayoutAlgorithm extends CustomLayoutAlgorithm {
  private xs: number[] = [];
  private ys: number[] = [];
  private gapPx: number = 0;

  setGapPx(px: number): void {
    this.gapPx = px;
  }

  onMeasure(self: FrameNode, constraint: LayoutConstraint): void {
    const maxW: number = typeof constraint.maxSize.width === 'number' ? constraint.maxSize.width : 0;
    const maxH: number = typeof constraint.maxSize.height === 'number'
      ? constraint.maxSize.height : Number.MAX_SAFE_INTEGER;
    const gap: number = this.gapPx;
    const count: number = self.getChildrenCount();

    let x: number = 0;
    let y: number = 0;
    let rowHeight: number = 0;
    this.xs = [];
    this.ys = [];
    for (let i = 0; i < count; i++) {
      const child: FrameNode | null = self.getChild(i);
      if (child === null) {
        this.xs.push(0);
        this.ys.push(0);
        continue;
      }
      child.measure({
        minSize: { width: 0, height: 0 },
        maxSize: { width: maxW, height: maxH },
        percentReference: { width: maxW, height: maxH }
      });
      const measured: Size = child.getMeasuredSize();
      const w: number = typeof measured.width === 'number' ? measured.width : 0;
      const h: number = typeof measured.height === 'number' ? measured.height : 0;
      if (x > 0 && x + w > maxW) {
        x = 0;
        y += rowHeight + gap;
        rowHeight = 0;
      }
      this.xs.push(x);
      this.ys.push(y);
      x += w + gap;
      rowHeight = Math.max(rowHeight, h);
    }
    self.setMeasuredSize({ width: maxW, height: y + rowHeight });
  }

  onLayout(self: FrameNode, position: Position): void {
    const count: number = self.getChildrenCount();
    for (let i = 0; i < count; i++) {
      const child: FrameNode | null = self.getChild(i);
      if (child === null) {
        continue;
      }
      child.layout({ x: this.xs[i] ?? 0, y: this.ys[i] ?? 0 });
    }
  }
}

@ComponentV2
export struct RepoMetaChips {
  @Param repo: RepoSummary | undefined = undefined;

  private readonly wrapAlgorithm: WrapLayoutAlgorithm = new WrapLayoutAlgorithm();

  aboutToAppear(): void {
    this.wrapAlgorithm.setGapPx(this.getUIContext().vp2px(CHIP_GAP_VP));
  }

  @Builder
  chip(item: ChipItem) {
    Row({ space: 4 }) {
      if (item.icon !== undefined) {
        SymbolGlyph(item.icon)
          .fontSize(13)
          .fontColor([$r('app.color.ag_text_secondary')])
      }
      Text(item.label)
        .fontSize(12)
        .fontColor($r('app.color.ag_text_secondary'))
        .maxLines(1)
    }
    .height(CHIP_HEIGHT_VP)
    .padding({ left: 10, right: 10 })
    .borderRadius(CHIP_HEIGHT_VP / 2)
    .border({ width: 1, color: $r('app.color.ag_separator') })
    .backgroundColor(Color.Transparent)
  }

  build() {
    if (this.repo !== undefined) {
      DynamicLayout(this.wrapAlgorithm) {
        ForEach(buildChips(this.repo), (item: ChipItem) => {
          this.chip(item)
        }, (item: ChipItem) => item.label)
      }
      .width('100%')
      .id('repo_meta_chips')
    }
  }
}
