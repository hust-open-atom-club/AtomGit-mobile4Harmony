import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';

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

export enum GlassStyle {
  REGULAR = 'regular',
  THIN = 'thin',
  ULTRA_THIN = 'ultra-thin'
}

function toImmersiveStyle(style: GlassStyle): uiMaterial.ImmersiveStyle {
  if (style === GlassStyle.THIN) {
    return uiMaterial.ImmersiveStyle.THIN;
  }
  if (style === GlassStyle.ULTRA_THIN) {
    return uiMaterial.ImmersiveStyle.ULTRA_THIN;
  }
  return uiMaterial.ImmersiveStyle.REGULAR;
}

export function glassMaterial(style: GlassStyle,
  isDark: boolean): uiMaterial.Material | undefined {
  if (!deviceInfo.apiAvailable('26.0.0')) {
    return undefined;
  }
  if (!uiMaterial.isImmersiveMaterialSupported()) {
    return undefined;
  }
  const opts: uiMaterial.ImmersiveOptions = {
    style: toImmersiveStyle(style),
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
  if (!deviceInfo.apiAvailable('26.0.0')) {
    return undefined;
  }
  if (!uiMaterial.isImmersiveMaterialSupported()) {
    return undefined;
  }
  const opts: uiMaterial.ImmersiveOptions = {
    style: toImmersiveStyle(GlassStyle.ULTRA_THIN),
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
  return glass === undefined ? $r('app.color.ag_panel') : Color.Transparent;
}

export function glassSurfaceBlur(glass: uiMaterial.Material | undefined): BlurStyle {
  return glass === undefined ? BlurStyle.COMPONENT_THICK : BlurStyle.NONE;
}

export function glassBorderColor(): ResourceColor {
  return $r('app.color.ag_glass_border');
}
