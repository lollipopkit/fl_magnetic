import 'dart:math';

import 'package:flutter/widgets.dart';

import 'cell_key.dart';

/// Represents a single particle in the physics simulation.
///
/// Each particle has a position and velocity, and corresponds to
/// a magnetic node in the view.
class MagneticParticle {
  /// Current position of the particle.
  Offset position;

  /// Current velocity of the particle.
  Offset velocity;

  /// Creates a new particle with the given position and velocity.
  MagneticParticle({required this.position, required this.velocity});
}

/// Physics simulation for magnetic nodes.
///
/// Handles collision detection, attraction to center, and general
/// physics behavior for magnetic nodes. Supports both circle-based
/// and convex hull-based collision detection.
class MagneticPhysics {
  final Random _rng;

  /// Strength of attraction toward the center of the view.
  final double attractionStrength;

  /// Amount of random motion applied to particles.
  final double randomMotion;

  /// Drag coefficient that slows particles over time.
  final double drag;

  /// Maximum velocity magnitude for particles.
  final double maxVelocity;

  /// Bounce factor when particles hit boundaries (0-1).
  final double bounce;

  /// Whether to enable spatial hashing for performance optimization.
  final bool enableSpatialHash;

  /// Minimum number of particles before spatial hashing is enabled.
  final int spatialHashThreshold;

  /// Multiplier for spatial hash cell size based on particle radius.
  final double spatialHashCellSizeMultiplier;

  /// Minimum size for spatial hash cells.
  final double spatialHashMinCellSize;

  /// Number of sides to use when approximating circles with polygons.
  final int satCircleHullSides;

  /// Minimum distance for particles to be considered at the same position.
  final double samePositionEpsilon;

  /// Minimum distance from center before attraction is applied.
  final double centerAttractionEpsilon;

  /// Impulse factor applied during collisions.
  final double collisionImpulse;

  /// Whether to copy provided hull arrays to avoid mutation.
  final bool copyProvidedHulls;

  /// Creates a new physics simulation with the given parameters.
  ///
  /// The default values are carefully chosen to provide natural,
  /// pleasing motion for most use cases.
  MagneticPhysics({
    Random? rng,
    this.attractionStrength = 50.0,
    this.randomMotion = 6.0,
    this.drag = 0.15,
    this.maxVelocity = 220.0,
    this.bounce = 0.8,
    this.enableSpatialHash = true,
    this.spatialHashThreshold = 32,
    this.spatialHashCellSizeMultiplier = 2.0,
    this.spatialHashMinCellSize = 1.0,
    this.satCircleHullSides = 12,
    this.samePositionEpsilon = 0.001,
    this.centerAttractionEpsilon = 0.001,
    this.collisionImpulse = 0.9,
    this.copyProvidedHulls = true,
  }) : assert(spatialHashThreshold >= 0),
       assert(spatialHashCellSizeMultiplier > 0),
       assert(spatialHashMinCellSize > 0),
       assert(satCircleHullSides >= 3),
       assert(samePositionEpsilon >= 0),
       assert(centerAttractionEpsilon >= 0),
       assert(collisionImpulse >= 0),
       _rng = rng ?? Random();

  /// Advances the physics simulation by one time step.
  ///
  /// Parameters:
  /// - [particles] - Map of particle IDs to particle states
  /// - [size] - Size of the containing view
  /// - [dt] - Time step in seconds
  /// - [radiusFor] - Function to get collision radius for a particle
  /// - [hullFor] - Optional function to get convex hull for collision
  /// - [lockedIds] - Set of particle IDs that shouldn't move
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

    final ids = <String>[];
    final particleList = <MagneticParticle>[];
    final radii = <double>[];
    final locked = <bool>[];
    var maxRadius = 0.0;

    for (final entry in particles.entries) {
      final id = entry.key;
      final p = entry.value;

      ids.add(id);
      particleList.add(p);

      final r = radiusFor(id);
      radii.add(r);
      if (r > maxRadius) maxRadius = r;

      final isLocked = lockedIds.contains(id);
      locked.add(isLocked);

      if (isLocked) {
        p.velocity = Offset.zero;
        continue;
      }

      final toCenter = center - p.position;
      final dist = toCenter.distance;
      if (dist > centerAttractionEpsilon) {
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

    final count = ids.length;
    if (count < 2) return;

    final samePos2 = samePositionEpsilon * samePositionEpsilon;

    final hullPolys = List<List<Offset>?>.filled(count, null);
    final polyCache = List<List<Offset>?>.filled(count, null);
    if (hullFor != null) {
      for (var i = 0; i < count; i++) {
        final hull = hullFor(ids[i]);
        if (hull != null && hull.length >= 3) {
          final poly = copyProvidedHulls
              ? List<Offset>.from(hull, growable: false)
              : hull;
          hullPolys[i] = poly;
          polyCache[i] = poly;
        }
      }
    }

    void translatePoly(int idx, Offset delta) {
      final poly = polyCache[idx];
      if (poly == null) return;
      for (var k = 0; k < poly.length; k++) {
        poly[k] = poly[k] + delta;
      }
    }

    List<Offset> polyFor(int idx) {
      final existing = polyCache[idx];
      if (existing != null) return existing;
      final poly = _circleHull(
        particleList[idx].position,
        radii[idx],
        sides: satCircleHullSides,
      );
      polyCache[idx] = poly;
      return poly;
    }

    void processPair(int i, int j) {
      final a = particleList[i];
      final b = particleList[j];
      final rA = radii[i];
      final rB = radii[j];
      final minDist = rA + rB;
      final minDist2 = minDist * minDist;

      final lockedA = locked[i];
      final lockedB = locked[j];
      if (lockedA && lockedB) return;

      var delta = b.position - a.position;
      var dist2 = delta.dx * delta.dx + delta.dy * delta.dy;
      if (dist2 < samePos2) {
        delta = Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5);
        dist2 = delta.dx * delta.dx + delta.dy * delta.dy;
      }
      if (dist2 >= minDist2) return;

      final dist = sqrt(dist2);
      final dir = delta / dist;

      if (hullPolys[i] == null && hullPolys[j] == null) {
        final overlap = minDist - dist;

        if (lockedA) {
          final move = dir * overlap;
          b.position += move;
          translatePoly(j, move);

          final sepSpeed = b.velocity.dx * dir.dx + b.velocity.dy * dir.dy;
          if (sepSpeed < 0) {
            b.velocity -= dir * sepSpeed * collisionImpulse;
          }
        } else if (lockedB) {
          final move = dir * overlap;
          a.position -= move;
          translatePoly(i, -move);

          final sepSpeed = a.velocity.dx * dir.dx + a.velocity.dy * dir.dy;
          if (sepSpeed > 0) {
            a.velocity -= dir * sepSpeed * collisionImpulse;
          }
        } else {
          final move = dir * (overlap / 2);
          a.position -= move;
          b.position += move;
          translatePoly(i, -move);
          translatePoly(j, move);

          final relVel = b.velocity - a.velocity;
          final sepSpeed = relVel.dx * dir.dx + relVel.dy * dir.dy;
          if (sepSpeed < 0) {
            final impulse = dir * sepSpeed * collisionImpulse;
            a.velocity += impulse;
            b.velocity -= impulse;
          }
        }
        return;
      }

      final polyA = polyFor(i);
      final polyB = polyFor(j);
      final sat = _sat(polyA, polyB);
      if (sat == null) return;

      final nrm = sat.normal;
      final overlap = sat.depth;

      if (lockedA) {
        final move = nrm * overlap;
        b.position += move;
        translatePoly(j, move);

        final sepSpeed = b.velocity.dx * nrm.dx + b.velocity.dy * nrm.dy;
        if (sepSpeed < 0) {
          b.velocity -= nrm * sepSpeed * collisionImpulse;
        }
      } else if (lockedB) {
        final move = nrm * overlap;
        a.position -= move;
        translatePoly(i, -move);

        final sepSpeed = a.velocity.dx * nrm.dx + a.velocity.dy * nrm.dy;
        if (sepSpeed > 0) {
          a.velocity -= nrm * sepSpeed * collisionImpulse;
        }
      } else {
        final move = nrm * (overlap / 2);
        a.position -= move;
        b.position += move;
        translatePoly(i, -move);
        translatePoly(j, move);

        final relVel = b.velocity - a.velocity;
        final sepSpeed = relVel.dx * nrm.dx + relVel.dy * nrm.dy;
        if (sepSpeed < 0) {
          final impulse = nrm * sepSpeed * collisionImpulse;
          a.velocity += impulse;
          b.velocity -= impulse;
        }
      }
    }

    final useSpatialHash = enableSpatialHash && count > spatialHashThreshold;
    if (!useSpatialHash) {
      for (var i = 0; i < count; i++) {
        for (var j = i + 1; j < count; j++) {
          processPair(i, j);
        }
      }
      return;
    }

    final cellSize = max(
      spatialHashMinCellSize,
      maxRadius * spatialHashCellSizeMultiplier,
    );
    final invCellSize = 1.0 / cellSize;
    final grid = <CellKey, List<int>>{};

    for (var i = 0; i < count; i++) {
      final pos = particleList[i].position;
      final cx = (pos.dx * invCellSize).floor();
      final cy = (pos.dy * invCellSize).floor();
      final key = packCellKey(cx, cy);
      grid.putIfAbsent(key, () => <int>[]).add(i);
    }

    final neighborRange = max(1, ((maxRadius * 2) / cellSize).ceil());

    for (final entry in grid.entries) {
      final key = entry.key;
      final cell = entry.value;

      for (var a = 0; a < cell.length; a++) {
        for (var b = a + 1; b < cell.length; b++) {
          processPair(cell[a], cell[b]);
        }
      }

      final x = unpackCellX(key);
      final y = unpackCellY(key);

      for (var dx = 0; dx <= neighborRange; dx++) {
        final dyStart = dx == 0 ? 1 : -neighborRange;
        for (var dy = dyStart; dy <= neighborRange; dy++) {
          final neighborKey = packCellKey(x + dx, y + dy);
          final other = grid[neighborKey];
          if (other == null) continue;

          for (final i in cell) {
            for (final j in other) {
              processPair(i, j);
            }
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
      final overlap = min(projA.$2, projB.$2) - max(projA.$1, projB.$1);
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
