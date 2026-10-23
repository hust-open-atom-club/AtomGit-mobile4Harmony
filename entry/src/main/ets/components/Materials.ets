import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

export function supportsHdsMaterial(): boolean {
  try {
    return hdsMaterial.getSystemMaterialTypes().length > 0;
  } catch (err) {
    return false;
  }
}

export function hdsAdaptiveMaterial(): SystemMaterialParams | undefined {
  if (!supportsHdsMaterial()) {
    return undefined;
  }
  const params: SystemMaterialParams = {
    materialType: hdsMaterial.MaterialType.IMMERSIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
  return params;
}

export function glassMaterial(style: uiMaterial.ImmersiveStyle,
  isDark: boolean): uiMaterial.Material | undefined {
  if (!uiMaterial.isImmersiveMaterialSupported()) {
    return undefined;
  }
  const opts: uiMaterial.ImmersiveOptions = {
    style: style,
    materialColor: Color.Transparent,
    interactive: true
  };
  if (!isDark) {
    const light: uiMaterial.LightEffectOptions = { color: Color.White };
    opts.lightEffect = light;
  }
  return new uiMaterial.ImmersiveMaterial(opts);
}

export function chipMaterial(isDark: boolean): uiMaterial.Material | undefined {
  if (!uiMaterial.isImmersiveMaterialSupported()) {
    return undefined;
  }
  const opts: uiMaterial.ImmersiveOptions = {
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    materialColor: Color.Transparent,
    interactive: true
  };
  if (!isDark) {
    const light: uiMaterial.LightEffectOptions = { color: Color.White };
    opts.lightEffect = light;
  }
  return new uiMaterial.ImmersiveMaterial(opts);
}

export function glassOrBackground(glass: uiMaterial.Material | undefined): ResourceColor {
  return glass === undefined ? $r('app.color.ag_surface') : Color.Transparent;
}

export function glassBorderColor(): ResourceColor {
  return $r('app.color.ag_glass_border');
}
