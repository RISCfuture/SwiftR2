# Getting Started with SwiftR2

Learn how to configure SwiftR2 and perform common operations with Cloudflare R2.

## Overview

SwiftR2 is a Swift-native client for Cloudflare R2 object storage. This guide walks you through the basics of configuring the client and performing common storage operations.

## Adding SwiftR2 to Your Project

Add SwiftR2 as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftR2.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftR2"]
)
```

## Creating a Client

The simplest way to create a client is with static credentials:

```swift
import SwiftR2

let client = R2Client(
    accountId: "your-account-id",
    accessKeyId: "your-access-key-id",
    secretAccessKey: "your-secret-access-key"
)
```

For production applications, consider using environment variables:

```swift
let client = R2Client(
    configuration: R2ClientConfiguration(
        accountId: "your-account-id",
        credentialsProvider: EnvironmentCredentialsProvider()
    )
)
```

Set the environment variables `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` with your credentials.

## Uploading Objects

Upload data directly:

```swift
// Upload a string
try await client.put(
    "Hello, R2!",
    bucket: "my-bucket",
    key: "greeting.txt"
)

// Upload binary data
let imageData = try Data(contentsOf: imageURL)
try await client.put(
    imageData,
    bucket: "my-bucket",
    key: "images/photo.jpg",
    contentType: "image/jpeg"
)
```

Upload files directly from disk:

```swift
let result = try await client.putFile(
    from: localFileURL,
    bucket: "my-bucket",
    key: "documents/report.pdf"
)
```

For large files, the client automatically uses multipart upload for better reliability.

## Downloading Objects

Download objects as data:

```swift
let data = try await client.get(bucket: "my-bucket", key: "greeting.txt")
let text = String(data: data, encoding: .utf8)
```

Download directly to a file:

```swift
try await client.getFile(
    bucket: "my-bucket",
    key: "documents/report.pdf",
    to: localDestinationURL
)
```

For large files, use streaming to avoid loading the entire object into memory:

```swift
let stream = try await client.getObjectStream(bucket: "my-bucket", key: "large-file.zip")

for try await chunk in stream {
    // Process each chunk
    try fileHandle.write(contentsOf: chunk)
}
```

## Listing Objects

List all objects in a bucket:

```swift
let result = try await client.listObjects(bucket: "my-bucket")

for object in result.objects {
    print("\(object.key): \(object.size) bytes")
}
```

Use prefixes to list objects in a "folder":

```swift
let result = try await client.listObjects(
    bucket: "my-bucket",
    prefix: "images/",
    delimiter: "/"
)

// Objects directly in images/
for object in result.objects {
    print("File: \(object.key)")
}

// "Subfolders" in images/
for prefix in result.commonPrefixes {
    print("Folder: \(prefix.prefix)")
}
```

Handle pagination for large buckets:

```swift
var continuationToken: String? = nil

repeat {
    let result = try await client.listObjects(
        bucket: "my-bucket",
        continuationToken: continuationToken
    )

    for object in result.objects {
        print(object.key)
    }

    continuationToken = result.nextContinuationToken
} while continuationToken != nil
```

## Deleting Objects

Delete a single object:

```swift
try await client.deleteObject(bucket: "my-bucket", key: "old-file.txt")
```

Delete multiple objects in one request:

```swift
let result = try await client.deleteObjects(
    bucket: "my-bucket",
    keys: ["file1.txt", "file2.txt", "file3.txt"]
)

print("Deleted \(result.deleted.count) objects")
```

## Copying Objects

Copy an object within or between buckets:

```swift
let result = try await client.copyObject(
    sourceBucket: "source-bucket",
    sourceKey: "original.txt",
    destBucket: "dest-bucket",
    destKey: "copy.txt"
)
```

## Presigned URLs

Generate presigned URLs for temporary access without credentials:

```swift
// URL for downloading (valid for 1 hour by default)
let downloadURL = try await client.presignedGetURL(
    bucket: "my-bucket",
    key: "file.pdf"
)

// URL for uploading (valid for 1 hour by default)
let uploadURL = try await client.presignedPutURL(
    bucket: "my-bucket",
    key: "uploads/new-file.pdf",
    contentType: "application/pdf"
)
```

## Error Handling

SwiftR2 throws ``R2Error`` for operation failures:

```swift
do {
    let data = try await client.get(bucket: "my-bucket", key: "missing.txt")
} catch R2Error.notFound(let bucket, let key) {
    print("Object not found: \(bucket)/\(key ?? "")")
} catch R2Error.accessDenied(let message) {
    print("Access denied: \(message)")
} catch R2Error.networkError(let message) {
    print("Network error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Progress Tracking

Track upload and download progress for large files:

```swift
try await client.putFile(
    from: largeFileURL,
    bucket: "my-bucket",
    key: "large-file.zip"
) { progress in
    if let percent = progress.percentCompleted {
        print("Progress: \(percent)%")
    }
}
```

## Multipart Uploads

For fine-grained control over large file uploads, use ``MultipartUploadManager``:

```swift
let manager = MultipartUploadManager(
    client: client,
    configuration: MultipartUploadConfiguration(
        partSize: 10 * 1024 * 1024,  // 10MB parts
        maxConcurrentUploads: 4
    )
)

let result = try await manager.upload(
    bucket: "my-bucket",
    key: "very-large-file.zip",
    fileURL: localFileURL
) { progress in
    print("Uploaded \(progress.completedBytes) bytes")
}
```

Save and resume interrupted uploads using ``ResumableUploadState``:

```swift
// Save state to resume later
let stateData = try state.encoded()
UserDefaults.standard.set(stateData, forKey: "upload-state")

// Resume from saved state
let savedData = UserDefaults.standard.data(forKey: "upload-state")!
let state = try ResumableUploadState.decode(from: savedData)

let result = try await manager.resume(
    state: state,
    source: FileUploadSource(fileURL: localFileURL)
)
```

## Next Steps

- Learn about ``R2Client`` for the complete API reference
- Explore ``MultipartUploadManager`` for advanced upload scenarios
- See ``R2Error`` for comprehensive error handling
