# ``SwiftR2/R2Client``

## Topics

### Creating a Client

- ``init(configuration:)``
- ``init(accountId:accessKeyId:secretAccessKey:)``

### Downloading Objects

- ``getObject(bucket:key:)``
- ``getObjectStream(bucket:key:)``
- ``get(bucket:key:)``
- ``getWithMetadata(bucket:key:)``
- ``getString(bucket:key:encoding:)``
- ``getFile(bucket:key:to:progress:)``

### Uploading Objects

- ``putObject(bucket:key:body:contentType:metadata:)``
- ``putObjectStream(bucket:key:source:metadata:)``
- ``put(_:bucket:key:contentType:metadata:)-(Data,_,_,_,_)``
- ``put(_:bucket:key:contentType:metadata:)-(String,_,_,_,_)``
- ``putFile(from:bucket:key:contentType:metadata:progress:)``

### Object Metadata

- ``headObject(bucket:key:)``

### Listing Objects

- ``listObjects(bucket:prefix:delimiter:maxKeys:continuationToken:)``

### Deleting Objects

- ``deleteObject(bucket:key:)``
- ``deleteObjects(bucket:keys:)``

### Copying Objects

- ``copyObject(sourceBucket:sourceKey:destBucket:destKey:)``

### Multipart Upload

- ``createMultipartUpload(bucket:key:contentType:metadata:)``
- ``uploadPart(bucket:key:uploadId:partNumber:body:)``
- ``completeMultipartUpload(bucket:key:uploadId:parts:)``
- ``abortMultipartUpload(bucket:key:uploadId:)``

### Presigned URLs

- ``presignedGetURL(bucket:key:expiration:)``
- ``presignedPutURL(bucket:key:contentType:expiration:)``
