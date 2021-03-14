import 'dart:async';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import 'dospace_client.dart';
import 'dospace_bucket.dart';

class Spaces extends Client {
  Spaces(
      {required String? region,
      required String? accessKey,
      required String? secretKey,
      String? endpointUrl,
      http.Client? httpClient})
      : super(
            region: region,
            accessKey: accessKey,
            secretKey: secretKey,
            service: "s3",
            endpointUrl: endpointUrl,
            httpClient: httpClient) {
    // ...
  }

  Bucket bucket(String? bucket) {
    if (endpointUrl == "https://${region}.digitaloceanspaces.com") {
      return new Bucket(
          region: region,
          accessKey: accessKey,
          secretKey: secretKey,
          endpointUrl: "https://${bucket}.${region}.digitaloceanspaces.com",
          httpClient: httpClient);
    } else {
      throw Exception(
          "Endpoint URL not supported. Create Bucket client manually.");
    }
  }

  Future<List<String>> listAllBuckets() async {
    xml.XmlDocument doc = await getUri(Uri.parse(endpointUrl + '/'));
    List<String> res = [];
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

  String? preSignListAllBuckets() {
    http.Request request =
        new http.Request('GET', Uri.parse(endpointUrl + '/'));
    return signRequest(request, preSignedUrl: true);
  }
}
