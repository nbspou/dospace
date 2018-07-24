
import 'dart:async';

import 'package:dospace/dospace.dart' as dospace;

Future<List<String>> listAllBuckets() {
  dospace.Client client = new dospace.Client(
    region: "nyc3",
    accessKey: "7Q7GAFJ4IXHQVLBRXSRX",
    secretKey: "2JLXa9RqPwpavBkC7dt1MHWUDfd6onaXTXTfSYc5eQ0",
    endpointUrl: "https://nyc3.digitaloceanspaces.com"
  );
  return client.listAllBuckets();
}

main() async {
  List<String> buckets = await listAllBuckets();
  for (String bucket in buckets) {
    dospace.Client client = new dospace.Client(
      region: "nyc3",
      accessKey: "7Q7GAFJ4IXHQVLBRXSRX",
      secretKey: "2JLXa9RqPwpavBkC7dt1MHWUDfd6onaXTXTfSYc5eQ0",
      endpointUrl: "https://${bucket}.nyc3.digitaloceanspaces.com"
    );
    dospace.ListBucketResult listBucket = await client.listBucketContents();
    print('bucket: ${listBucket.name}');
    print('isTruncated: ${listBucket.isTruncated}');
    for (dospace.ListBucketContents contents in listBucket.contents) {
      print('key: ${contents.key}');
    }
  }
}
