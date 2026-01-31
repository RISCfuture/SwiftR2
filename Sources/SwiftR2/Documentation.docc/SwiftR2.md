# ``SwiftR2``

A native Swift client for Cloudflare R2 object storage.

## Overview

SwiftR2 provides a modern, Swift-native interface for interacting with Cloudflare R2 storage. It supports all common S3-compatible operations including uploading, downloading, listing, and deleting objects, as well as advanced features like multipart uploads for large files and presigned URLs.

The library is built with Swift concurrency in mind, using `async`/`await` throughout and providing streaming capabilities for efficient memory usage when working with large files.

```swift
import SwiftR2

// Create a client with your R2 credentials
let client = R2Client(
    accountId: "your-account-id",
    accessKeyId: "your-access-key-id",
    secretAccessKey: "your-secret-access-key"
)

// Upload an object
try await client.put("Hello, R2!", bucket: "my-bucket", key: "greeting.txt")

// Download an object
let data = try await client.get(bucket: "my-bucket", key: "greeting.txt")
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``R2Client``
- ``R2ClientConfiguration``

### Authentication

- ``R2Credentials``
- ``CredentialsProvider``
- ``StaticCredentialsProvider``
- ``EnvironmentCredentialsProvider``
- ``ChainedCredentialsProvider``

### Object Operations

- ``R2GetObjectResult``
- ``R2PutObjectResult``
- ``R2ObjectMetadata``
- ``R2CopyObjectResult``

### Listing Objects

- ``R2ListObjectsResult``
- ``R2ListObject``
- ``R2CommonPrefix``
- ``R2DeleteObjectsResult``

### Streaming

- ``R2DownloadStream``
- ``R2UploadSource``
- ``DataUploadSource``
- ``FileUploadSource``
- ``FileHandleAsyncSequence``
- ``FileRangeAsyncSequence``

### Multipart Uploads

- ``MultipartUploadManager``
- ``MultipartUploadConfiguration``
- ``ResumableUploadState``
- ``R2CreateMultipartUploadResult``
- ``R2UploadPartResult``
- ``R2CompletedPart``
- ``R2CompleteMultipartUploadResult``
- ``R2MultipartUpload``
- ``R2Part``

### Storage

- ``StorageClass``

### Error Handling

- ``R2Error``
- ``R2ServiceError``

### Progress Tracking

- ``R2Progress``
- ``R2ProgressHandler``

### Request Signing

- ``AWSSignatureV4``
