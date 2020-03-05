import 'dart:math';

import 'package:flutter/widgets.dart';

import '../decoration/neumorphic_box_decorations.dart';
import '../theme_provider.dart';
import '../NeumorphicBoxShape.dart';
import '../theme.dart';

export '../decoration/neumorphic_box_decorations.dart';
export '../theme_provider.dart';
export '../NeumorphicBoxShape.dart';
export '../theme.dart';

class NeumorphicBorder {
  final Color color;
  final double width;
  final double depth;
  final bool oppositeLightSource;

  NeumorphicBorder({
    this.color,
    this.width,
    this.depth,
    this.oppositeLightSource = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeumorphicBorder &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          width == other.width &&
          depth == other.depth &&
          oppositeLightSource == other.oppositeLightSource;

  @override
  int get hashCode =>
      color.hashCode ^
      width.hashCode ^
      depth.hashCode ^
      oppositeLightSource.hashCode;
}

@immutable
class Neumorphic extends StatelessWidget {
  static const DEFAULT_DURATION = const Duration(milliseconds: 100);

  static const double MIN_DEPTH = -20.0;
  static const double MAX_DEPTH = 20.0;

  static const double MIN_INTENSITY = 0.0;
  static const double MAX_INTENSITY = 1.0;

  static const double MIN_CURVE = 0.0;
  static const double MAX_CURVE = 1.0;

  final Widget child;
  //final Color accent;
  final NeumorphicStyle style;
  final EdgeInsets padding;
  final NeumorphicBoxShape boxShape;
  final Duration duration;

  final NeumorphicBorder border;

  //forces have 2 different widgets if the shape changes
  final Key _circleKey = Key("circle");
  final Key _rectangleKey = Key("rectangle");

  Neumorphic({
    Key key,
    this.child,
    this.duration = Neumorphic.DEFAULT_DURATION,
    this.style,
    this.border,
    //this.accent,
    this.boxShape,
    this.padding = const EdgeInsets.all(0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shape = this.boxShape ?? NeumorphicBoxShape.roundRect();

    //print("this.accent : $accent");

    return _NeumorphicStyleAnimator(
        duration: this.duration,
        style: this.style,
        builder: (context, s) {
          NeumorphicStyle style = s;

          Widget widgetChild = this.child;
          if (border != null) {
            //if have a border, add a neumorphic with same boxshape
            //and opposite lightsource
            widgetChild = Padding(
              padding: EdgeInsets.all(border.width ?? 0),
              child: Neumorphic(
                padding: this.padding,
                boxShape: this.boxShape,
                style: style.copyWith(
                  depth: border.depth ?? style.depth,
                  lightSource: border.oppositeLightSource
                      ? style.lightSource.invert()
                      : style.lightSource,
                ),
                child: this.child,
              ),
            );

            //and used style have border color
            style = style.copyWith(color: border.color);
          } else {
            widgetChild = Padding(
              padding: this.padding,
              child: widgetChild,
            );
          }

          //print("${style.depth}");
          final decorator = NeumorphicBoxDecoration(
              /*accent: accent,*/ style: style,
              shape: shape);

          Widget clippedChild;
          if (shape.isCircle) {
            clippedChild = ClipPath(clipper: CircleClipper(), child: widgetChild);
          } else {
            clippedChild =
                ClipRRect(borderRadius: shape.borderRadius, child: widgetChild);
          }

          return AnimatedContainer(
            key: shape.isCircle ? _circleKey : _rectangleKey,
            duration: this.duration,
            child: clippedChild,
            decoration: decorator,
          );
        });
  }
}

class CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2.0, size.height / 2.0),
        radius: min(size.width / 2.0, size.height / 2.0),
      ));
  }

  @override
  bool shouldReclip(CircleClipper oldClipper) => true;
}

typedef Widget _NeumorphicStyleBuilder(
    BuildContext context, NeumorphicStyle style);

class _NeumorphicStyleAnimator extends StatefulWidget {
  //final Widget child;
  final NeumorphicStyle style;
  final Duration duration;
  final _NeumorphicStyleBuilder builder;

  _NeumorphicStyleAnimator(
      {@required this.duration, @required this.builder, this.style});

  @override
  _NeumorphicStyleAnimatorState createState() =>
      _NeumorphicStyleAnimatorState();
}

class _NeumorphicStyleAnimatorState extends State<_NeumorphicStyleAnimator>
    with TickerProviderStateMixin {
  NeumorphicThemeData _theme;
  NeumorphicStyle _animatedStyle;

  AnimationController _controller;

  //animated style
  Animation<double> _depthAnim;
  Animation<double> _intensityAnim;
  //Animation<double> _curveFactoryAnim;
  Animation<Offset> _lightSourceAnim;
  Animation<Color> _baseColorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(() {
        setState(() {
          _animatedStyle = _animatedStyle.copyWith(
            depth: _depthAnim?.value ?? _animatedStyle.depth,
            intensity: _intensityAnim?.value ?? _animatedStyle.intensity,
            //curveFactor: _curveFactoryAnim?.value ?? _animatedStyle.curveFactor,
            lightSource: _lightSourceAnim?.value != null
                ? LightSource(
                    _lightSourceAnim.value.dx, _lightSourceAnim.value.dy)
                : _animatedStyle.lightSource,
            color: _baseColorAnim?.value != null
                ? _baseColorAnim.value
                : _animatedStyle.color,
          );
          //print("animatedStyle: ${_animatedStyle}");
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NeumorphicStyleAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateStyle(_animatedStyle, widget.style);
  }

  void _initStyle() {
    _theme = NeumorphicTheme.getCurrentTheme(context) ?? neumorphicDefaultTheme;
    _animatedStyle =
        (widget.style ?? NeumorphicStyle()).copyWithThemeIfNull(_theme);
  }

  void updateStyle(NeumorphicStyle oldStyle, NeumorphicStyle newStyle) {
    final newTheme =
        NeumorphicTheme.getCurrentTheme(context) ?? neumorphicDefaultTheme;
    if (newTheme != _theme) {
      _theme = newTheme;
    }
    final styleWithTheme =
        (newStyle ?? NeumorphicStyle()).copyWithThemeIfNull(_theme);
    if (_animatedStyle != styleWithTheme) {
      if (widget.duration == Duration.zero) {
        //don't need to animate

        _animatedStyle = styleWithTheme;
      } else {
        //region animate elements

        //not animated values
        _animatedStyle = _animatedStyle.copyWith(shape: styleWithTheme.shape);

        //animated values
        if (oldStyle.depth != styleWithTheme.depth) {
          _depthAnim = Tween(begin: oldStyle.depth, end: styleWithTheme.depth)
              .animate(_controller);
        }
        if (oldStyle.intensity != styleWithTheme.intensity) {
          _intensityAnim =
              Tween(begin: oldStyle.intensity, end: styleWithTheme.intensity)
                  .animate(_controller);
        }
        // if (oldStyle.curveFactor != styleWithTheme.curveFactor) {
        //   _curveFactoryAnim = Tween(begin: oldStyle.curveFactor, end: styleWithTheme.curveFactor).animate(_controller);
        // }
        if (oldStyle.lightSource != styleWithTheme.lightSource) {
          //print("old: ${oldStyle.lightSource.offset}, new: ${styleWithTheme.lightSource.offset}");
          _lightSourceAnim = Tween(
                  begin: oldStyle.lightSource.offset,
                  end: styleWithTheme.lightSource.offset)
              .animate(_controller);
        }
        if (oldStyle.color != styleWithTheme.color) {
          _baseColorAnim =
              ColorTween(begin: oldStyle.color, end: styleWithTheme.color)
                  .animate(_controller);
        }

        //endregion
      }

      //region launch
      _controller.reset();
      _controller.forward();
      //endregion
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_theme == null) {
      _initStyle();
    }
    //print("animatedStyle: ${_animatedStyle}");
    return widget.builder(context, _animatedStyle);
  }
}