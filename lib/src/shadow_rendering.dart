/// Temporary A/B switch for the clip-based shadow rendering rework.
///
/// The legacy renderer draws every shadow through two `Canvas.saveLayer`
/// calls (a blurred pass composited against a `BlendMode.dstOut` mask).
/// `saveLayer` forces an offscreen render pass per call, which is the
/// dominant raster cost of this package.
///
/// The clip-based renderer replaces the mask with `Canvas.clipPath` /
/// `Canvas.clipRect` plus a single blurred draw — no offscreen pass.
///
/// This flag exists as a kill-switch while the new renderer is validated
/// on real devices; it will be removed once the clip renderer is proven.
class NeumorphicShadowRendering {
  NeumorphicShadowRendering._();

  /// When true (default), shadows render via clip paths instead of
  /// saveLayer+dstOut masks. Set to false to restore the legacy renderer.
  static bool useClipPath = true;
}
