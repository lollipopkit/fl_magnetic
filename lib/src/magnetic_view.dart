import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'magnetic_controller.dart';
import 'magnetic_node_style.dart';
import 'physics.dart';

typedef MagneticNodeBuilder = Widget Function(
  BuildContext context,
  MagneticNode node,
  bool selected,
);

@immutable
class MagneticViewTuning {
  final double maxDtSeconds;
  final double initialVelocityScale;
  final double itemDragReleaseVelocityScale;
  final double backgroundDragReleaseVelocityScale;
  final double pathHullSamplesPerLength;
  final int pathHullMinSamples;
  final int pathHullMaxSamples;
  final int adaptiveLabelSearchIterations;

  const MagneticViewTuning({
    this.maxDtSeconds = 0.05,
    this.initialVelocityScale = 80.0,
    this.itemDragReleaseVelocityScale = 1.0,
    this.backgroundDragReleaseVelocityScale = 0.7,
    this.pathHullSamplesPerLength = 20.0,
    this.pathHullMinSamples = 24,
    this.pathHullMaxSamples = 160,
    this.adaptiveLabelSearchIterations = 14,
  })  : assert(maxDtSeconds >= 0),
        assert(initialVelocityScale >= 0),
        assert(itemDragReleaseVelocityScale >= 0),
        assert(backgroundDragReleaseVelocityScale >= 0),
        assert(pathHullSamplesPerLength > 0),
        assert(pathHullMinSamples >= 3),
        assert(pathHullMaxSamples >= pathHullMinSamples),
        assert(adaptiveLabelSearchIterations > 0);
}

class _AdaptiveLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final FontWeight fontWeight;
  final int searchIterations;

  const _AdaptiveLabel({
    required this.text,
    required this.color,
    required this.maxFontSize,
    required this.minFontSize,
    required this.maxLines,
    required this.fontWeight,
    required this.searchIterations,
  });

  double _bestFontSize(BoxConstraints constraints, TextDirection direction) {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    if (maxW <= 0 || maxH <= 0) return maxFontSize;

    bool fits(double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
          ),
        ),
        maxLines: maxLines,
        ellipsis: '…',
        textAlign: TextAlign.center,
        textDirection: direction,
      )..layout(maxWidth: maxW);
      return !painter.didExceedMaxLines && painter.height <= maxH;
    }

    var low = minFontSize.clamp(0.0, maxFontSize);
    var high = maxFontSize;
    var best = low;
    final iters = max(1, searchIterations);
    for (var i = 0; i < iters; i++) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fs = _bestFontSize(
          constraints,
          Directionality.of(context),
        );
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fs,
            color: color,
            fontWeight: fontWeight,
          ),
        );
      },
    );
  }
}

Path _fitPathToSize(Path original, Size size) {
  final bounds = original.getBounds();
  if (bounds.isEmpty || size.isEmpty) return original;
  final maxDim = max(bounds.width, bounds.height);
  if (maxDim <= 0) return original;
  final scale = min(size.width, size.height) / maxDim;
  final tx = size.width / 2 - scale * bounds.center.dx;
  final ty = size.height / 2 - scale * bounds.center.dy;
  final m = Float64List(16)
    ..[0] = scale
    ..[5] = scale
    ..[10] = 1
    ..[15] = 1
    ..[12] = tx
    ..[13] = ty;
  return original.transform(m);
}

enum MagneticNodeAnimationType {
  select,
  deselect,
  remove,
}

typedef MagneticNodeAnimationBuilder = Widget Function(
  BuildContext context,
  MagneticNode node,
  MagneticNodeAnimationType type,
  bool selected,
  Animation<double> animation,
  Widget child,
);

class MagneticView extends StatefulWidget {
  final MagneticController? controller;
  final List<MagneticNode>? nodes;

  final MagneticNodeStyle defaultStyle;
  /// Global spacing multiplier between bubbles.
  ///
  /// Effective collision spacing is `nodeStyle.marginScale * spacingScale`.
  final double spacingScale;
  final bool allowsMultipleSelection;
  final bool enableItemDrag;
  final bool enableBackgroundDrag;
  final bool enableLongPressToRemove;
  final Duration removeAnimationDuration;
  final MagneticViewTuning tuning;
  final MagneticPhysics? physics;
  final MagneticNodeBuilder? nodeBuilder;
  /// Optional hook to provide custom animations for select/deselect/remove.
  ///
  /// When provided, default removal scale animation is disabled and this hook
  /// receives an [Animation<double>] for each transition.
  final MagneticNodeAnimationBuilder? animationBuilder;

  final ValueChanged<MagneticNode>? onSelect;
  final ValueChanged<MagneticNode>? onDeselect;
  final ValueChanged<MagneticNode>? onRemove;

  const MagneticView({
    super.key,
    this.controller,
    this.nodes,
    this.defaultStyle = const MagneticNodeStyle(),
    this.spacingScale = 1.0,
    this.allowsMultipleSelection = false,
    this.enableItemDrag = true,
    this.enableBackgroundDrag = true,
    this.enableLongPressToRemove = false,
    this.removeAnimationDuration = const Duration(milliseconds: 200),
    this.tuning = const MagneticViewTuning(),
    this.physics,
    this.nodeBuilder,
    this.animationBuilder,
    this.onSelect,
    this.onDeselect,
    this.onRemove,
  }) : assert(controller != null || nodes != null,
            'Provide either a controller or nodes.');

  @override
  State<MagneticView> createState() => _MagneticViewState();
}

class _MagneticViewState extends State<MagneticView>
    with TickerProviderStateMixin {
  late MagneticController _controller;
  late MagneticPhysics _physics;
  bool _ownsController = false;
  late final Ticker _ticker;
  final Random _rng = Random();
  final Map<String, MagneticParticle> _particles = <String, MagneticParticle>{};
  final Set<String> _removingIds = <String>{};
  final Map<String, List<Offset>> _unitHulls = <String, List<Offset>>{};
  final Map<String, Object?> _hullSources = <String, Object?>{};

  Size _size = Size.zero;
  Duration _lastTick = Duration.zero;

  Set<String> _lastSelectedIds = <String>{};
  final Map<String, AnimationController> _selectionControllers =
      <String, AnimationController>{};
  final Map<String, MagneticNodeAnimationType> _selectionTypes =
      <String, MagneticNodeAnimationType>{};
  final Map<String, AnimationController> _removeControllers =
      <String, AnimationController>{};

  String? _draggingNodeId;
  Offset _draggingOffset = Offset.zero;
  bool _draggingBackground = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MagneticController(nodes: widget.nodes);
    if (_ownsController && widget.nodes != null) {
      _controller.setNodes(widget.nodes!);
    }
    _physics = widget.physics ?? MagneticPhysics();
    _lastSelectedIds = _controller.selectedIds;
    _controller.addListener(_onControllerChanged);
    _syncParticles();

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant MagneticView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = MagneticController(nodes: widget.nodes);
        _ownsController = true;
      }
      _lastSelectedIds = _controller.selectedIds;
      _controller.addListener(_onControllerChanged);
      _syncParticles();
    } else if (_ownsController && widget.nodes != oldWidget.nodes) {
      _controller.setNodes(widget.nodes ?? const <MagneticNode>[]);
    }

    if (oldWidget.animationBuilder != widget.animationBuilder) {
      if (widget.animationBuilder == null) {
        _disposeSelectionControllers();
        _disposeRemoveControllers();
      } else {
        _lastSelectedIds = _controller.selectedIds;
      }
    }

    if (oldWidget.physics != widget.physics) {
      _physics = widget.physics ?? MagneticPhysics();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.removeListener(_onControllerChanged);
    _disposeSelectionControllers();
    _disposeRemoveControllers();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _disposeSelectionControllers() {
    for (final c in _selectionControllers.values) {
      c.dispose();
    }
    _selectionControllers.clear();
    _selectionTypes.clear();
  }

  void _disposeRemoveControllers() {
    for (final c in _removeControllers.values) {
      c.dispose();
    }
    _removeControllers.clear();
  }

  void _onControllerChanged() {
    if (widget.animationBuilder != null) {
      final current = _controller.selectedIds;
      final newlySelected = current.difference(_lastSelectedIds);
      final newlyDeselected = _lastSelectedIds.difference(current);

      for (final id in newlySelected) {
        final node = _controller.nodes
            .cast<MagneticNode?>()
            .firstWhere((n) => n?.id == id, orElse: () => null);
        if (node != null) {
          _triggerSelectionAnimation(node, MagneticNodeAnimationType.select);
        }
      }
      for (final id in newlyDeselected) {
        final node = _controller.nodes
            .cast<MagneticNode?>()
            .firstWhere((n) => n?.id == id, orElse: () => null);
        if (node != null) {
          _triggerSelectionAnimation(node, MagneticNodeAnimationType.deselect);
        }
      }
      _lastSelectedIds = current;
    } else {
      _lastSelectedIds = _controller.selectedIds;
    }

    _syncParticles();
  }

  void _syncParticles() {
    final ids = _controller.nodes.map((n) => n.id).toSet();
    _particles.removeWhere((id, _) => !ids.contains(id));
    if (widget.animationBuilder != null) {
      _selectionControllers.removeWhere((id, c) {
        if (!ids.contains(id)) {
          c.dispose();
          _selectionTypes.remove(id);
          return true;
        }
        return false;
      });
      _removeControllers.removeWhere((id, c) {
        if (!ids.contains(id)) {
          c.dispose();
          return true;
        }
        return false;
      });
    }
    _unitHulls.removeWhere((id, _) => !ids.contains(id));
    _hullSources.removeWhere((id, _) => !ids.contains(id));
    for (final node in _controller.nodes) {
      _particles.putIfAbsent(node.id, () {
        final r = _collisionRadiusFor(node);
        final pos = Offset(
          r + _rng.nextDouble() * max(1.0, _size.width - r * 2),
          r + _rng.nextDouble() * max(1.0, _size.height - r * 2),
        );
        final vel = Offset(
          (_rng.nextDouble() - 0.5) * widget.tuning.initialVelocityScale,
          (_rng.nextDouble() - 0.5) * widget.tuning.initialVelocityScale,
        );
        return MagneticParticle(position: pos, velocity: vel);
      });

      if (node.path != null && node.behavior?.convexHull(node, false, _styleFor(node)) == null) {
        final source = node.path;
        if (_hullSources[node.id] != source) {
          final unit = _computeUnitHull(source!);
          if (unit != null) {
            _unitHulls[node.id] = unit;
            _hullSources[node.id] = source;
          }
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final dtSeconds = ((elapsed - _lastTick).inMicroseconds / 1e6)
        .clamp(0.0, widget.tuning.maxDtSeconds)
        .toDouble();
    _lastTick = elapsed;
    final lockedIds = <String>{};
    if (_draggingBackground) {
      lockedIds.addAll(_particles.keys);
    } else if (_draggingNodeId != null) {
      lockedIds.add(_draggingNodeId!);
    }

    final nodes = _controller.nodes;
    final nodeById = <String, MagneticNode>{
      for (final node in nodes) node.id: node,
    };
    final radiusById = <String, double>{
      for (final node in nodes) node.id: _collisionRadiusFor(node),
    };

    _physics.step(
      particles: _particles,
      size: _size,
      dt: dtSeconds,
      radiusFor: (id) {
        final cached = radiusById[id];
        if (cached != null) return cached;
        final node = nodeById[id];
        if (node == null) return 0;
        final r = _collisionRadiusFor(node);
        radiusById[id] = r;
        return r;
      },
      hullFor: (id) {
        final node = nodeById[id];
        if (node == null) return null;
        final selected = _controller.isSelected(id);
        final style = _styleFor(node);
        final behaviorHull = node.behavior?.convexHull(node, selected, style);
        final unitHull = behaviorHull ?? _unitHulls[id];
        if (unitHull == null) return null;
        final p = _particles[id];
        if (p == null) return null;
        final diameter = (radiusById[id] ?? _collisionRadiusFor(node)) * 2;
        return unitHull
            .map((u) => p.position + u * diameter)
            .toList(growable: false);
      },
      lockedIds: lockedIds,
    );
    if (mounted) setState(() {});
  }

  List<Offset>? _computeUnitHull(Path originalPath) {
    final fitted = _fitPathToSize(originalPath, const Size(1, 1));
    final points = <Offset>[];
    for (final metric in fitted.computeMetrics(forceClosed: true)) {
      final count = (metric.length * widget.tuning.pathHullSamplesPerLength)
          .round()
          .clamp(widget.tuning.pathHullMinSamples, widget.tuning.pathHullMaxSamples)
          .toInt();
      for (var i = 0; i < count; i++) {
        final t = metric.length * (i / count);
        final pos = metric.getTangentForOffset(t)?.position;
        if (pos != null) points.add(pos);
      }
    }
    if (points.length < 3) return null;
    final hull = _convexHull(points);
    if (hull.length < 3) return null;
    return hull
        .map((p) => p - const Offset(0.5, 0.5))
        .toList(growable: false);
  }

  List<Offset> _convexHull(List<Offset> pts) {
    final sorted = pts.toList()
      ..sort((a, b) {
        final c = a.dx.compareTo(b.dx);
        return c != 0 ? c : a.dy.compareTo(b.dy);
      });
    double cross(Offset o, Offset a, Offset b) {
      return (a.dx - o.dx) * (b.dy - o.dy) -
          (a.dy - o.dy) * (b.dx - o.dx);
    }

    final lower = <Offset>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <Offset>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return lower + upper;
  }

  MagneticNodeStyle _styleFor(MagneticNode node) =>
      node.style ?? widget.defaultStyle;

  bool _anySelected() => _controller.selectedIds.isNotEmpty;

  double _displayScaleFor(MagneticNode node, bool selected) {
    final style = _styleFor(node);
    if (selected) return style.selectedScale;
    if (!_anySelected()) return style.scale;
    return style.deselectedScale;
  }

  double _displayRadiusFor(MagneticNode node, bool selected) {
    final style = _styleFor(node);
    return style.radius * _displayScaleFor(node, selected);
  }

  double _collisionRadiusFor(MagneticNode node) {
    final selected = _controller.isSelected(node.id);
    final style = _styleFor(node);
    var radius = style.radius *
        style.marginScale *
        widget.spacingScale *
        _displayScaleFor(node, selected);
    final mult =
        node.behavior?.collisionRadiusMultiplier(node, selected, style);
    if (mult != null) {
      radius *= mult;
    }
    return radius;
  }

  MagneticNode? _hitTest(Offset localPosition) {
    MagneticNode? hit;
    double bestDist = double.infinity;
    for (final node in _controller.nodes) {
      if (_removingIds.contains(node.id)) continue;
      final p = _particles[node.id];
      if (p == null) continue;
      final selected = _controller.isSelected(node.id);
      final scale = _displayScaleFor(node, selected);
      final diameter = _styleFor(node).radius * 2 * scale;
      final size = Size(diameter, diameter);
      final topLeft = p.position - Offset(diameter / 2, diameter / 2);
      final localInBox = localPosition - topLeft;
      final d = (localPosition - p.position).distance;

      bool inside;
      final behaviorHit =
          node.behavior?.hitTest(node, localInBox, size, selected, _styleFor(node));
      if (behaviorHit != null) {
        inside = behaviorHit;
      } else if (node.path != null) {
        final fitted = _fitPathToSize(node.path!, size);
        inside = fitted.contains(localInBox);
      } else {
        final r = _displayRadiusFor(node, selected);
        inside = d <= r;
      }
      if (inside && d < bestDist) {
        bestDist = d;
        hit = node;
      }
    }
    return hit;
  }

  void _triggerSelectionAnimation(
    MagneticNode node,
    MagneticNodeAnimationType type,
  ) {
    final style = _styleFor(node);
    final controller = _selectionControllers.putIfAbsent(node.id, () {
      final c = AnimationController(
        vsync: this,
        duration: style.animationDuration,
      );
      c.value = 1.0;
      return c;
    });
    controller.duration = style.animationDuration;
    _selectionTypes[node.id] = type;
    controller
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (_selectionTypes[node.id] == type) {
          setState(() {
            _selectionTypes.remove(node.id);
          });
        }
      });
  }

  void _toggleSelection(MagneticNode node) {
    final previous = _controller.selectedIds;
    final next = Set<String>.from(previous);

    if (previous.contains(node.id)) {
      next.remove(node.id);
    } else {
      if (!widget.allowsMultipleSelection) {
        next.clear();
      }
      next.add(node.id);
    }

    final deselectedIds = previous.difference(next);
    final selectedIds = next.difference(previous);

    _controller.setSelectedIds(next);

    for (final id in deselectedIds) {
      final n = _controller.nodes.firstWhere((e) => e.id == id);
      widget.onDeselect?.call(n);
    }
    for (final id in selectedIds) {
      final n = _controller.nodes.firstWhere((e) => e.id == id);
      widget.onSelect?.call(n);
    }
  }

  Future<void> _removeNode(MagneticNode node) async {
    if (_removingIds.contains(node.id)) return;
    setState(() {
      _removingIds.add(node.id);
    });

    if (widget.animationBuilder == null) {
      await Future<void>.delayed(widget.removeAnimationDuration);
      if (!mounted) return;
      _controller.removeNode(node.id);
      widget.onRemove?.call(node);
      setState(() {
        _removingIds.remove(node.id);
      });
      return;
    }

    final controller = _removeControllers.putIfAbsent(node.id, () {
      final c = AnimationController(
        vsync: this,
        duration: widget.removeAnimationDuration,
      );
      c.value = 0.0;
      return c;
    });
    controller.duration = widget.removeAnimationDuration;
    await controller.forward();
    if (!mounted) return;
    _controller.removeNode(node.id);
    widget.onRemove?.call(node);
    controller.dispose();
    _removeControllers.remove(node.id);
    setState(() {
      _removingIds.remove(node.id);
    });
  }

  Offset _globalToLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  Offset _clampPositionForNode(MagneticNode node, Offset position) {
    if (_size.isEmpty) return position;
    final r = _collisionRadiusFor(node);
    final dx = position.dx.clamp(r, max(r, _size.width - r));
    final dy = position.dy.clamp(r, max(r, _size.height - r));
    return Offset(dx.toDouble(), dy.toDouble());
  }

  void _startItemDrag(MagneticNode node, Offset localPosition) {
    final p = _particles[node.id];
    if (p == null) return;
    _draggingNodeId = node.id;
    _draggingOffset = p.position - localPosition;
    p.velocity = Offset.zero;
  }

  void _startBackgroundDrag() {
    _draggingBackground = true;
    for (final node in _controller.nodes) {
      final p = _particles[node.id];
      if (p != null) {
        p.velocity = Offset.zero;
      }
    }
  }

  void _endItemDrag(DragEndDetails details) {
    final id = _draggingNodeId;
    if (id == null) return;
    final p = _particles[id];
    if (p != null) {
      var v = details.velocity.pixelsPerSecond *
          widget.tuning.itemDragReleaseVelocityScale;
      final speed = v.distance;
      if (speed > _physics.maxVelocity) {
        v = v / speed * _physics.maxVelocity;
      }
      p.velocity = v;
    }
    _draggingNodeId = null;
  }

  void _endBackgroundDrag(DragEndDetails details) {
    final vRaw = details.velocity.pixelsPerSecond *
        widget.tuning.backgroundDragReleaseVelocityScale;
    var v = vRaw;
    final speed = v.distance;
    if (speed > _physics.maxVelocity) {
      v = v / speed * _physics.maxVelocity;
    }
    for (final node in _controller.nodes) {
      final p = _particles[node.id];
      if (p != null) {
        p.velocity += v;
      }
    }
    _draggingBackground = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );
        if (nextSize != _size) {
          _size = nextSize;
          SchedulerBinding.instance.addPostFrameCallback((_) => _syncParticles());
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final local = details.localPosition;
            final node = _hitTest(local);
            if (node != null) _toggleSelection(node);
          },
          onLongPressStart: widget.enableLongPressToRemove
              ? (details) {
                  final local = _globalToLocal(details.globalPosition);
                  final node = _hitTest(local);
                  if (node != null) _removeNode(node);
                }
              : null,
          onPanStart: (details) {
            if (!widget.enableItemDrag && !widget.enableBackgroundDrag) return;
            final local = details.localPosition;
            final node =
                widget.enableItemDrag ? _hitTest(local) : null;
            if (node != null) {
              _startItemDrag(node, local);
              setState(() {});
            } else if (widget.enableBackgroundDrag) {
              _startBackgroundDrag();
              setState(() {});
            }
          },
          onPanUpdate: (details) {
            final local = details.localPosition;
            final draggingId = _draggingNodeId;
            if (draggingId != null) {
              final node = _controller.nodes
                  .cast<MagneticNode?>()
                  .firstWhere((n) => n?.id == draggingId, orElse: () => null);
              if (node == null) return;
              final p = _particles[draggingId];
              if (p == null) return;
              final target = local + _draggingOffset;
              p.position = _clampPositionForNode(node, target);
              p.velocity = Offset.zero;
              setState(() {});
              return;
            }

            if (_draggingBackground) {
              final delta = details.delta;
              for (final node in _controller.nodes) {
                final p = _particles[node.id];
                if (p == null) continue;
                final target = p.position + delta;
                p.position = _clampPositionForNode(node, target);
                p.velocity = Offset.zero;
              }
              setState(() {});
            }
          },
          onPanEnd: (details) {
            if (_draggingNodeId != null) {
              _endItemDrag(details);
              setState(() {});
            } else if (_draggingBackground) {
              _endBackgroundDrag(details);
              setState(() {});
            }
          },
          onPanCancel: () {
            _draggingNodeId = null;
            _draggingBackground = false;
            setState(() {});
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final node in _controller.nodes)
                _buildNode(node),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNode(MagneticNode node) {
    final particle = _particles[node.id];
    if (particle == null) {
      return const SizedBox.shrink();
    }

    final selected = _controller.isSelected(node.id);
    final style = _styleFor(node);
    final diameter = style.radius * 2;
    final removing = _removingIds.contains(node.id);
    final anySelected = _anySelected();

    final baseChild = widget.nodeBuilder != null
        ? widget.nodeBuilder!(context, node, selected)
        : (node.behavior?.build(
                context, node, selected, style, anySelected) ??
            (node.path != null
                ? _PathBubble(
                    node: node,
                    selected: selected,
                    style: style,
                    anySelected: anySelected,
                    labelSearchIterations:
                        widget.tuning.adaptiveLabelSearchIterations,
                  )
                : _DefaultBubble(
                    node: node,
                    selected: selected,
                    style: style,
                    anySelected: anySelected,
                    labelSearchIterations:
                        widget.tuning.adaptiveLabelSearchIterations,
                  )));

    Widget animatedChild = baseChild;

    if (widget.animationBuilder != null) {
      final selType = _selectionTypes[node.id];
      final selController = _selectionControllers[node.id];
      if (selType != null &&
          selController != null &&
          (selController.isAnimating || selController.value < 1.0)) {
        animatedChild = widget.animationBuilder!(
          context,
          node,
          selType,
          selected,
          selController.view,
          animatedChild,
        );
      }

      if (removing) {
        final rmController = _removeControllers.putIfAbsent(node.id, () {
          final c = AnimationController(
            vsync: this,
            duration: widget.removeAnimationDuration,
          );
          c.value = 0.0;
          return c;
        });
        animatedChild = widget.animationBuilder!(
          context,
          node,
          MagneticNodeAnimationType.remove,
          selected,
          rmController.view,
          animatedChild,
        );
      }
    }

    return Positioned(
      left: particle.position.dx - diameter / 2,
      top: particle.position.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: widget.animationBuilder == null
          ? AnimatedScale(
              scale: removing ? 0.0 : 1.0,
              duration: widget.removeAnimationDuration,
              curve: Curves.easeInOut,
              child: animatedChild,
            )
          : animatedChild,
    );
  }
}

class _DefaultBubble extends StatelessWidget {
  final MagneticNode node;
  final bool selected;
  final MagneticNodeStyle style;
  final bool anySelected;
  final int labelSearchIterations;

  const _DefaultBubble({
    required this.node,
    required this.selected,
    required this.style,
    required this.anySelected,
    required this.labelSearchIterations,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? style.selectedColor : style.color;
    final fg = selected ? style.selectedTextColor : style.textColor;
    final scale =
        selected ? style.selectedScale : (anySelected ? style.deselectedScale : style.scale);

    return AnimatedScale(
      scale: scale,
      duration: style.animationDuration,
      curve: Curves.easeOutBack,
      child: Semantics(
        label: node.semanticsLabel ?? node.text,
        button: true,
        selected: selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: style.strokeColor,
              width: style.strokeWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasImage = node.image != null;
                if (!hasImage) {
                  return Center(
                    child: _AdaptiveLabel(
                      text: node.text,
                      color: fg,
                      maxFontSize: style.fontSize,
                      minFontSize: style.minFontSize,
                      maxLines: style.textMaxLines,
                      fontWeight: FontWeight.w600,
                      searchIterations: labelSearchIterations,
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ClipOval(
                        child: Image(
                          image: node.image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: _AdaptiveLabel(
                          text: node.text,
                          color: fg,
                          maxFontSize: style.fontSize,
                          minFontSize: style.minFontSize,
                          maxLines: style.textMaxLines,
                          fontWeight: FontWeight.w600,
                          searchIterations: labelSearchIterations,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FittedPathClipper extends CustomClipper<Path> {
  final Path originalPath;
  const _FittedPathClipper(this.originalPath);

  @override
  Path getClip(Size size) => _fitPathToSize(originalPath, size);

  @override
  bool shouldReclip(covariant _FittedPathClipper oldClipper) =>
      oldClipper.originalPath != originalPath;
}

class _PathBubblePainter extends CustomPainter {
  final Path originalPath;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const _PathBubblePainter({
    required this.originalPath,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _fitPathToSize(originalPath, size);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathBubblePainter oldDelegate) {
    return oldDelegate.originalPath != originalPath ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _PathBubble extends StatelessWidget {
  final MagneticNode node;
  final bool selected;
  final MagneticNodeStyle style;
  final bool anySelected;
  final int labelSearchIterations;

  const _PathBubble({
    required this.node,
    required this.selected,
    required this.style,
    required this.anySelected,
    required this.labelSearchIterations,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? style.selectedColor : style.color;
    final fg = selected ? style.selectedTextColor : style.textColor;
    final scale =
        selected ? style.selectedScale : (anySelected ? style.deselectedScale : style.scale);
    final path = node.path!;

    return AnimatedScale(
      scale: scale,
      duration: style.animationDuration,
      curve: Curves.easeOutBack,
      child: Semantics(
        label: node.semanticsLabel ?? node.text,
        button: true,
        selected: selected,
        child: CustomPaint(
          painter: _PathBubblePainter(
            originalPath: path,
            fillColor: bg,
            strokeColor: style.strokeColor,
            strokeWidth: style.strokeWidth,
          ),
          child: ClipPath(
            clipper: _FittedPathClipper(path),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (node.image != null)
                  Image(
                    image: node.image!,
                    fit: BoxFit.cover,
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: _AdaptiveLabel(
                      text: node.text,
                      color: fg,
                      maxFontSize: style.fontSize,
                      minFontSize: style.minFontSize,
                      maxLines: style.textMaxLines,
                      fontWeight: FontWeight.w600,
                      searchIterations: labelSearchIterations,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
