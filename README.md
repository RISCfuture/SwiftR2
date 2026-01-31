# SwiftR2

[![Build and Test](https://github.com/riscfuture/SwiftR2/actions/workflows/tests.yml/badge.svg)](https://github.com/riscfuture/SwiftR2/actions/workflows/tests.yml)
[![Documentation](https://github.com/riscfuture/SwiftR2/actions/workflows/documentation.yml/badge.svg)](https://riscfuture.github.io/SwiftR2/)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS-blue.svg)](https://swift.org)

A native Swift client for Cloudflare R2 object storage with full async/await
support and streaming capabilities.

## Features

- 🚀 **Swift Concurrency**: Built entirely with async/await for modern Swift apps
- 📦 **Complete S3 API**: Upload, download, list, copy, and delete objects
- 🔄 **Streaming Support**: Memory-efficient streaming for large file transfers
- 📤 **Multipart Uploads**: Automatic chunking with parallel uploads and resume capability
- 🔐 **Presigned URLs**: Generate temporary access URLs for sharing
- ⚡ **Actor-Based**: Thread-safe client using Swift actors
- 🔑 **Flexible Auth**: Multiple credential providers including environment variables

## Installation

### Swift Package Manager

Add SwiftR2 to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/riscfuture/SwiftR2.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

### Creating a Client

```swift
import SwiftR2

// Simple initialization with static credentials
let client = R2Client(
    accountId: "your-account-id",
    accessKeyId: "your-access-key-id",
    secretAccessKey: "your-secret-access-key"
)

// Or use environment variables (recommended for production)
let client = R2Client(
    configuration: R2ClientConfiguration(
        accountId: "your-account-id",
        credentialsProvider: EnvironmentCredentialsProvider()
    )
)
```

Set environment variables `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` with
your credentials from the Cloudflare dashboard.

### Uploading Objects

```swift
// Upload a string
try await client.put("Hello, R2!", bucket: "my-bucket", key: "greeting.txt")

// Upload binary data
let imageData = try Data(contentsOf: imageURL)
try await client.put(
    imageData,
    bucket: "my-bucket",
    key: "images/photo.jpg",
    contentType: "image/jpeg"
)

// Upload a file (automatically uses multipart for large files)
try await client.putFile(
    from: localFileURL,
    bucket: "my-bucket",
    key: "documents/report.pdf"
) { progress in
    print("Progress: \(progress.percentCompleted ?? 0)%")
}
```

### Downloading Objects

```swift
// Download as Data
let data = try await client.get(bucket: "my-bucket", key: "file.txt")

// Download as String
let text = try await client.getString(bucket: "my-bucket", key: "file.txt")

// Download to file with progress
try await client.getFile(
    bucket: "my-bucket",
    key: "large-file.zip",
    to: localDestinationURL
) { progress in
    print("Downloaded: \(progress.completedBytes) bytes")
}

// Stream large files
let stream = try await client.getObjectStream(bucket: "my-bucket", key: "huge.zip")
for try await chunk in stream {
    // Process each chunk without loading entire file into memory
}
```

### Listing Objects

```swift
// List all objects
let result = try await client.listObjects(bucket: "my-bucket")
for object in result.objects {
    print("\(object.key): \(object.size) bytes")
}

// List with prefix (folder-like)
let result = try await client.listObjects(
    bucket: "my-bucket",
    prefix: "images/",
    delimiter: "/"
)

// Paginate through large buckets
var token: String? = nil
repeat {
    let result = try await client.listObjects(
        bucket: "my-bucket",
        continuationToken: token
    )
    for object in result.objects {
        print(object.key)
    }
    token = result.nextContinuationToken
} while token != nil
```

### Deleting Objects

```swift
// Delete single object
try await client.deleteObject(bucket: "my-bucket", key: "old-file.txt")

// Bulk delete
let result = try await client.deleteObjects(
    bucket: "my-bucket",
    keys: ["file1.txt", "file2.txt", "file3.txt"]
)
print("Deleted \(result.deleted.count) objects")
```

### Copying Objects

```swift
try await client.copyObject(
    sourceBucket: "source-bucket",
    sourceKey: "original.txt",
    destBucket: "dest-bucket",
    destKey: "copy.txt"
)
```

## Advanced Features

### Presigned URLs

Generate temporary URLs for unauthenticated access:

```swift
// Download URL (default 1 hour expiration)
let downloadURL = try await client.presignedGetURL(
    bucket: "my-bucket",
    key: "file.pdf"
)

// Upload URL
let uploadURL = try await client.presignedPutURL(
    bucket: "my-bucket",
    key: "uploads/new-file.pdf",
    contentType: "application/pdf",
    expiration: 3600  // 1 hour
)
```

### Multipart Uploads

For fine-grained control over large file uploads:

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

### Resumable Uploads

Save and resume interrupted uploads:

```swift
// Save state to resume later
let stateData = try state.encoded()
UserDefaults.standard.set(stateData, forKey: "upload-state")

// Resume from saved state
let savedData = UserDefaults.standard.data(forKey: "upload-state")!
let state = try ResumableUploadState.decode(from: savedData)
let result = try await manager.resume(
    state: state,
    source: FileUploadSource(fileURL: fileURL)
)
```

### Custom Credential Providers

```swift
// Chain multiple providers
let provider = ChainedCredentialsProvider(providers: [
    EnvironmentCredentialsProvider(),
    StaticCredentialsProvider(accessKeyId: "fallback", secretAccessKey: "key")
])

// Implement your own
struct KeychainCredentialsProvider: CredentialsProvider {
    func credentials() async throws -> R2Credentials {
        // Fetch from keychain
    }
}
```

## Error Handling

```swift
do {
    let data = try await client.get(bucket: "my-bucket", key: "file.txt")
} catch R2Error.notFound(let bucket, let key) {
    print("Object not found: \(bucket)/\(key ?? "")")
} catch R2Error.accessDenied(let message) {
    print("Access denied: \(message)")
} catch R2Error.rateLimited(let retryAfter) {
    if let delay = retryAfter {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        // Retry...
    }
} catch R2Error.networkError(let message) {
    print("Network error: \(message)")
} catch {
    print("Error: \(error)")
}
```

## Limitations

- **Bucket Operations**: Creating, deleting, and listing buckets is not
  supported. Use the Cloudflare dashboard or Wrangler CLI for bucket management.
- **Object Versioning**: While version IDs are returned when available,
  version-specific operations are not fully implemented.
- **Object Locking**: Object lock and legal hold features are not supported.
- **Lifecycle Rules**: Lifecycle configuration is managed through Cloudflare,
  not this client.
- **Access Control**: R2 uses Cloudflare's access control; S3-style ACLs are
  not supported.
- **Server-Side Encryption**: R2 encrypts all data at rest automatically;
  client-managed keys are not supported.

## Documentation

Full API documentation is available at:

- [API Reference](https://riscfuture.github.io/SwiftR2/documentation/swiftr2/)
- [Getting Started Guide](https://riscfuture.github.io/SwiftR2/documentation/swiftr2/gettingstarted)

## Testing

Run the test suite:

```bash
swift test
```

## Requirements

- Swift 6.0+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+

## License

SwiftR2 is available under the MIT license. See the LICENSE file for details.
