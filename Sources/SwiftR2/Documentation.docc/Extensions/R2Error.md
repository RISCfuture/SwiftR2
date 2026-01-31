# ``SwiftR2/R2Error``

## Topics

### Object Errors

- ``notFound(bucket:key:)``
- ``bucketNotFound(bucket:)``
- ``objectAlreadyExists(bucket:key:)``

### Authentication Errors

- ``accessDenied(message:)``
- ``missingCredentials(_:)``

### Request Errors

- ``invalidRequest(message:)``
- ``preconditionFailed(message:)``
- ``rateLimited(retryAfter:)``

### Network Errors

- ``networkError(message:)``
- ``invalidResponse(message:)``

### Upload Errors

- ``multipartUploadError(message:)``
- ``uploadAborted(uploadId:)``
- ``checksumMismatch(expected:actual:)``

### Service Errors

- ``serviceError(_:)``
- ``unknown(message:)``
