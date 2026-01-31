import Foundation

/// A source for upload data.
///
/// Implement this protocol to provide data for streaming uploads.
/// SwiftR2 includes two built-in implementations:
/// - ``DataUploadSource``: Upload from in-memory data
/// - ``FileUploadSource``: Upload from a file on disk
///
/// ## Implementing a Custom Source
///
/// ```swift
/// struct NetworkUploadSource: R2UploadSource {
///     let contentLength: Int64? = nil  // Unknown length
///     let contentType: String? = "application/octet-stream"
///
///     func chunks() -> AsyncThrowingStream<Data, any Error> {
///         AsyncThrowingStream { continuation in
///             // Yield chunks as they become available
///             continuation.yield(data)
///             continuation.finish()
///         }
///     }
/// }
/// ```
public protocol R2UploadSource: Sendable {
    /// The total content length in bytes, if known in advance.
    ///
    /// Providing this enables progress tracking and content-length headers.
    var contentLength: Int64? { get }

    /// The MIME type of the content.
    ///
    /// Used to set the Content-Type header on upload.
    var contentType: String? { get }

    /// Returns an async stream of data chunks.
    ///
    /// Each chunk should be a reasonable size (e.g., 64KB-1MB).
    /// The stream should complete when all data has been yielded.
    func chunks() -> AsyncThrowingStream<Data, any Error>
}

/// An upload source backed by in-memory data.
///
/// Use this to upload data that's already loaded in memory.
/// For large files, prefer ``FileUploadSource`` to avoid memory pressure.
///
/// ```swift
/// let source = DataUploadSource(
///     data: imageData,
///     contentType: "image/jpeg"
/// )
/// try await client.putObjectStream(bucket: "bucket", key: "image.jpg", source: source)
/// ```
public struct DataUploadSource: R2UploadSource {
    private let data: Data
    private let chunkSize: Int

    /// The MIME type of the content.
    public let contentType: String?

    /// The total content length in bytes.
    public var contentLength: Int64? {
        Int64(data.count)
    }

    /// Creates a data upload source.
    ///
    /// - Parameters:
    ///   - data: The data to upload.
    ///   - contentType: The MIME type of the content.
    ///   - chunkSize: The size of chunks to yield in bytes. Defaults to 1MB.
    public init(data: Data, contentType: String? = nil, chunkSize: Int = 1024 * 1024) {
        self.data = data
        self.contentType = contentType
        self.chunkSize = chunkSize
    }

    public func chunks() -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                let chunk = data[offset..<end]
                continuation.yield(Data(chunk))
                offset = end
            }
            continuation.finish()
        }
    }
}

/// An upload source backed by a file on disk.
///
/// Reads the file in chunks to minimize memory usage. The content type
/// is automatically inferred from the file extension if not specified.
///
/// ```swift
/// let source = try FileUploadSource(fileURL: localFileURL)
/// try await client.putObjectStream(bucket: "bucket", key: "file.pdf", source: source)
/// ```
public struct FileUploadSource: R2UploadSource {
    private let fileURL: URL
    private let chunkSize: Int

    /// The total file size in bytes.
    public let contentLength: Int64?

    /// The MIME type of the content.
    ///
    /// Automatically inferred from the file extension if not specified.
    public let contentType: String?

    /// Creates a file upload source.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to upload.
    ///   - contentType: The MIME type. If `nil`, inferred from file extension.
    ///   - chunkSize: The size of chunks to read in bytes. Defaults to 1MB.
    /// - Throws: An error if the file cannot be accessed.
    public init(fileURL: URL, contentType: String? = nil, chunkSize: Int = 1024 * 1024) throws {
        self.fileURL = fileURL
        self.chunkSize = chunkSize

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        self.contentLength = attributes[.size] as? Int64

        // Determine content type
        if let contentType {
            self.contentType = contentType
        } else {
            self.contentType = Self.mimeType(for: fileURL.pathExtension)
        }
    }

    /// Returns the MIME type for a file extension.
    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "txt": return "text/plain"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        case "tar": return "application/x-tar"
        case "gz", "gzip": return "application/gzip"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }

    public func chunks() -> AsyncThrowingStream<Data, any Error> {
        let url = fileURL
        let size = chunkSize

        return AsyncThrowingStream { continuation in
            do {
                let handle = try FileHandle(forReadingFrom: url)

                defer {
                    try? handle.close()
                }

                while true {
                    let chunk = try handle.read(upToCount: size)

                    if let chunk, !chunk.isEmpty {
                        continuation.yield(chunk)
                    } else {
                        break
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
