import { window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

export interface SafeAreaInsets {
  topVp: number
  bottomVp: number
}

export function pxToVp(px: number): number {
  if (px <= 0) {
    return 0
  }
  try {
    const d = display.getDefaultDisplaySync()
    return px / (d.densityDPI / 160)
  } catch (_e) {
    return px / 3
  }
}

export function fetchSafeAreaInsets(context: common.UIAbilityContext): Promise<SafeAreaInsets> {
  return window.getLastWindow(context).then((win: window.Window): SafeAreaInsets => {
    try {
      const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const cutout = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)

      let topPx = system.topRect.height
      if (cutout.topRect.height > topPx) {
        topPx = cutout.topRect.height
      }

      const insets: SafeAreaInsets = {
        topVp: pxToVp(topPx),
        bottomVp: pxToVp(nav.bottomRect.height)
      }
      return insets
    } catch (_e) {
      const fallback: SafeAreaInsets = { topVp: 0, bottomVp: 0 }
      return fallback
    }
  }).catch((_e: Error): SafeAreaInsets => {
    const fallback: SafeAreaInsets = { topVp: 0, bottomVp: 0 }
    return fallback
  })
}
