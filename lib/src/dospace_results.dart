import 'package:meta/meta.dart';

class BucketContent {
  /// The object's key.
  final String? key;

  /// The date and time that the object was last modified in the format: %Y-%m-%dT%H:%M:%S.%3NZ (e.g. 2017-06-23T18:37:48.157Z)
  final DateTime? lastModifiedUtc;

  /// The entity tag containing an MD5 hash of the object.
  final String? eTag;

  /// The size of the object in bytes.
  final int? size;

  BucketContent({
    required this.key,
    required this.lastModifiedUtc,
    required this.eTag,
    required this.size,
  });
}
