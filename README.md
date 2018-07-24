# DOSpace

Client library to interact with the DigitalOcean Spaces API.

## Usage

A simple usage example:

```
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
```

## References

* https://developers.digitalocean.com/documentation/spaces/
* https://github.com/agilord/aws_client
* https://github.com/gjersvik/awsdart
* https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
* https://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html
* https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html
* https://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html
