import 'dart:math';

import 'package:flutter/widgets.dart';

class MagneticParticle {
  Offset position;
  Offset velocity;

  MagneticParticle({
    required this.position,
    required this.velocity,
  });
}

class MagneticPhysics {
  final Random _rng;
  final double attractionStrength;
  final double randomMotion;
  final double drag;
  final double maxVelocity;
  final double bounce;

  MagneticPhysics({
    Random? rng,
    this.attractionStrength = 50.0,
    this.randomMotion = 6.0,
    this.drag = 0.15,
    this.maxVelocity = 220.0,
    this.bounce = 0.8,
  }) : _rng = rng ?? Random();

  void step({
    required Map<String, MagneticParticle> particles,
    required Size size,
    required double dt,
    required double Function(String id) radiusFor,
    List<Offset>? Function(String id)? hullFor,
    Set<String> lockedIds = const <String>{},
  }) {
    if (size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final shortestSide = size.shortestSide;

    for (final entry in particles.entries) {
      final id = entry.key;
      final p = entry.value;
      final r = radiusFor(entry.key);

      if (lockedIds.contains(id)) {
        p.velocity = Offset.zero;
        continue;
      }

      final toCenter = center - p.position;
      final dist = toCenter.distance;
      if (dist > 0.001) {
        final dir = toCenter / dist;
        final force = dir * (attractionStrength / max(1.0, shortestSide));
        p.velocity += force * dt * shortestSide;
      }

      final jitter = Offset(
        (_rng.nextDouble() - 0.5) * randomMotion,
        (_rng.nextDouble() - 0.5) * randomMotion,
      );
      p.velocity += jitter * dt;

      final damping = (1.0 - drag * dt).clamp(0.0, 1.0);
      p.velocity = p.velocity * damping;

      final speed = p.velocity.distance;
      if (speed > maxVelocity) {
        p.velocity = p.velocity / speed * maxVelocity;
      }

      p.position += p.velocity * dt;

      if (p.position.dx < r) {
        p.position = Offset(r, p.position.dy);
        p.velocity = Offset(-p.velocity.dx * bounce, p.velocity.dy);
      } else if (p.position.dx > size.width - r) {
        p.position = Offset(size.width - r, p.position.dy);
        p.velocity = Offset(-p.velocity.dx * bounce, p.velocity.dy);
      }

      if (p.position.dy < r) {
        p.position = Offset(p.position.dx, r);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy * bounce);
      } else if (p.position.dy > size.height - r) {
        p.position = Offset(p.position.dx, size.height - r);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy * bounce);
      }
    }

    final ids = particles.keys.toList(growable: false);
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final idA = ids[i];
        final idB = ids[j];
        final a = particles[idA]!;
        final b = particles[idB]!;
        final rA = radiusFor(idA);
        final rB = radiusFor(idB);
        final minDist = rA + rB;

        final lockedA = lockedIds.contains(idA);
        final lockedB = lockedIds.contains(idB);

        final hullA = hullFor?.call(idA);
        final hullB = hullFor?.call(idB);

        if (hullA == null && hullB == null) {
          var delta = b.position - a.position;
          var dist = delta.distance;
          if (dist < 0.001) {
            delta =
                Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5);
            dist = delta.distance;
          }
          if (dist < minDist) {
            final dir = delta / dist;
            final overlap = minDist - dist;

            if (lockedA && lockedB) {
              continue;
            } else if (lockedA) {
              b.position += dir * overlap;
              final sepSpeed =
                  b.velocity.dx * dir.dx + b.velocity.dy * dir.dy;
              if (sepSpeed < 0) {
                b.velocity -= dir * sepSpeed * 0.9;
              }
            } else if (lockedB) {
              a.position -= dir * overlap;
              final sepSpeed =
                  a.velocity.dx * dir.dx + a.velocity.dy * dir.dy;
              if (sepSpeed > 0) {
                a.velocity -= dir * sepSpeed * 0.9;
              }
            } else {
              a.position -= dir * (overlap / 2);
              b.position += dir * (overlap / 2);

              final relVel = b.velocity - a.velocity;
              final sepSpeed = relVel.dx * dir.dx + relVel.dy * dir.dy;
              if (sepSpeed < 0) {
                final impulse = dir * sepSpeed * 0.9;
                a.velocity += impulse;
                b.velocity -= impulse;
              }
            }
          }
          continue;
        }

        final polyA =
            hullA ?? _circleHull(a.position, rA, sides: 12);
        final polyB =
            hullB ?? _circleHull(b.position, rB, sides: 12);

        final sat = _sat(polyA, polyB);
        if (sat == null) continue;

        final dir = sat.normal;
        final overlap = sat.depth;

        if (lockedA && lockedB) {
          continue;
        } else if (lockedA) {
          b.position += dir * overlap;
          final sepSpeed = b.velocity.dx * dir.dx + b.velocity.dy * dir.dy;
          if (sepSpeed < 0) {
            b.velocity -= dir * sepSpeed * 0.9;
          }
        } else if (lockedB) {
          a.position -= dir * overlap;
          final sepSpeed = a.velocity.dx * dir.dx + a.velocity.dy * dir.dy;
          if (sepSpeed > 0) {
            a.velocity -= dir * sepSpeed * 0.9;
          }
        } else {
          a.position -= dir * (overlap / 2);
          b.position += dir * (overlap / 2);

          final relVel = b.velocity - a.velocity;
          final sepSpeed = relVel.dx * dir.dx + relVel.dy * dir.dy;
          if (sepSpeed < 0) {
            final impulse = dir * sepSpeed * 0.9;
            a.velocity += impulse;
            b.velocity -= impulse;
          }
        }
      }
    }
  }
}

class _SatResult {
  final Offset normal;
  final double depth;
  const _SatResult(this.normal, this.depth);
}

List<Offset> _circleHull(Offset center, double radius, {int sides = 12}) {
  final pts = <Offset>[];
  for (var i = 0; i < sides; i++) {
    final a = (2 * pi * i) / sides;
    pts.add(center + Offset(cos(a) * radius, sin(a) * radius));
  }
  return pts;
}

Offset _centroid(List<Offset> poly) {
  var x = 0.0, y = 0.0;
  for (final p in poly) {
    x += p.dx;
    y += p.dy;
  }
  final n = poly.length.toDouble();
  return Offset(x / n, y / n);
}

_SatResult? _sat(List<Offset> a, List<Offset> b) {
  double minOverlap = double.infinity;
  Offset smallestAxis = Offset.zero;

  bool testAxes(List<Offset> poly) {
    for (var i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      final edge = p2 - p1;
      final axis = Offset(-edge.dy, edge.dx);
      final axisLen = axis.distance;
      if (axisLen < 1e-6) continue;
      final unit = axis / axisLen;

      final projA = _project(a, unit);
      final projB = _project(b, unit);
      final overlap =
          min(projA.$2, projB.$2) - max(projA.$1, projB.$1);
      if (overlap <= 0) {
        return false;
      }
      if (overlap < minOverlap) {
        minOverlap = overlap;
        smallestAxis = unit;
      }
    }
    return true;
  }

  if (!testAxes(a)) return null;
  if (!testAxes(b)) return null;

  final cA = _centroid(a);
  final cB = _centroid(b);
  final toB = cB - cA;
  if (toB.dx * smallestAxis.dx + toB.dy * smallestAxis.dy < 0) {
    smallestAxis = -smallestAxis;
  }

  return _SatResult(smallestAxis, minOverlap);
}

(double, double) _project(List<Offset> poly, Offset axis) {
  var minVal = double.infinity;
  var maxVal = -double.infinity;
  for (final p in poly) {
    final d = p.dx * axis.dx + p.dy * axis.dy;
    if (d < minVal) minVal = d;
    if (d > maxVal) maxVal = d;
  }
  return (minVal, maxVal);
}
