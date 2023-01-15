import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dospace/dospace.dart' as dospace;
import 'package:ini/ini.dart' as ini;
import 'package:mime/mime.dart';
import 'package:test/test.dart';

dospace.Spaces? spaces;
dospace.Bucket? bucket;

Future<void> main() async {
  List<String> lines = await new File("test/test.ini").readAsLines();
  ini.Config cfg = new ini.Config.fromStrings(lines);

  setUp(() async {
    spaces = new dospace.Spaces(
      region: cfg.get("section", "region"),
      accessKey: cfg.get("section", "accessKey"),
      secretKey: cfg.get("section", "secretKey"),
    );
    bucket = spaces!.bucket(cfg.get("section", "bucketName"));
  });

  tearDown(() async {
    await spaces!.close();
    bucket = null;
    spaces = null;
  });

  test("Bucket is in Spaces", () async {
    List<String> buckets = await spaces!.listAllBuckets();
    expect(buckets, contains(cfg.get("section", "bucketName")));
  });

  test("Upload file", () async {
    String? etag = await bucket!.uploadFile(
        "dospace_test.dart",
        File("test/dospace_test.dart"),
        lookupMimeType(File("test/dospace_test.dart").path)!,
        dospace.Permissions.public);
    expect(etag, isNotEmpty);
  }, timeout: Timeout(Duration(seconds: 20)));

  test("Delete file", () async {
    bool etag = await bucket!.deleteFile('dospace_test.dart');
    expect(etag, isTrue);
  });

  test("Upload binary data", () async {
    Uint8List data = new Uint8List.fromList(
        await new File("test/dospace_test.dart").readAsBytes());
    Digest contentSha256 = sha256.convert(data);
    String key = "test/user/1/$contentSha256.dart";
    bucket!.uploadData(key, data, "text/plain", dospace.Permissions.public,
        contentSha256: contentSha256);
  });
}
