import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

class IndicatorStyle {
  //final double borderRadius;
  final double depth;
  final Color accent;
  final Color variant;

  const IndicatorStyle({
    this.depth = -4,
    this.accent,
    this.variant,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProgressStyle &&
              runtimeType == other.runtimeType &&
              depth == other.depth &&
              accent == other.accent &&
              variant == other.variant;

  @override
  int get hashCode =>
      depth.hashCode ^
      accent.hashCode ^
      variant.hashCode;

}

enum NeumorphicIndicatorOrientation {
  vertical,
  horizontal
}

class NeumorphicIndicator extends StatefulWidget {
  final double percent;
  final double width;
  final double height;
  final NeumorphicIndicatorOrientation orientation;
  final IndicatorStyle style;

  const NeumorphicIndicator({
    Key key,
    this.percent = 0.5,
    this.orientation = NeumorphicIndicatorOrientation.vertical,
    this.height = double.maxFinite,
    this.width = double.maxFinite,
    this.style = const IndicatorStyle(),
  }) : super(key: key);

  @override
  createState() => _NeumorphicIndicatorState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is NeumorphicIndicator &&
              runtimeType == other.runtimeType &&
              percent == other.percent &&
              width == other.width &&
              height == other.height &&
              orientation == other.orientation &&
              style == other.style;

  @override
  int get hashCode =>
      percent.hashCode ^
      width.hashCode ^
      height.hashCode ^
      orientation.hashCode ^
      style.hashCode;

}

class _NeumorphicIndicatorState extends State<NeumorphicIndicator> with TickerProviderStateMixin {
  double percent = 0;
  AnimationController _controller;
  Animation _animation;

  @override
  void initState() {
    super.initState();
    percent = widget.percent ?? 0;
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 150));
  }

  @override
  void didUpdateWidget(NeumorphicIndicator oldWidget) {
    if (oldWidget.percent != widget.percent) {
      _controller.reset();
      _animation = Tween<double>(begin: oldWidget.percent, end: widget.percent).animate(_controller)
        ..addListener(() {
          setState(() {
            this.percent = _animation.value;
          });
        });

      _controller.forward();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NeumorphicTheme theme = NeumorphicThemeProvider.findNeumorphicTheme(context);
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Neumorphic(
        shape: NeumorphicBoxShape.stadium(),
        padding: EdgeInsets.zero,
        style: NeumorphicStyle(depth: widget.style.depth, shape: NeumorphicShape.flat),
        child: FractionallySizedBox(
          heightFactor: widget.orientation == NeumorphicIndicatorOrientation.vertical ? widget.percent : 1,
          widthFactor: widget.orientation == NeumorphicIndicatorOrientation.horizontal ? widget.percent : 1,
          alignment: widget.orientation == NeumorphicIndicatorOrientation.horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
          child: ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: NeumorphicBoxShape.stadium().borderRadius,
            child: Container(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  widget.style.accent ?? theme.accentColor,
                  widget.style.variant ?? theme.variantColor
                ],
              ),
            )),
          ),
        ),
      ),
    );
  }
}