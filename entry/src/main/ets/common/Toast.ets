import { promptAction, UIContext } from '@kit.ArkUI';
import {
  HdsSnackBar,
  SnackBarIconOptions,
  SnackBarMessageOptions,
  SnackBarOperationOptions,
  SnackBarOperationType
} from '@kit.UIDesignKit';

export function snack(uiContext: UIContext, message: string): void {
  try {
    const icon: SnackBarIconOptions = { icon: $r('sys.symbol.checkmark_square') };
    const content: SnackBarMessageOptions = { content: message };
    const operation: SnackBarOperationOptions = {
      operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY
    };
    new HdsSnackBar(uiContext).show(icon, content, operation);
  } catch (err) {
    toast(message);
  }
}

export function toast(message: string): void {
  openToastSafe(message);
}

function openToastSafe(message: string): void {
  try {
    promptAction.openToast({ message: message });
  } catch {
  }
}
