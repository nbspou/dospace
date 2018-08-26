import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:crypto/crypto.dart';
import 'package:http_client/console.dart' as http;
import 'package:xml/xml.dart' as xml;

class ClientException implements Exception {
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> responseHeaders;
  final String responseBody;
  const ClientException(this.statusCode, this.reasonPhrase,
      this.responseHeaders, this.responseBody);
  String toString() {
    return "DOException { statusCode: ${statusCode}, reasonPhrase: \"${reasonPhrase}\", responseBody: \"${responseBody}\" }";
  }
}

class Client {
  final String region;
  final String accessKey;
  final String secretKey;
  final String service;
  final String endpointUrl;

  @protected
  final http.Client httpClient;

  Client(
      {@required this.region,
      @required this.accessKey,
      @required this.secretKey,
      @required this.service,
      String endpointUrl,
      http.Client httpClient})
      : this.endpointUrl = (endpointUrl == null)
            ? "https://${region}.digitaloceanspaces.com"
            : endpointUrl,
        this.httpClient =
            httpClient == null ? new http.ConsoleClient() : httpClient {
    assert(this.region != null);
    assert(this.accessKey != null);
    assert(this.secretKey != null);
  }

  @protected
  Future<xml.XmlDocument> getUri(Uri uri) async {
    http.Request request =
        new http.Request('GET', uri, headers: new http.Headers());
    signRequest(request);
    http.Response response = await httpClient.send(request);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await response.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes());
    if (response.statusCode != 200) {
      throw new ClientException(response.statusCode, response.reasonPhrase,
          response.headers.toSimpleMap(), body);
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

  @protected
  void signRequest(http.Request request, {Digest contentSha256}) {
    // Build canonical request
    String httpMethod = request.method;
    String canonicalURI = request.uri.path;
    String host = request.uri.host;
    // String service = 's3';

    DateTime date = new DateTime.now().toUtc();
    String dateIso8601 = date.toIso8601String();
    dateIso8601 = dateIso8601
            .substring(0, dateIso8601.indexOf('.'))
            .replaceAll(':', '')
            .replaceAll('-', '') +
        'Z';
    String dateYYYYMMDD = date.year.toString().padLeft(4, '0') +
        date.month.toString().padLeft(2, '0') +
        date.day.toString().padLeft(2, '0');

    Digest hashedPayload = contentSha256 != null
        ? contentSha256
        : (sha256.convert(request.bodyBytes == null
            ? utf8.encode('')
            : request.bodyBytes)); // TODO: Hashed payload bodyStream

    // Build canonical query string
    Map<String, String> queryParameters = request.uri.queryParameters;
    Map<String, String> queryCase = queryParameters.map((s, t) => new MapEntry<String, String>(s.toLowerCase(), s));
    List<String> queryKeys = queryCase.keys.toList()
      ..sort();
    String canonicalQueryString = queryKeys
        .map((s) => '${_uriEncode(queryCase[s])}=${_uriEncode(queryParameters[s])}')
        .join('&');

    // Build canonical headers string
    Map<String, List<String>> headers = new Map<String, List<String>>();
    request.headers.add('x-amz-date', dateIso8601); // Set date in header
    request.headers.add(
        'x-amz-content-sha256', '$hashedPayload'); // Set payload hash in header
    request.headers.keys.forEach(
        (String name) => (headers[name.toLowerCase()] = request.headers[name]));
    headers['host'] = [host]; // Host is a builtin header
    List<String> headerNames = headers.keys.toList()..sort();
    String canonicalHeaders = headerNames
        .map((s) =>
            (headers[s].map((v) => ('${s}:${_trimAll(v)}')).join('\n') + '\n'))
        .join();

    String signedHeaders = headerNames.join(';');

    // Sign headers
    String canonicalRequest =
        '${httpMethod}\n${canonicalURI}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n$hashedPayload';
    // print('\n>>>>>> canonical request \n' + canonicalRequest + '\n<<<<<<\n');

    Digest canonicalRequestHash = sha256.convert(utf8.encode(
        canonicalRequest)); //_hmacSha256.convert(utf8.encode(canonicalRequest));

    String stringToSign =
        'AWS4-HMAC-SHA256\n${dateIso8601}\n${dateYYYYMMDD}/${region}/${service}/aws4_request\n$canonicalRequestHash';
    // print('\n>>>>>> string to sign \n' + stringToSign + '\n<<<<<<\n');

    Digest dateKey = new Hmac(sha256, utf8.encode("AWS4${secretKey}"))
        .convert(utf8.encode(dateYYYYMMDD));
    Digest dateRegionKey =
        new Hmac(sha256, dateKey.bytes).convert(utf8.encode(region));
    Digest dateRegionServiceKey =
        new Hmac(sha256, dateRegionKey.bytes).convert(utf8.encode(service));
    Digest signingKey = new Hmac(sha256, dateRegionServiceKey.bytes)
        .convert(utf8.encode("aws4_request"));

    Digest signature =
        new Hmac(sha256, signingKey.bytes).convert(utf8.encode(stringToSign));

    String credential =
        '${accessKey}/${dateYYYYMMDD}/${region}/${service}/aws4_request';

    // Set signature in header
    request.headers.add('Authorization',
        'AWS4-HMAC-SHA256 Credential=${credential}, SignedHeaders=${signedHeaders}, Signature=$signature');
  }
}
