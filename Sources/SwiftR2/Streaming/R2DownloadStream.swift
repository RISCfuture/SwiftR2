import Foundation

/// A stream of data chunks from an R2 download.
///
/// Conforms to `AsyncSequence` to allow iterating over data chunks
/// as they arrive from the network. This is more memory-efficient
/// than downloading the entire object at once.
///
/// ```swift
/// let stream = try await client.getObjectStream(bucket: "bucket", key: "large-file.zip")
///
/// print("Content-Length: \(stream.contentLength ?? 0)")
///
/// for try await chunk in stream {
///     // Process each chunk as it arrives
///     try fileHandle.write(contentsOf: chunk)
/// }
/// ```
public struct R2DownloadStream: AsyncSequence, Sendable {
    public typealias Element = Data

    /// The total content length of the object in bytes, if known.
    ///
    /// May be `nil` for chunked transfer encoding.
    public let contentLength: Int64?

    /// The MIME type of the object content.
    public let contentType: String?

    /// The entity tag (ETag) of the object.
    public let etag: String?

    /// When the object was last modified.
    public let lastModified: Date?

    /// Custom metadata associated with the object.
    ///
    /// Keys are returned without the `x-amz-meta-` prefix.
    public let metadata: [String: String]

    private let bytes: URLSession.AsyncBytes
    private let chunkSize: Int

    init(
        bytes: URLSession.AsyncBytes,
        response: HTTPURLResponse,
        chunkSize: Int = 65536
    ) {
        self.bytes = bytes
        self.chunkSize = chunkSize

        // Extract metadata from response headers
        if let contentLengthString = response.value(forHTTPHeaderField: "Content-Length"),
           let contentLength = Int64(contentLengthString) {
            self.contentLength = contentLength
        } else {
            self.contentLength = nil
        }

        self.contentType = response.value(forHTTPHeaderField: "Content-Type")
        self.etag = response.value(forHTTPHeaderField: "ETag")?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        if let lastModifiedString = response.value(forHTTPHeaderField: "Last-Modified") {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            self.lastModified = formatter.date(from: lastModifiedString)
        } else {
            self.lastModified = nil
        }

        // Extract custom metadata (x-amz-meta-* headers)
        var customMetadata: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String,
               keyString.lowercased().hasPrefix("x-amz-meta-"),
               let valueString = value as? String {
                let metaKey = String(keyString.dropFirst("x-amz-meta-".count))
                customMetadata[metaKey] = valueString
            }
        }
        self.metadata = customMetadata
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytes: bytes, chunkSize: chunkSize)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var bytesIterator: URLSession.AsyncBytes.AsyncIterator
        private let chunkSize: Int
        private var buffer: Data
        private var finished: Bool = false

        init(bytes: URLSession.AsyncBytes, chunkSize: Int) {
            self.bytesIterator = bytes.makeAsyncIterator()
            self.chunkSize = chunkSize
            self.buffer = Data()
            self.buffer.reserveCapacity(chunkSize)
        }

        public mutating func next() async throws -> Data? {
            guard !finished else { return nil }

            buffer.removeAll(keepingCapacity: true)

            while buffer.count < chunkSize {
                if let byte = try await bytesIterator.next() {
                    buffer.append(byte)
                } else {
                    finished = true
                    break
                }
            }

            return buffer.isEmpty ? nil : buffer
        }
    }
}

/// Progress information for uploads and downloads.
///
/// Passed to ``R2ProgressHandler`` callbacks during file transfers.
///
/// ```swift
/// try await client.putFile(from: fileURL, bucket: "bucket", key: "key") { progress in
///     if let percent = progress.percentCompleted {
///         print("Progress: \(percent)%")
///     }
/// }
/// ```
public struct R2Progress: Sendable {
    /// The number of bytes transferred so far.
    public let completedBytes: Int64

    /// The total number of bytes to transfer, if known.
    ///
    /// May be `nil` for streams with unknown length.
    public let totalBytes: Int64?

    /// The fraction completed (0.0 to 1.0), if total is known.
    ///
    /// Returns `nil` if ``totalBytes`` is unknown.
    public var fractionCompleted: Double? {
        guard let total = totalBytes, total > 0 else { return nil }
        return Double(completedBytes) / Double(total)
    }

    /// The percentage completed (0 to 100), if total is known.
    ///
    /// Returns `nil` if ``totalBytes`` is unknown.
    public var percentCompleted: Int? {
        guard let fraction = fractionCompleted else { return nil }
        return Int(fraction * 100)
    }

    /// Creates a new progress value.
    ///
    /// - Parameters:
    ///   - completedBytes: Bytes transferred so far.
    ///   - totalBytes: Total bytes to transfer, if known.
    public init(completedBytes: Int64, totalBytes: Int64?) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }
}

/// A closure that receives progress updates during file transfers.
///
/// Used with methods like ``R2Client/putFile(from:bucket:key:contentType:metadata:progress:)``
/// and ``R2Client/getFile(bucket:key:to:progress:)``.
public typealias R2ProgressHandler = @Sendable (R2Progress) -> Void
