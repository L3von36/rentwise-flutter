// Guard: the sample dataset's seeded orders must carry REAL encoded
// signatures (signatureToDoc output), not placeholder strings — the
// decoder honestly turns garbage into zero strokes, which rendered as
// an empty white thumbnail box on order detail.
import 'package:flutter_test/flutter_test.dart';
import 'package:rentwise/data/appwrite_mappers.dart';

import 'fixtures/sample_dataset.dart';

void main() {
  test('every seeded signed order decodes to visible strokes', () {
    final orders = SampleDataset.orders(DateTime.now());
    final signed = orders.where((o) => o.signatureCaptured).toList();
    expect(signed, isNotEmpty, reason: 'fixture should include signed orders');
    for (final o in signed) {
      final strokes = signatureFromDoc(o.signatureData);
      expect(strokes, isNotEmpty,
          reason: '${o.id} claims signed but decodes to no strokes');
      final points = strokes.expand((s) => s).length;
      expect(points, greaterThanOrEqualTo(2),
          reason: '${o.id} signature has too few points to draw');
    }
  });
}
