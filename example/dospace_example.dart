import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dospace/dospace.dart' as dospace;
import 'package:http/http.dart' as http;

const String region = "nyc3";
const String accessKey = "";
const String secretKey = "";
const String bucketName = "";

main() async {
  dospace.Spaces spaces = new dospace.Spaces(
    region: region,
    accessKey: accessKey,
    secretKey: secretKey,
  );
  for (String name in await spaces.listAllBuckets()) {
    print('bucket: ${name}');
    dospace.Bucket bucket = spaces.bucket(name);
    await for (dospace.BucketContent content
        in bucket.listContents(maxKeys: 3)) {
      print('key: ${content.key}');
    }
  }
  dospace.Bucket bucket = spaces.bucket(bucketName);
  String? etag = await bucket.uploadFile(
      'README.md', 'README.md', 'text/plain', dospace.Permissions.public);
  print('upload: $etag');

  // Basic pre-signed URL
  print('list buckets: ${spaces.preSignListAllBuckets()}');

  // Basic pre-signed upload
  {
    String preSignUrl = bucket.preSignUpload('README.md')!;
    print('upload url: ${preSignUrl}');
    var httpClient = new http.Client();
    var httpRequest = new http.Request('PUT', Uri.parse(preSignUrl));
    http.StreamedResponse httpResponse = await httpClient.send(httpRequest);
    String body = await utf8.decodeStream(httpResponse.stream);
    print('${httpResponse.statusCode} ${httpResponse.reasonPhrase}');
    print(body);
    httpClient.close();
  }

  // Pre-signed upload with specific payload
  {
    var input = new File('README.md');
    int contentLength = await input.length();
    Digest contentSha256 = await sha256.bind(input.openRead()).first;
    String preSignUrl = bucket.preSignUpload('README.md',
        contentLength: contentLength, contentSha256: contentSha256)!;
    print('strict upload url: ${preSignUrl}');
    var httpClient = new http.Client();
    var httpRequest = new http.Request('PUT', Uri.parse(preSignUrl));
    http.StreamedResponse httpResponse = await httpClient.send(httpRequest);
    String body = await utf8.decodeStream(httpResponse.stream);
    print('${httpResponse.statusCode} ${httpResponse.reasonPhrase}');
    print(body);
    httpClient.close();
  }

  print('done');
}
