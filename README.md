# DOSpace

Client library to interact with the DigitalOcean Spaces API.

## Usage

A simple usage example:

```
import 'dart:async';
import 'package:dospace/dospace.dart' as dospace;

main() async {
  dospace.Spaces spaces = new dospace.Spaces(
    region: "nyc3",
    accessKey: "7Q7GAFJ4IXHQVLBRXSRX",
    secretKey: "2JLXa9RqPwpavBkC7dt1MHWUDfd6onaXTXTfSYc5eQ0",
  );
  for (String name in await spaces.listAllBuckets()) {
    print('bucket: ${name}');
    dospace.Bucket bucket = spaces.bucket(name);
    await for (dospace.BucketContent content in bucket.listContents(maxKeys: 3)) {
       print('key: ${content.key}');
    }
  }
  String etag = await spaces.bucket('example').uploadFile(
    'README.md', 'README.md', 'text/plain', dospace.Permissions.public);
  print('upload: $etag');
  await spaces.close();
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
