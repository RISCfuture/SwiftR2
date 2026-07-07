import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking

  /// A byte stream mirroring `URLSession.AsyncBytes`.
  ///
  /// swift-corelibs-foundation doesn't implement `URLSession.bytes(for:)`, so this
  /// reimplements the same async byte-streaming behavior on top of
  /// `URLSessionDataDelegate` callbacks.
  struct URLSessionByteStream: AsyncSequence, Sendable {
    typealias Element = UInt8

    private let dataStream: AsyncThrowingStream<Data, Error>

    fileprivate init(dataStream: AsyncThrowingStream<Data, Error>) {
      self.dataStream = dataStream
    }

    func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(dataIterator: dataStream.makeAsyncIterator())
    }

    // A class, not a struct: a `mutating func next()` that awaits a stored
    // `AsyncThrowingStream.AsyncIterator.next()` trips the compiler's data-race
    // checking for `sending` values under `NonisolatedNonsendingByDefault`.
    final class AsyncIterator: AsyncIteratorProtocol, @unchecked Sendable {
      private var dataIterator: AsyncThrowingStream<Data, Error>.AsyncIterator
      private var buffer: [UInt8] = []
      private var bufferIndex = 0

      fileprivate init(dataIterator: AsyncThrowingStream<Data, Error>.AsyncIterator) {
        self.dataIterator = dataIterator
      }

      func next() async throws -> UInt8? {
        while bufferIndex >= buffer.count {
          guard let data = try await dataIterator.next() else { return nil }
          buffer = Array(data)
          bufferIndex = 0
        }
        defer { bufferIndex += 1 }
        return buffer[bufferIndex]
      }
    }
  }

  extension URLSession {
    /// Starts a streaming request, mirroring `URLSession.bytes(for:)` on platforms
    /// where swift-corelibs-foundation doesn't implement it.
    func streamingBytes(for request: URLRequest) async throws -> (URLSessionByteStream, URLResponse)
    {
      let (dataStream, dataContinuation) = AsyncThrowingStream<Data, Error>.makeStream()

      let response = try await withCheckedThrowingContinuation {
        (responseContinuation: CheckedContinuation<URLResponse, Error>) in
        let delegate = ByteStreamDelegate(
          responseContinuation: responseContinuation,
          dataContinuation: dataContinuation
        )
        let streamingSession = URLSession(
          configuration: configuration,
          delegate: delegate,
          delegateQueue: nil
        )
        streamingSession.dataTask(with: request).resume()
        streamingSession.finishTasksAndInvalidate()
      }

      return (URLSessionByteStream(dataStream: dataStream), response)
    }
  }

  /// Forwards a single streaming request's delegate callbacks to Swift concurrency
  /// primitives, bridging `URLSessionDataDelegate` into `URLSession.streamingBytes(for:)`.
  private final class ByteStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var responseContinuation: CheckedContinuation<URLResponse, Error>?
    private let dataContinuation: AsyncThrowingStream<Data, Error>.Continuation

    init(
      responseContinuation: CheckedContinuation<URLResponse, Error>,
      dataContinuation: AsyncThrowingStream<Data, Error>.Continuation
    ) {
      self.responseContinuation = responseContinuation
      self.dataContinuation = dataContinuation
    }

    func urlSession(
      _: URLSession,
      dataTask _: URLSessionDataTask,
      didReceive response: URLResponse,
      completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
      responseContinuation?.resume(returning: response)
      responseContinuation = nil
      completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
      dataContinuation.yield(data)
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
      if let error {
        responseContinuation?.resume(throwing: error)
        responseContinuation = nil
        dataContinuation.finish(throwing: error)
      } else {
        dataContinuation.finish()
      }
    }
  }
#endif
