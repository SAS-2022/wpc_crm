import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Longest side of an uploaded photo and of its thumbnail (px).
const photoMaxSide = 1600;
const thumbMaxSide = 360;

/// Photos already this small are uploaded as they are.
const _keepBelowBytes = 350 * 1024;

/// A photo scaled down for upload plus a small thumbnail for the photo
/// grids (which used to download every full photo).
typedef ShrunkPhoto = ({Uint8List photo, bool reencoded, Uint8List thumb});

/// JPEG / PNG / WebP: [photoMaxSide] JPEG (unless already small) + a
/// [thumbMaxSide] JPEG thumbnail. Null when the image can't be decoded
/// (e.g. HEIC); it is then uploaded unchanged, without a thumbnail.
ShrunkPhoto? shrinkPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final image = img.bakeOrientation(decoded);
  img.Image fit(int maxSide) {
    if (image.width <= maxSide && image.height <= maxSide) return image;
    return image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }

  final big = image.width > photoMaxSide || image.height > photoMaxSide;
  final keep = !big && bytes.length < _keepBelowBytes;
  return (
    photo: keep ? bytes : img.encodeJpg(fit(photoMaxSide), quality: 72),
    reencoded: !keep,
    thumb: img.encodeJpg(fit(thumbMaxSide), quality: 70),
  );
}

/// [shrinkPhoto] off the UI thread on phones (on the web it runs inline).
Future<ShrunkPhoto?> shrinkPhotoAsync(Uint8List bytes) => compute(shrinkPhoto, bytes);
