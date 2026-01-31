import Foundation

/// An async sequence that reads chunks from a file.
///
/// Provides efficient chunk-by-chunk reading of files for streaming uploads.
/// The file is read lazily as the sequence is iterated.
///
/// ```swift
/// let sequence = try FileHandleAsyncSequence(fileURL: fileURL)
/// for try await chunk in sequence {
///     // Process each chunk
/// }
/// ```
public struct FileHandleAsyncSequence: AsyncSequence, Sendable {
    public typealias Element = Data

    /// The URL of the file being read.
    public let fileURL: URL

    /// The size of each chunk in bytes.
    public let chunkSize: Int

    /// The total size of the file in bytes.
    public let fileSize: Int64

    /// Creates a file handle async sequence.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to read.
    ///   - chunkSize: The size of each chunk in bytes. Defaults to 1MB.
    /// - Throws: ``R2Error/invalidRequest(message:)`` if the file cannot be accessed
    ///   or its size cannot be determined.
    public init(fileURL: URL, chunkSize: Int = 1024 * 1024) throws {
        self.fileURL = fileURL
        self.chunkSize = chunkSize

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? Int64 else {
            throw R2Error.invalidRequest(message: "Cannot determine file size")
        }
        self.fileSize = size
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(fileURL: fileURL, chunkSize: chunkSize)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let fileURL: URL
        private let chunkSize: Int
        private var handle: FileHandle?
        private var finished = false

        init(fileURL: URL, chunkSize: Int) {
            self.fileURL = fileURL
            self.chunkSize = chunkSize
        }

        public mutating func next() throws -> Data? {
            guard !finished else { return nil }

            // Open handle lazily
            if handle == nil {
                handle = try FileHandle(forReadingFrom: fileURL)
            }

            guard let handle else {
                finished = true
                return nil
            }

            let chunk = try handle.read(upToCount: chunkSize)

            if let chunk, !chunk.isEmpty {
                return chunk
            }

            try handle.close()
            self.handle = nil
            finished = true
            return nil
        }
    }
}

/// An async sequence that reads a specific byte range from a file.
///
/// Useful for reading specific portions of large files, such as when
/// resuming a partially completed upload.
///
/// ```swift
/// let sequence = FileRangeAsyncSequence(
///     fileURL: fileURL,
///     offset: 1024 * 1024,  // Start at 1MB
///     length: 5 * 1024 * 1024  // Read 5MB
/// )
/// for try await chunk in sequence {
///     // Process each chunk
/// }
/// ```
public struct FileRangeAsyncSequence: AsyncSequence, Sendable {
    public typealias Element = Data

    /// The URL of the file being read.
    public let fileURL: URL

    /// The byte offset to start reading from.
    public let offset: UInt64

    /// The total number of bytes to read.
    public let length: Int

    /// The size of each chunk in bytes.
    public let chunkSize: Int

    /// Creates a file range async sequence.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to read.
    ///   - offset: The byte offset to start reading from.
    ///   - length: The number of bytes to read.
    ///   - chunkSize: The size of each chunk in bytes. Defaults to 1MB.
    public init(
        fileURL: URL,
        offset: UInt64,
        length: Int,
        chunkSize: Int = 1024 * 1024
    ) {
        self.fileURL = fileURL
        self.offset = offset
        self.length = length
        self.chunkSize = chunkSize
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(fileURL: fileURL, offset: offset, length: length, chunkSize: chunkSize)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let fileURL: URL
        private let offset: UInt64
        private let length: Int
        private let chunkSize: Int
        private var handle: FileHandle?
        private var bytesRead: Int = 0
        private var finished = false

        init(fileURL: URL, offset: UInt64, length: Int, chunkSize: Int) {
            self.fileURL = fileURL
            self.offset = offset
            self.length = length
            self.chunkSize = chunkSize
        }

        public mutating func next() throws -> Data? {
            guard !finished, bytesRead < length else {
                if let handle {
                    try handle.close()
                    self.handle = nil
                }
                finished = true
                return nil
            }

            // Open and seek handle lazily
            if handle == nil {
                let h = try FileHandle(forReadingFrom: fileURL)
                try h.seek(toOffset: offset)
                handle = h
            }

            guard let handle else {
                finished = true
                return nil
            }

            let remaining = length - bytesRead
            let toRead = Swift.min(chunkSize, remaining)

            let chunk = try handle.read(upToCount: toRead)

            if let chunk, !chunk.isEmpty {
                bytesRead += chunk.count
                return chunk
            }

            try handle.close()
            self.handle = nil
            finished = true
            return nil
        }
    }
}
