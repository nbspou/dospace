
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:crypto/crypto.dart';
import 'package:http_client/console.dart' as http;
import 'package:xml/xml.dart' as xml;

import 'dospace_results.dart';

class ClientException implements Exception {
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> responseHeaders;
  final String responseBody;
  const ClientException(this.statusCode, this.reasonPhrase, this.responseHeaders, this.responseBody);
  String toString() {
    return "DOException { statusCode: ${statusCode}, reasonPhrase: \"${reasonPhrase}\", responseBody: \"${responseBody}\" }";
  }
}

class Client {
  http.Client _httpClient;
  final String region;
  final String accessKey;
  final String secretKey;
  final String endpointUrl;
  Client({
    @required this.region,
    @required this.accessKey,
    @required this.secretKey,
    @required this.endpointUrl,
    http.Client httpClient
  }) {
    assert(region != null);
    assert(accessKey != null);
    assert(secretKey != null);
    assert(endpointUrl != null);
    _httpClient = httpClient == null ? new http.ConsoleClient() : httpClient;
  }

  /// List all existing buckets in a region.
  /// https://developers.digitalocean.com/documentation/spaces/#list-all-buckets
  Future<List<String>> listAllBuckets() async {
    xml.XmlDocument doc = await _getUri(Uri.parse(endpointUrl + '/'));
    List<String> res = new List<String>();
    for (xml.XmlElement root in doc.findElements('ListAllMyBucketsResult')) {
      for (xml.XmlElement buckets in root.findElements('Buckets')) {
        for (xml.XmlElement bucket in buckets.findElements('Bucket')) {
          for (xml.XmlElement name in bucket.findElements('Name')) {
            res.add(name.text);
          }
        }
      }
    }
    return res;
  }

  /// List a Bucket's Contents.
  /// TODO: Manage markers and provide async iterator interface
  /// https://developers.digitalocean.com/documentation/spaces/#list-bucket-contents
  Future<ListBucketResult> listBucketContents({
    String delimiter, String marker, String maxKeys, String prefix
  }) async {
    Uri uri = Uri.parse(endpointUrl + '/');
    Map<String, dynamic> params;
    if (delimiter != null) params['delimiter'] = delimiter;
    if (marker != null) params['marker'] = marker;
    if (maxKeys != null) params['max-keys'] = maxKeys;
    if (prefix != null) params['prefix'] = prefix;
    uri = uri.replace(queryParameters: params);
    xml.XmlDocument doc = await _getUri(uri);
    String name;
    String prefix_;
    String marker_;
    String nextMarker;
    String maxKeys_;
    bool isTruncated;
    List<ListBucketContents> contents = new List<ListBucketContents>();
    for (xml.XmlElement root in doc.findElements('ListBucketResult')) {
      for (xml.XmlNode node in root.children) {
        if (node is xml.XmlElement) {
          xml.XmlElement ele = node;
          switch ('${ele.name}') {
            case "Name": print(ele.text); name = ele.text; break;
            case "Prefix": prefix_ = ele.text; break;
            case "Marker": marker_ = ele.text; break;
            case "NextMarker": nextMarker = ele.text; break;
            case "MaxKeys": maxKeys_ = ele.text; break;
            case "IsTruncated": isTruncated = ele.text.toLowerCase() != "false" && ele.text != "0"; break;
            case "Contents":
              String key;
              DateTime lastModifiedUtc;
              String eTag;
              int size;
              for (xml.XmlNode node in ele.children) {
                if (node is xml.XmlElement) {
                  xml.XmlElement ele = node;
                  switch ('${ele.name}') {
                    case "Key": key = ele.text; break;
                    case "LastModified": lastModifiedUtc = DateTime.parse(ele.text); break;
                    case "ETag": eTag = ele.text; break;
                    case "Size": size = int.parse(ele.text); break;
                  }
                }
              }
              contents.add(new ListBucketContents(
                key: key, 
                lastModifiedUtc: lastModifiedUtc,
                eTag: eTag,
                size: size,
              ));  
              break;
          }
        }
      }
    }
    return new ListBucketResult(
      name: name,
      prefix: prefix_,
      marker: marker_,
      nextMarker: nextMarker,
      maxKeys: maxKeys_,
      isTruncated: isTruncated,
      contents: contents,
    );
  }

  Future<xml.XmlDocument> _getUri(Uri uri) async {
    http.Request request = new http.Request('GET', uri, headers: new http.Headers());
    _signRequest(request);
    http.Response response = await _httpClient.send(request);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await response.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes());
    if (response.statusCode != 200) {
      throw new ClientException(response.statusCode, response.reasonPhrase, response.headers.toSimpleMap(), body);
    }
    xml.XmlDocument doc = xml.parse(body);
    return doc;
  }

  String _uriEncode(String str) {
    return Uri.encodeQueryComponent(str).replaceAll('+', '%20');
  }

  String _trimAll(String str) {
    String res = str.trim();
    int len;
    do {
      len = res.length;
      res = res.replaceAll('  ', ' ');
    } while (res.length != len);
    return res;
  }

  void _signRequest(http.Request request) {
    // Build canonical request
    String httpMethod = request.method;
    String canonicalURI = request.uri.path;
    String host = request.uri.host;
    String service = 's3';

    DateTime date = new DateTime.now().toUtc();
    String dateIso8601 = date.toIso8601String();
    dateIso8601 = dateIso8601.substring(0, dateIso8601.indexOf('.')).replaceAll(':', '').replaceAll('-', '') + 'Z';
    String dateYYYYMMDD = date.year.toString().padLeft(4, '0') + date.month.toString().padLeft(2, '0') + date.day.toString().padLeft(2, '0');

    Digest hashedPayload = sha256.convert(request.bodyBytes == null ? utf8.encode('') : request.bodyBytes); // TODO: Hashed payload bodyStream

    // Build canonical query string
    Map<String, String> queryParameters = request.uri.queryParameters;
    List<String> queryKeys = queryParameters.keys.toList()..sort(); // TODO: Ordinal sort
    String canonicalQueryString = queryKeys.map((s) => '${_uriEncode(s)}=${_uriEncode(queryParameters[s])}').join('&');

    // Build canonical headers string
    Map<String, List<String>> headers = new Map<String, List<String>>();
    request.headers.add('x-amz-date', dateIso8601); // Set date in header
    request.headers.add('x-amz-content-sha256', '$hashedPayload'); // Set payload hash in header
    request.headers.keys.forEach((String name) => (headers[name.toLowerCase()] = request.headers[name]));
    headers['host'] = [ host ]; // Host is a builtin header
    List<String> headerNames = headers.keys.toList()..sort();
    String canonicalHeaders = headerNames.map((s) => (headers[s].map((v) => ('${s}:${_trimAll(v)}')).join('\n') + '\n')).join();

    String signedHeaders = headerNames.join(';');

    // Sign headers
    String canonicalRequest = '${httpMethod}\n${canonicalURI}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n$hashedPayload';
    // print('\n>>>>>> canonical request \n' + canonicalRequest + '\n<<<<<<\n');

    Digest canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)); //_hmacSha256.convert(utf8.encode(canonicalRequest));

    String stringToSign = 'AWS4-HMAC-SHA256\n${dateIso8601}\n${dateYYYYMMDD}/${region}/${service}/aws4_request\n$canonicalRequestHash';
    // print('\n>>>>>> string to sign \n' + stringToSign + '\n<<<<<<\n');

    Digest dateKey = new Hmac(sha256, utf8.encode("AWS4${secretKey}")).convert(utf8.encode(dateYYYYMMDD));
    Digest dateRegionKey = new Hmac(sha256, dateKey.bytes).convert(utf8.encode(region));
    Digest dateRegionServiceKey = new Hmac(sha256, dateRegionKey.bytes).convert(utf8.encode(service));
    Digest signingKey = new Hmac(sha256, dateRegionServiceKey.bytes).convert(utf8.encode("aws4_request"));

    Digest signature = new Hmac(sha256, signingKey.bytes).convert(utf8.encode(stringToSign));

    String credential = '${accessKey}/${dateYYYYMMDD}/${region}/${service}/aws4_request';

    // Set signature in header
    request.headers.add('Authorization', 'AWS4-HMAC-SHA256 Credential=${credential}, SignedHeaders=${signedHeaders}, Signature=$signature');
  }
}
