import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/painting.dart';

import '../shadow_rendering.dart';
import '../theme/theme.dart';
import 'cache/neumorphic_painter_cache.dart';
import 'neumorphic_box_decoration_helper.dart';
import 'neumorphic_emboss_decoration_painter.dart';

class NeumorphicEmptyTextPainter extends BoxPainter {
  NeumorphicEmptyTextPainter({required VoidCallback onChanged})
      : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    //does nothing
  }
}

class NeumorphicDecorationTextPainter extends BoxPainter {
  final NeumorphicStyle style;
  final String text;
  final TextStyle textStyle;
  final TextAlign textAlign;

  NeumorphicPainterCache _cache;

  late Paint _backgroundPaint;
  late Paint _whiteShadowPaint;
  late Paint _whiteShadowMaskPaint;
  late Paint _blackShadowPaint;
  late Paint _blackShadowMaskPaint;
  late Paint _gradientPaint;
  late Paint _borderPaint;

  late ui.Paragraph _textParagraph;
  late ui.Paragraph _innerTextParagraph;
  late ui.Paragraph _whiteShadowParagraph;
  late ui.Paragraph _whiteShadowMaskParagraph;
  late ui.Paragraph _blackShadowTextParagraph;
  late ui.Paragraph _blackShadowTextMaskParagraph;
  late ui.Paragraph _gradientParagraph;

  // Direct-draw shadow paints for the no-saveLayer fast path. The legacy
  // renderer applies the shadow paint's alpha twice (paragraph foreground +
  // saveLayer composite), so these carry the squared alpha.
  late Paint _whiteShadowDirectPaint;
  late Paint _blackShadowDirectPaint;

  void generatePainters() {
    this._backgroundPaint = Paint();
    this._whiteShadowPaint = Paint();
    this._whiteShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._blackShadowPaint = Paint();
    this._blackShadowMaskPaint = Paint()..blendMode = BlendMode.dstOut;
    this._whiteShadowDirectPaint = Paint();
    this._blackShadowDirectPaint = Paint();
    this._gradientPaint = Paint();

    this._borderPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.bevel
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.border.width ?? 0.0
      ..color = style.border.color ?? Color(0xFFFFFFFF);
  }

  final bool drawGradient;
  final bool drawShadow;
  final bool drawBackground;
  final bool renderingByPath;

  NeumorphicDecorationTextPainter({
    required this.style,
    required this.textStyle,
    required this.text,
    required this.drawGradient,
    required this.drawShadow,
    required this.drawBackground,
    required VoidCallback onChanged,
    required this.textAlign,
    this.renderingByPath = true,
  })  : _cache = NeumorphicPainterCache(),
        super(onChanged) {
    generatePainters();
  }

  void _updateCache(Offset offset, ImageConfiguration configuration) {
    bool invalidateSize = false;
    if (configuration.size != null) {
      invalidateSize = this
          ._cache
          .updateSize(newOffset: offset, newSize: configuration.size!);
    }

    final bool invalidateLightSource = this
        ._cache
        .updateLightSource(style.lightSource, style.oppositeShadowLightSource);

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
        _whiteShadowDirectPaint..maskFilter = _cache.maskFilterBlur;
        _blackShadowDirectPaint..maskFilter = _cache.maskFilterBlur;
      }
    }

    bool invalidateShadowColors = false;
    if (style.shadowLightColor != null &&
        style.shadowDarkColor != null &&
        style.intensity != null) {
      invalidateShadowColors = this._cache.updateShadowColor(
            newShadowLightColorEmboss: style.shadowLightColor!,
            newShadowDarkColorEmboss: style.shadowDarkColor!,
            newIntensity: style.intensity ?? neumorphicDefaultTheme.intensity,
          );
      if (invalidateShadowColors) {
        if (_cache.shadowLightColor != null) {
          final c = _cache.shadowLightColor!;
          _whiteShadowPaint..color = c;
          _whiteShadowDirectPaint..color = c.withValues(alpha: c.a * c.a);
        }
        if (_cache.shadowDarkColor != null) {
          final c = _cache.shadowDarkColor!;
          _blackShadowPaint..color = c;
          _blackShadowDirectPaint..color = c.withValues(alpha: c.a * c.a);
        }
      }
    }

    // Building and laying out paragraphs is expensive; only rebuild when an
    // input actually changed (previously this ran on EVERY paint).
    final useDirectShadow = NeumorphicShadowRendering.useClipPath &&
        _cache.backgroundColor.a >= 0.999;
    if (!_paragraphsBuilt ||
        _builtWithDirectShadow != useDirectShadow ||
        invalidateSize ||
        invalidateColor ||
        invalidateDepth ||
        invalidateShadowColors ||
        invalidateLightSource) {
      _paragraphsBuilt = true;
      _builtWithDirectShadow = useDirectShadow;
      _buildParagraphs(useDirectShadow: useDirectShadow);
    }

    if (invalidateDepth || invalidateLightSource) {
      _cache.updateDepthOffset();
    }

    if (invalidateLightSource || invalidateDepth || invalidateSize) {
      _cache.updateTranslations();
    }
  }

  bool _paragraphsBuilt = false;
  bool _builtWithDirectShadow = false;
  ui.Paragraph? _whiteShadowDirectParagraph;
  ui.Paragraph? _blackShadowDirectParagraph;

  void _buildParagraphs({required bool useDirectShadow}) {
    final constraints = ui.ParagraphConstraints(width: _cache.width);
    final paragraphStyle = textStyle.getParagraphStyle(
        textDirection: TextDirection.ltr, textAlign: this.textAlign);

    ui.Paragraph build(Paint foreground) {
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(ui.TextStyle(foreground: foreground))
        ..addText(text);
      return builder.build()..layout(constraints);
    }

    _textParagraph = build(_borderPaint);
    _innerTextParagraph = build(_backgroundPaint);

    if (useDirectShadow) {
      _whiteShadowDirectParagraph = build(_whiteShadowDirectPaint);
      _blackShadowDirectParagraph = build(_blackShadowDirectPaint);
    } else {
      _whiteShadowParagraph = build(_whiteShadowPaint);
      _whiteShadowMaskParagraph = build(_whiteShadowMaskPaint);
      _blackShadowTextParagraph = build(_blackShadowPaint);
      _blackShadowTextMaskParagraph = build(_blackShadowMaskPaint);
    }

    _gradientParagraph = build(_gradientPaint
      ..shader = getGradientShader(
        gradientRect: Rect.fromLTRB(0, 0, _cache.width, _cache.height),
        intensity: style.surfaceIntensity,
        source: style.shape == NeumorphicShape.concave
            ? this.style.lightSource
            : this.style.lightSource.invert(),
      ));
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _updateCache(offset, configuration);

    _drawShadow(offset: offset, canvas: canvas, path: _cache.path);

    _drawElement(offset: offset, canvas: canvas, path: _cache.path);
  }

  void _drawElement(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (true) {
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
        ..drawParagraph(_textParagraph, Offset.zero)
        ..restore();
    }
  }

  void _drawBackground(
      {required Canvas canvas, required Offset offset, required Path path}) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawParagraph(_innerTextParagraph, Offset.zero)
      ..restore();
  }

  void _drawShadow(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (style.depth != null && style.depth!.abs() >= 0.1) {
      if (_builtWithDirectShadow) {
        // Fast path (opaque text fill): the legacy dstOut mask only erases
        // the glyph interiors, which the opaque fill repaints anyway — so
        // draw the blurred shadow glyphs directly, no saveLayer, no mask.
        canvas
          ..save()
          ..translate(offset.dx + _cache.depthOffset.dx,
              offset.dy + _cache.depthOffset.dy)
          ..drawParagraph(_whiteShadowDirectParagraph!, Offset.zero)
          ..restore();

        canvas
          ..save()
          ..translate(offset.dx - _cache.depthOffset.dx,
              offset.dy - _cache.depthOffset.dy)
          ..drawParagraph(_blackShadowDirectParagraph!, Offset.zero)
          ..restore();
        return;
      }

      canvas
        ..saveLayer(_cache.layerRect, _whiteShadowPaint)
        ..translate(offset.dx + _cache.depthOffset.dx,
            offset.dy + _cache.depthOffset.dy)
        ..drawParagraph(_whiteShadowParagraph, Offset.zero)
        ..translate(-_cache.depthOffset.dx, -_cache.depthOffset.dy)
        ..drawParagraph(_whiteShadowMaskParagraph, Offset.zero)
        ..restore();

      canvas
        ..saveLayer(_cache.layerRect, _blackShadowPaint)
        ..translate(offset.dx - _cache.depthOffset.dx,
            offset.dy - _cache.depthOffset.dy)
        ..drawParagraph(_blackShadowTextParagraph, Offset.zero)
        ..translate(_cache.depthOffset.dx, _cache.depthOffset.dy)
        ..drawParagraph(_blackShadowTextMaskParagraph, Offset.zero)
        ..restore();
    }
  }

  void _drawGradient(
      {required Canvas canvas, required Offset offset, required Path path}) {
    if (style.shape == NeumorphicShape.concave ||
        style.shape == NeumorphicShape.convex) {
      if (NeumorphicShadowRendering.useClipPath) {
        // The gradient paragraph already carries the gradient shader as its
        // glyph foreground; the surrounding saveLayer was pure overhead.
        canvas
          ..save()
          ..translate(offset.dx, offset.dy)
          ..drawParagraph(_gradientParagraph, Offset.zero)
          ..restore();
        return;
      }
      canvas
        ..saveLayer(_cache.layerRect, _gradientPaint)
        ..translate(offset.dx, offset.dy)
        ..drawParagraph(_gradientParagraph, Offset.zero)
        ..restore();
    }
  }
}
