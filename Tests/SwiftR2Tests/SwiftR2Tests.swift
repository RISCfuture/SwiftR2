import Testing
import Foundation
@testable import SwiftR2

// MARK: - Credentials Tests

@Test
func testStaticCredentialsProvider() throws {
    let provider = StaticCredentialsProvider(
        accessKeyId: "test-access-key",
        secretAccessKey: "test-secret-key"
    )

    let credentials = try provider.credentials()
    #expect(credentials.accessKeyId == "test-access-key")
    #expect(credentials.secretAccessKey == "test-secret-key")
}

@Test
func testR2Credentials() {
    let credentials = R2Credentials(
        accessKeyId: "access",
        secretAccessKey: "secret"
    )

    #expect(credentials.accessKeyId == "access")
    #expect(credentials.secretAccessKey == "secret")
}

// MARK: - Configuration Tests

@Test
func testR2ClientConfiguration() {
    let config = R2ClientConfiguration(
        accountId: "test-account",
        accessKeyId: "access",
        secretAccessKey: "secret"
    )

    #expect(config.accountId == "test-account")
    #expect(config.endpoint.absoluteString == "https://test-account.r2.cloudflarestorage.com")
    #expect(R2ClientConfiguration.region == "auto")
    #expect(R2ClientConfiguration.service == "s3")
}

// MARK: - Error Tests

@Test
func testR2ErrorDescriptions() {
    // Test R2Error with notFound case
    let notFoundError = R2Error.notFound(bucket: "my-bucket", key: "my-key")
    #expect(notFoundError.errorDescription == "Object not found.")
    #expect(notFoundError.failureReason?.contains("my-key") == true)
    #expect(notFoundError.failureReason?.contains("my-bucket") == true)

    // Test R2Error with accessDenied case
    let accessDeniedError = R2Error.accessDenied(message: "Insufficient permissions")
    #expect(accessDeniedError.errorDescription == "Access denied.")
    #expect(accessDeniedError.failureReason?.contains("Insufficient permissions") == true)
    #expect(accessDeniedError.recoverySuggestion != nil)

    // Test R2ServiceError
    let serviceError = R2ServiceError(
        code: "TestError",
        message: "Test message",
        statusCode: 400,
        requestId: "req-123"
    )
    #expect(serviceError.errorDescription == "R2 service error.")
    #expect(serviceError.failureReason?.contains("TestError") == true)
    #expect(serviceError.failureReason?.contains("Test message") == true)
    #expect(serviceError.failureReason?.contains("req-123") == true)
}

// MARK: - Model Tests

@Test
func testStorageClass() {
    #expect(StorageClass.standard.rawValue == "STANDARD")
    #expect(StorageClass.standardIA.rawValue == "STANDARD_IA")
}

@Test
func testR2ObjectMetadata() {
    let metadata = R2ObjectMetadata(
        key: "test.txt",
        size: 1024,
        etag: "abc123",
        lastModified: Date(),
        storageClass: .standard,
        contentType: "text/plain",
        metadata: ["custom": "value"]
    )

    #expect(metadata.key == "test.txt")
    #expect(metadata.size == 1024)
    #expect(metadata.etag == "abc123")
    #expect(metadata.storageClass == .standard)
    #expect(metadata.contentType == "text/plain")
    #expect(metadata.metadata["custom"] == "value")
}

@Test
func testR2ListObject() {
    let obj = R2ListObject(
        key: "folder/file.txt",
        size: 2048,
        etag: "def456",
        lastModified: Date(),
        storageClass: .standardIA
    )

    #expect(obj.key == "folder/file.txt")
    #expect(obj.size == 2048)
    #expect(obj.storageClass == .standardIA)
}

@Test
func testR2Progress() {
    let progress1 = R2Progress(completedBytes: 500, totalBytes: 1000)
    #expect(progress1.fractionCompleted == 0.5)
    #expect(progress1.percentCompleted == 50)

    let progress2 = R2Progress(completedBytes: 500, totalBytes: nil)
    #expect(progress2.fractionCompleted == nil)
    #expect(progress2.percentCompleted == nil)
}

// MARK: - Multipart Configuration Tests

@Test
func testMultipartUploadConfiguration() {
    let config = MultipartUploadConfiguration()
    #expect(config.partSize == 8 * 1024 * 1024)
    #expect(config.maxConcurrentUploads == 4)
    #expect(config.retryFailedParts == true)
    #expect(config.maxRetryAttempts == 3)

    // Test minimum part size enforcement
    let smallConfig = MultipartUploadConfiguration(partSize: 1024)
    #expect(smallConfig.partSize == MultipartUploadConfiguration.minimumPartSize)
}

@Test
func testResumableUploadState() throws {
    let state = ResumableUploadState(
        bucket: "my-bucket",
        key: "my-key",
        uploadId: "upload-123",
        partSize: 8 * 1024 * 1024,
        totalSize: 100_000_000,
        completedParts: [
            R2CompletedPart(partNumber: 1, etag: "etag1"),
            R2CompletedPart(partNumber: 2, etag: "etag2")
        ]
    )

    #expect(state.nextPartNumber == 3)
    #expect(state.bytesUploaded == 2 * 8 * 1024 * 1024)

    // Test encoding and decoding
    let encoded = try state.encoded()
    let decoded = try ResumableUploadState.decode(from: encoded)
    #expect(decoded.bucket == state.bucket)
    #expect(decoded.key == state.key)
    #expect(decoded.uploadId == state.uploadId)
    #expect(decoded.completedParts.count == 2)
}

// MARK: - Upload Source Tests

@Test
func testDataUploadSource() async throws {
    let testData = Data("Hello, World!".utf8)
    let source = DataUploadSource(data: testData, contentType: "text/plain", chunkSize: 5)

    #expect(source.contentLength == 13)
    #expect(source.contentType == "text/plain")

    var chunks: [Data] = []
    for try await chunk in source.chunks() {
        chunks.append(chunk)
    }

    // With chunk size 5, "Hello, World!" (13 bytes) should be split into 3 chunks
    #expect(chunks.count == 3)
    #expect(chunks[0].count == 5)
    #expect(chunks[1].count == 5)
    #expect(chunks[2].count == 3)

    let reassembled = chunks.reduce(Data()) { $0 + $1 }
    #expect(reassembled == testData)
}

// MARK: - Delete Objects Result Tests

@Test
func testDeleteObjectsResult() {
    let deleted = R2DeleteObjectsResult.DeletedObject(
        key: "deleted-file.txt",
        versionId: nil,
        deleteMarker: false
    )
    #expect(deleted.key == "deleted-file.txt")

    let error = R2DeleteObjectsResult.DeleteError(
        key: "failed-file.txt",
        code: "AccessDenied",
        message: "Access denied"
    )
    #expect(error.code == "AccessDenied")

    let result = R2DeleteObjectsResult(
        deleted: [deleted],
        errors: [error]
    )
    #expect(result.deleted.count == 1)
    #expect(result.errors.count == 1)
}

// MARK: - Multipart Models Tests

@Test
func testMultipartUploadModels() {
    let createResult = R2CreateMultipartUploadResult(
        bucket: "bucket",
        key: "key",
        uploadId: "upload-id"
    )
    #expect(createResult.uploadId == "upload-id")

    let uploadPartResult = R2UploadPartResult(
        partNumber: 1,
        etag: "etag-1"
    )
    #expect(uploadPartResult.partNumber == 1)

    let completedPart = R2CompletedPart(
        partNumber: 1,
        etag: "etag-1"
    )
    #expect(completedPart.partNumber == 1)
    #expect(completedPart.etag == "etag-1")
}
