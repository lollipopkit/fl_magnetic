import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:fl_magnetic/fl_magnetic.dart';

void main() {
  test('controller manages nodes and selection', () {
    final a = MagneticNode(id: 'a', text: 'A');
    final b = MagneticNode(id: 'b', text: 'B');
    final c = MagneticController(nodes: [a, b]);

    expect(c.nodes.length, 2);
    expect(c.isSelected('a'), false);

    c.setSelectedIds({'a'});
    expect(c.isSelected('a'), true);
    expect(c.selectedIds, {'a'});
    expect(c.selectedNodes.map((n) => n.id).toList(), ['a']);

    c.removeNode('a');
    expect(c.nodes.length, 1);
    expect(c.isSelected('a'), false);
    expect(c.selectedIds.isEmpty, true);
    expect(c.selectedNodes.isEmpty, true);
  });

  test('resetSelection clears selectedIds', () {
    final a = MagneticNode(id: 'a', text: 'A');
    final c = MagneticController(nodes: [a], selectedIds: {'a'});
    expect(c.selectedIds, {'a'});

    c.resetSelection();
    expect(c.selectedIds.isEmpty, true);
  });

  test('setNodes prunes selections to existing nodes', () {
    final a = MagneticNode(id: 'a', text: 'A');
    final b = MagneticNode(id: 'b', text: 'B');
    final c = MagneticController(nodes: [a, b], selectedIds: {'a', 'b'});
    expect(c.selectedIds, {'a', 'b'});

    c.setNodes([b]);
    expect(c.nodes.map((n) => n.id).toList(), ['b']);
    expect(c.selectedIds, {'b'});
  });

  test('LabelNode/ImageNode convenience types', () {
    final label = LabelNode(id: 'l', text: 'Label');
    expect(label.text, 'Label');
    expect(label.image, isNull);

    final img = ImageNode(
      id: 'i',
      image: const AssetImage('assets/does_not_matter.png'),
    );
    expect(img.id, 'i');
    expect(img.image, isNotNull);
    expect(img.text, '');

    final f1 = MagneticNode.label(id: 'fl', text: 'X');
    expect(f1.id, 'fl');
    expect(f1.image, isNull);
    expect(f1.text, 'X');

    final f2 = MagneticNode.image(
      id: 'fi',
      image: const AssetImage('assets/does_not_matter.png'),
      text: 'T',
    );
    expect(f2.id, 'fi');
    expect(f2.image, isNotNull);
    expect(f2.text, 'T');
  });
}
