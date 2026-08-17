import 'package:material_ui/material_ui.dart';
import 'package:flutter/painting.dart';

import '../neumorphic_box_shape.dart';
import '../shadow_rendering.dart';
import '../theme/theme.dart';
import 'cache/neumorphic_painter_cache.dart';
import 'neumorphic_box_decoration_helper.dart';
import 'neumorphic_emboss_decoration_painter.dart';

class NeumorphicDecorationPainter extends BoxPainter {
  final NeumorphicStyle style;
  final NeumorphicBoxShape shape;

  NeumorphicPainterCache _cache = NeumorphicPainterCache();

  late Paint _backgroundPaint;
  late Paint _whiteShadowPaint;
  late Paint _whiteShadowMaskPaint;
  late Paint _blackShadowPaint;
  late Paint _blackShadowMaskPaint;
  late Paint _gradientPaint;
  late Paint _borderPaint;

  // Clip-mode paints. The legacy renderer passes the shadow paint to BOTH
  // saveLayer and drawPath, so its color alpha is applied twice (once when
  // drawing, once when the layer is composited). The clip renderer draws
  // once, so these paints carry the squared alpha to match.
  late Paint _whiteClipShadowPaint;
  late Paint _blackClipShadowPaint;

  void generatePainters() {
    this._backgroundPaint = Paint();
    this._whiteShadowPaint = Paint();
    this._whiteShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._blackShadowPaint = Paint();
    this._blackShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._whiteClipShadowPaint = Paint();
    this._blackClipShadowPaint = Paint();
    this._gradientPaint = Paint();

    this._borderPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.bevel
      ..style = PaintingStyle.stroke;
  }

  final bool drawGradient;
  final bool drawShadow;
  final bool drawBackground;
  final bool renderingByPath;

  NeumorphicDecorationPainter({
    required this.style,
    required this.shape,
    required this.drawGradient,
    required this.drawShadow,
    required this.drawBackground,
    required VoidCallback onChanged,
    this.renderingByPath = true,
  }) : super(onChanged) {
    generatePainters();
  }

  void _updateCache(Offset offset, ImageConfiguration configuration) {
    bool invalidateSize = false;
    if (configuration.size != null) {
      invalidateSize = this
          ._cache
          .updateSize(newOffset: offset, newSize: configuration.size!);
      if (invalidateSize) {
        _cache.updatePath(
            newPath:
                shape.customShapePathProvider.getPath(configuration.size!));
        _clipOutPaths = null;
      }
    }

    bool invalidateLightSource = false;
    if (style.color != null) {
      invalidateLightSource = this._cache.updateLightSource(
          style.lightSource, style.oppositeShadowLightSource);
    }

    bool invalidateColor = false;
    if (style.color != null) {
      invalidateColor = this._cache.updateStyleColor(style.color!);
      if (invalidateColor) {
        _backgroundPaint..color = _cache.backgroundColor;
      }
    }

    bool invalidateDepth = false;
    if (style.depth != null) {
      invalidateDepth = this._cache.updateStyleDepth(style.depth!, 3);
      if (invalidateDepth) {
        _blackShadowPaint..maskFilter = _cache.maskFilterBlur;
        _whiteShadowPaint..maskFilter = _cache.maskFilterBlur;
        _whiteClipShadowPaint..maskFilter = _cache.maskFilterBlur;
        _blackClipShadowPaint..maskFilter = _cache.maskFilterBlur;
      }
    }

    bool invalidateShadowColors = false;
    if (style.shadowLightColor != null &&
        style.shadowDarkColor != null &&
        style.intensity != null) {
      invalidateShadowColors = this._cache.updateShadowColor(
            newShadowLightColorEmboss: style.shadowLightColor!,
            newShadowDarkColorEmboss: style.shadowDarkColor!,
            newIntensity: style.intensity!,
          );
      if (invalidateShadowColors) {
        if (_cache.shadowLightColor != null) {
          final c = _cache.shadowLightColor!;
          _whiteShadowPaint..color = c;
          _whiteClipShadowPaint..color = c.withValues(alpha: c.a * c.a);
        }
        if (_cache.shadowDarkColor != null) {
          final c = _cache.shadowDarkColor!;
          _blackShadowPaint..color = c;
          _blackClipShadowPaint..color = c.withValues(alpha: c.a * c.a);
        }
      }
    }

    if (invalidateDepth || invalidateLightSource) {
      _cache.updateDepthOffset();
    }

    if (invalidateLightSource || invalidateDepth || invalidateSize) {
      _cache.updateTranslations();
    }
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _updateCache(offset, configuration);

    if (drawShadow && NeumorphicShadowRendering.useClipPath) {
      _updateClipOutPaths(offset);
    }

    for (var i = 0; i < _cache.subPaths.length; i++) {
      if (drawShadow) {
        _drawShadow(
            offset: offset,
            canvas: canvas,
            path: _cache.subPaths[i],
            clipOutPath: NeumorphicShadowRendering.useClipPath
                ? _clipOutPaths![i]
                : _cache.subPaths[i]);
      }
    }

    if (renderingByPath) {
      for (var subPath in _cache.subPaths) {
        _drawElement(offset: offset, canvas: canvas, path: subPath);
      }
    } else {
      _drawElement(offset: offset, canvas: canvas, path: _cache.path);
    }
  }

  void _drawElement(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (drawBackground) {
      _drawBackground(offset: offset, canvas: canvas, path: path);
    }
    if (this.drawGradient) {
      _drawGradient(offset: offset, canvas: canvas, path: path);
    }
    if (style.border.isEnabled) {
      _drawBorder(canvas: canvas, offset: offset, path: path);
    }
  }

  void _drawBorder(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (style.border.width != null && style.border.width! > 0) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawPath(
            path,
            _borderPaint
              ..color = style.border.color ?? Color(0x00000000)
              ..strokeWidth = style.border.width ?? 0)
        ..restore();
    }
  }

  void _drawBackground(
      {required Canvas canvas, required Offset offset, required Path path}) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawPath(path, _backgroundPaint)
      ..restore();
  }

  // Clip-based shadow rendering: the legacy path erases the widget's own
  // footprint out of the blurred shadow with a saveLayer + dstOut mask
  // (an offscreen render pass per shadow). Clipping to "everything except
  // the footprint" and drawing the blurred shadow once is equivalent for a
  // hard-edged mask and needs no offscreen pass. One clip-out path per
  // subpath, cached until the geometry changes.
  List<Path>? _clipOutPaths;
  Offset? _clipOutOffset;

  void _updateClipOutPaths(Offset offset) {
    if (_clipOutPaths == null || _clipOutOffset != offset) {
      _clipOutOffset = offset;
      final layerRectPath = Path()..addRect(_cache.layerRect ?? Rect.largest);
      _clipOutPaths = [
        for (final subPath in _cache.subPaths)
          Path.combine(
              PathOperation.difference, layerRectPath, subPath.shift(offset)),
      ];
    }
  }

  void _drawShadow(
      {required Canvas canvas,
      required Offset offset,
      required Path path,
      required Path clipOutPath}) {
    if (style.depth != null && style.depth!.abs() >= 0.1) {
      if (NeumorphicShadowRendering.useClipPath) {
        canvas
          ..save()
          ..clipRect(_cache.layerRect ?? Rect.largest)
          ..clipPath(clipOutPath)
          ..translate(offset.dx + _cache.depthOffset.dx,
              offset.dy + _cache.depthOffset.dy)
          ..drawPath(path, _whiteClipShadowPaint)
          ..restore();

        canvas
          ..save()
          ..clipRect(_cache.layerRect ?? Rect.largest)
          ..clipPath(clipOutPath)
          ..translate(offset.dx - _cache.depthOffset.dx,
              offset.dy - _cache.depthOffset.dy)
          ..drawPath(path, _blackClipShadowPaint)
          ..restore();
        return;
      }

      canvas
        ..saveLayer(_cache.layerRect, _whiteShadowPaint)
        ..translate(offset.dx + _cache.depthOffset.dx,
            offset.dy + _cache.depthOffset.dy)
        ..drawPath(path, _whiteShadowPaint)
        ..translate(-_cache.depthOffset.dx, -_cache.depthOffset.dy)
        ..drawPath(path, _whiteShadowMaskPaint)
        ..restore();

      canvas
        ..saveLayer(_cache.layerRect, _blackShadowPaint)
        ..translate(offset.dx - _cache.depthOffset.dx,
            offset.dy - _cache.depthOffset.dy)
        ..drawPath(path, _blackShadowPaint)
        ..translate(_cache.depthOffset.dx, _cache.depthOffset.dy)
        ..drawPath(path, _blackShadowMaskPaint)
        ..restore();
    }
  }

  // Gradient shader cache: creating a shader allocates engine resources, so
  // only rebuild it when the inputs actually change (rect, intensity, source).
  Rect? _lastGradientRect;
  double? _lastGradientIntensity;
  LightSource? _lastGradientSource;

  void _drawGradient(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (style.shape == NeumorphicShape.concave ||
        style.shape == NeumorphicShape.convex) {
      final pathRect = path.getBounds();
      final source = style.shape == NeumorphicShape.concave
          ? this.style.lightSource
          : this.style.lightSource.invert();

      if (pathRect != _lastGradientRect ||
          style.surfaceIntensity != _lastGradientIntensity ||
          source != _lastGradientSource) {
        _lastGradientRect = pathRect;
        _lastGradientIntensity = style.surfaceIntensity;
        _lastGradientSource = source;
        _gradientPaint
          ..shader = getGradientShader(
            gradientRect: pathRect,
            intensity: style.surfaceIntensity,
            source: source,
          );
      }

      canvas
        ..saveLayer(
          pathRect.translate(offset.dx, offset.dy),
          _gradientPaint,
        )
        ..translate(offset.dx, offset.dy)
        ..drawPath(path, _gradientPaint)
        ..restore();
    }
  }
}
