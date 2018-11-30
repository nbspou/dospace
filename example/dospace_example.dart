import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dospace/dospace.dart' as dospace;
import 'package:http_client/console.dart' as http;

main() async {
  dospace.Spaces spaces = new dospace.Spaces(
    region: "nyc3",
    accessKey: "7Q7GAFJ4IXHQVLBRXSRX",
    secretKey: "2JLXa9RqPwpavBkC7dt1MHWUDfd6onaXTXTfSYc5eQ0",
  );
  for (String name in await spaces.listAllBuckets()) {
    print('bucket: ${name}');
    dospace.Bucket bucket = spaces.bucket(name);
    await for (dospace.BucketContent content
        in bucket.listContents(maxKeys: 3)) {
      print('key: ${content.key}');
    }
  }
  dospace.Bucket bucket = spaces.bucket('example');
  String etag = await bucket.uploadFile(
      'README.md', 'README.md', 'text/plain', dospace.Permissions.public);
  print('upload: $etag');

  // Basic pre-signed URL
  print('list buckets: ${spaces.preSignListAllBuckets()}');

  // Basic pre-signed upload
  {
    String preSignUrl = bucket.preSignUpload('README.md');
    print('upload url: ${preSignUrl}');
    var httpClient = new http.ConsoleClient();
    var httpRequest = new http.Request('PUT', preSignUrl);
    http.Response httpResponse = await httpClient.send(httpRequest);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await httpResponse.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes());
    print('${httpResponse.statusCode} ${httpResponse.reasonPhrase}');
    print(body);
  }

  // Pre-signed upload with specific payload
  {
    var input = new File('README.md');
    int contentLength = await input.length();
    Digest contentSha256 = await sha256.bind(input.openRead()).first;
    String preSignUrl = bucket.preSignUpload('README.md',
        contentLength: contentLength, contentSha256: contentSha256);
    print('strict upload url: ${preSignUrl}');
    var httpClient = new http.ConsoleClient();
    var httpRequest = new http.Request('PUT', preSignUrl);
    http.Response httpResponse = await httpClient.send(httpRequest);
    BytesBuilder builder = new BytesBuilder(copy: false);
    await httpResponse.body.forEach(builder.add);
    String body = utf8.decode(builder.toBytes());
    print('${httpResponse.statusCode} ${httpResponse.reasonPhrase}');
    print(body);
  }

  print('done');
}
