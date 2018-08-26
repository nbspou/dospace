import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:crypto/crypto.dart';
import 'package:http_client/console.dart' as http;
import 'package:xml/xml.dart' as xml;

import 'dospace_client.dart';
import 'dospace_results.dart';

enum Permissions {
  private,
  public,
}

class Bucket extends Client {
  Bucket(
      {@required String region,
      @required String accessKey,
      @required String secretKey,
      String endpointUrl,
      http.Client httpClient})
      : super(
            region: region,
            accessKey: accessKey,
            secretKey: secretKey,
            service: "s3",
            endpointUrl: endpointUrl,
            httpClient: httpClient) {
    // ...
  }

  void bucket(String bucket) {
    if (endpointUrl == "https://${region}.digitaloceanspaces.com") {
    } else {
      throw Exception(
          "Endpoint URL not supported. Create Bucket client manually.");
    }
  }

  /// List the Bucket's Contents.
  /// https://developers.digitalocean.com/documentation/spaces/#list-bucket-contents
  Stream<BucketContent> listContents(
      {String delimiter, String prefix, int maxKeys}) async* {
    bool isTruncated;
    String marker;
    do {
      Uri uri = Uri.parse(endpointUrl + '/');
      Map<String, dynamic> params = new Map<String, dynamic>();
      if (delimiter != null) params['delimiter'] = delimiter;
      if (marker != null) {
        params['marker'] = marker;
        marker = null;
      }
      if (maxKeys != null) params['max-keys'] = "${maxKeys}";
      if (prefix != null) params['prefix'] = prefix;
      uri = uri.replace(queryParameters: params);
      xml.XmlDocument doc = await getUri(uri);
      for (xml.XmlElement root in doc.findElements('ListBucketResult')) {
        for (xml.XmlNode node in root.children) {
          if (node is xml.XmlElement) {
            xml.XmlElement ele = node;
            switch ('${ele.name}') {
              case "NextMarker":
                marker = ele.text;
                break;
              case "IsTruncated":
                isTruncated =
                    ele.text.toLowerCase() != "false" && ele.text != "0";
                break;
              case "Contents":
                String key;
                DateTime lastModifiedUtc;
                String eTag;
                int size;
                for (xml.XmlNode node in ele.children) {
                  if (node is xml.XmlElement) {
                    xml.XmlElement ele = node;
                    switch ('${ele.name}') {
                      case "Key":
                        key = ele.text;
                        break;
                      case "LastModified":
                        lastModifiedUtc = DateTime.parse(ele.text);
                        break;
                      case "ETag":
                        eTag = ele.text;
                        break;
                      case "Size":
                        size = int.parse(ele.text);
                        break;
                    }
                  }
                }
                yield new BucketContent(
                  key: key,
                  lastModifiedUtc: lastModifiedUtc,
                  eTag: eTag,
                  size: size,
                );
                break;
            }
          }
        }
      }
    } while (isTruncated);
  }

  /// Uploads file. Returns Etag.
  Future<String> uploadFile(
      String key, String filePath, String contentType, Permissions permissions,
      {Map<String, String> meta}) async {
    var input = new File(filePath);
    int contentLength = await input.length();
    Digest contentSha256 = await sha256.bind(input.openRead()).first;
    String uriStr = endpointUrl + '/' + key;
    http.Request request = new http.Request('PUT', Uri.parse(uriStr),
        headers: new http.Headers(), body: input.openRead());
    if (meta != null) {
      for (MapEntry<String, String> me in meta.entries) {
        request.headers.add("x-amz-meta-${me.key}", me.value);
      }
    }
    if (permissions == Permissions.public) {
      request.headers.add('x-amz-acl', 'public-read');
    }
    request.headers.add('Content-Length', contentLength);
    request.headers.add('Content-Type', contentType);
    signRequest(request, contentSha256: contentSha256);
    http.Response response = await httpClient.send(request);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await response.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes()); // Should be empty when OK
    if (response.statusCode != 200) {
      throw new ClientException(response.statusCode, response.reasonPhrase,
          response.headers.toSimpleMap(), body);
    }
    String etag = response.headers['etag'].first;
    return etag;
  }

  /// Uploads data from memory. Returns Etag.
  Future<String> uploadData(
      String key, Uint8List data, String contentType, Permissions permissions,
      { Map<String, String> meta, Digest contentSha256 }) async {
    int contentLength = await data.length;
    Digest contentSha256_ = contentSha256 != null ? contentSha256 : await sha256.convert(data);
    String uriStr = endpointUrl + '/' + key;
    http.Request request = new http.Request('PUT', Uri.parse(uriStr),
        headers: new http.Headers(), body: data);
    if (meta != null) {
      for (MapEntry<String, String> me in meta.entries) {
        request.headers.add("x-amz-meta-${me.key}", me.value);
      }
    }
    if (permissions == Permissions.public) {
      request.headers.add('x-amz-acl', 'public-read');
    }
    request.headers.add('Content-Length', contentLength);
    request.headers.add('Content-Type', contentType);
    signRequest(request, contentSha256: contentSha256_);
    http.Response response = await httpClient.send(request);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await response.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes()); // Should be empty when OK
    if (response.statusCode != 200) {
      throw new ClientException(response.statusCode, response.reasonPhrase,
          response.headers.toSimpleMap(), body);
    }
    String etag = response.headers['etag'].first;
    return etag;
  }

  String preSignUpload(String key, {int contentLength, String contentType, Digest contentSha256, int expires = 900, Map<String, String> meta }) {
    String uriStr = endpointUrl + '/' + key;
    Uri uriBase = Uri.parse(uriStr);
    Map<String, String> queryParameters = new Map<String, String>();
    http.Request request = new http.Request('PUT', uriBase.replace(queryParameters: queryParameters),
        headers: new http.Headers());
    if (contentLength != null)
      request.headers.add('Content-Length', contentLength);
    if (contentType != null)
      request.headers.add('Content-Type', contentType);
    if (meta != null) {
      for (MapEntry<String, String> me in meta.entries) {
        queryParameters["x-amz-meta-${me.key}"] = me.value;
      }
    }
    return signRequest(request, contentSha256: contentSha256, expires: expires, preSignedUrl: true);
  }
}
