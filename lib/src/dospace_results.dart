
import 'package:meta/meta.dart';

class ListBucketContents {
  /// The object's key.
  final String key;

  /// The date and time that the object was last modified in the format: %Y-%m-%dT%H:%M:%S.%3NZ (e.g. 2017-06-23T18:37:48.157Z)
  final DateTime lastModifiedUtc;

  /// The entity tag containing an MD5 hash of the object.
  final String eTag;

  /// The size of the object in bytes.
  final int size;

  ListBucketContents({
    @required this.key,
    @required this.lastModifiedUtc,
    @required this.eTag,
    @required this.size,
  });
}

class ListBucketResult {
  /// The name of the bucket.
  final String name;

  /// The specified prefix if supplied as a query parameter.
  final String prefix;

  /// A key denoting where the list of objects begins. If empty, this indicates the beginning of the list.
  final String marker;

  /// Specifies the key which should be used with the maker query parameter in subsistent requests. This is only returned if a delimiter was provided with the request and IsTruncated is true.
  final String nextMarker;

  /// The maximum number of objects to return. Defaults to 1,000.
  final String maxKeys;

  /// A boolean indicating whether all objects are included in the response.
  final bool isTruncated;

  /// A container holding elements with information about the objects in the bucket.
  final List<ListBucketContents> contents;

  ListBucketResult({
    @required this.name,
    @required this.prefix,
    @required this.marker,
    @required this.nextMarker,
    @required this.maxKeys,
    @required this.isTruncated,
    @required this.contents,
  });
}
