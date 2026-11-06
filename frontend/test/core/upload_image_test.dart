import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/services/upload_image.dart';

void main() {
  final original = Uint8List(2 * 1024 * 1024);

  /// A fake encoder whose output grows with side and quality.
  Future<Uint8List?> fake(Uint8List _, int side, int quality) async =>
      Uint8List(side * quality);

  test('tries quality first, then fewer pixels, never bigger than asked', () {
    expect(UploadImage.steps(1280), [
      (1280, 80),
      (1280, 65),
      (1080, 60),
      (900, 55),
      (768, 50),
      (640, 45),
      (512, 40),
      (384, 40),
    ]);
    expect(UploadImage.steps(512), [(512, 80), (512, 65), (384, 40)]);
  });

  test('stops at the first try that fits', () async {
    final tries = <(int, int)>[];
    final out = await UploadImage.shrinkWith(
      original,
      maxSide: 1280,
      limit: 900 * 55,
      encode: (b, side, q) {
        tries.add((side, q));
        return fake(b, side, q);
      },
    );
    expect(out.length, 900 * 55);
    expect(tries.last, (900, 55));
  });

  test('nothing fits: the smallest try, not the original', () async {
    final out = await UploadImage.shrinkWith(
      original,
      maxSide: 1280,
      limit: 10,
      encode: fake,
    );
    expect(out.length, 384 * 40);
  });

  test('the encoder fails: the original goes', () async {
    final out = await UploadImage.shrinkWith(
      original,
      maxSide: 1280,
      limit: UploadImage.maxBytes,
      encode: (_, _, _) async => null,
    );
    expect(identical(out, original), isTrue);
  });

  test('fits the proxy limit once in base64', () {
    expect((UploadImage.maxBytes * 4 / 3) < 120 * 1024, isTrue);
  });
}
