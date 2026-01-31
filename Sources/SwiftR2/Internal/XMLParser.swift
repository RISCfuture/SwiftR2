import Foundation

/// Parser for S3/R2 XML responses.
enum R2XMLParser {
    /// Parses an error response.
    static func parseError(data: Data, statusCode: Int) -> R2ServiceError {
        guard let xml = try? XMLDocument(data: data) else {
            return R2ServiceError(
                code: "UnknownError",
                message: "Failed to parse error response",
                statusCode: statusCode
            )
        }

        let code = xml.rootElement()?.elements(forName: "Code").first?.stringValue ?? "UnknownError"
        let message = xml.rootElement()?.elements(forName: "Message").first?.stringValue ?? "Unknown error"
        let requestId = xml.rootElement()?.elements(forName: "RequestId").first?.stringValue
        let resource = xml.rootElement()?.elements(forName: "Resource").first?.stringValue

        return R2ServiceError(
            code: code,
            message: message,
            statusCode: statusCode,
            requestId: requestId,
            resource: resource
        )
    }

    /// Parses a ListObjectsV2 response.
    static func parseListObjectsV2(data: Data) throws -> R2ListObjectsResult {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement() else {
            throw R2Error.invalidResponse(message: "Failed to parse ListObjectsV2 response")
        }

        let isTruncated = root.elements(forName: "IsTruncated").first?.stringValue == "true"
        let nextToken = root.elements(forName: "NextContinuationToken").first?.stringValue
        let prefix = root.elements(forName: "Prefix").first?.stringValue
        let delimiter = root.elements(forName: "Delimiter").first?.stringValue
        let maxKeys = Int(root.elements(forName: "MaxKeys").first?.stringValue ?? "1000") ?? 1000
        let keyCount = Int(root.elements(forName: "KeyCount").first?.stringValue ?? "0") ?? 0

        var objects: [R2ListObject] = []
        for content in root.elements(forName: "Contents") {
            guard let key = content.elements(forName: "Key").first?.stringValue else { continue }

            let size = Int64(content.elements(forName: "Size").first?.stringValue ?? "0") ?? 0
            let etag = content.elements(forName: "ETag").first?.stringValue?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
            let lastModifiedString = content.elements(forName: "LastModified").first?.stringValue ?? ""
            let lastModified = parseISO8601Date(lastModifiedString) ?? Date()
            let storageClassString = content.elements(forName: "StorageClass").first?.stringValue ?? "STANDARD"
            let storageClass = StorageClass(rawValue: storageClassString) ?? .standard

            objects.append(R2ListObject(
                key: key,
                size: size,
                etag: etag,
                lastModified: lastModified,
                storageClass: storageClass
            ))
        }

        var commonPrefixes: [R2CommonPrefix] = []
        for prefixElement in root.elements(forName: "CommonPrefixes") {
            if let prefix = prefixElement.elements(forName: "Prefix").first?.stringValue {
                commonPrefixes.append(R2CommonPrefix(prefix: prefix))
            }
        }

        return R2ListObjectsResult(
            objects: objects,
            commonPrefixes: commonPrefixes,
            isTruncated: isTruncated,
            nextContinuationToken: nextToken,
            prefix: prefix,
            delimiter: delimiter,
            maxKeys: maxKeys,
            keyCount: keyCount
        )
    }

    /// Parses a CreateMultipartUpload response.
    static func parseCreateMultipartUpload(data: Data) throws -> R2CreateMultipartUploadResult {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement() else {
            throw R2Error.invalidResponse(message: "Failed to parse CreateMultipartUpload response")
        }

        guard let bucket = root.elements(forName: "Bucket").first?.stringValue,
              let key = root.elements(forName: "Key").first?.stringValue,
              let uploadId = root.elements(forName: "UploadId").first?.stringValue else {
            throw R2Error.invalidResponse(message: "Missing required fields in CreateMultipartUpload response")
        }

        return R2CreateMultipartUploadResult(bucket: bucket, key: key, uploadId: uploadId)
    }

    /// Parses a CompleteMultipartUpload response.
    static func parseCompleteMultipartUpload(data: Data) throws -> R2CompleteMultipartUploadResult {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement() else {
            throw R2Error.invalidResponse(message: "Failed to parse CompleteMultipartUpload response")
        }

        guard let bucket = root.elements(forName: "Bucket").first?.stringValue,
              let key = root.elements(forName: "Key").first?.stringValue,
              let etag = root.elements(forName: "ETag").first?.stringValue else {
            throw R2Error.invalidResponse(message: "Missing required fields in CompleteMultipartUpload response")
        }

        let location = root.elements(forName: "Location").first?.stringValue

        return R2CompleteMultipartUploadResult(
            bucket: bucket,
            key: key,
            etag: etag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
            location: location
        )
    }

    /// Parses a CopyObject response.
    static func parseCopyObject(data: Data) throws -> R2CopyObjectResult {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement() else {
            throw R2Error.invalidResponse(message: "Failed to parse CopyObject response")
        }

        guard let etag = root.elements(forName: "ETag").first?.stringValue,
              let lastModifiedString = root.elements(forName: "LastModified").first?.stringValue else {
            throw R2Error.invalidResponse(message: "Missing required fields in CopyObject response")
        }

        let lastModified = parseISO8601Date(lastModifiedString) ?? Date()

        return R2CopyObjectResult(
            etag: etag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
            lastModified: lastModified
        )
    }

    /// Parses a DeleteObjects response.
    static func parseDeleteObjects(data: Data) throws -> R2DeleteObjectsResult {
        guard let xml = try? XMLDocument(data: data),
              let root = xml.rootElement() else {
            throw R2Error.invalidResponse(message: "Failed to parse DeleteObjects response")
        }

        var deleted: [R2DeleteObjectsResult.DeletedObject] = []
        for deletedElement in root.elements(forName: "Deleted") {
            guard let key = deletedElement.elements(forName: "Key").first?.stringValue else { continue }
            let versionId = deletedElement.elements(forName: "VersionId").first?.stringValue
            let deleteMarker = deletedElement.elements(forName: "DeleteMarker").first?.stringValue == "true"

            deleted.append(R2DeleteObjectsResult.DeletedObject(
                key: key,
                versionId: versionId,
                deleteMarker: deleteMarker
            ))
        }

        var errors: [R2DeleteObjectsResult.DeleteError] = []
        for errorElement in root.elements(forName: "Error") {
            guard let key = errorElement.elements(forName: "Key").first?.stringValue,
                  let code = errorElement.elements(forName: "Code").first?.stringValue,
                  let message = errorElement.elements(forName: "Message").first?.stringValue else { continue }

            errors.append(R2DeleteObjectsResult.DeleteError(
                key: key,
                code: code,
                message: message
            ))
        }

        return R2DeleteObjectsResult(deleted: deleted, errors: errors)
    }

    /// Parses an ISO 8601 date string.
    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

/// Builds XML for S3/R2 requests.
enum R2XMLBuilder {
    /// Builds DeleteObjects request body.
    static func buildDeleteObjects(keys: [String], quiet: Bool = true) -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        xml += "<Delete>"

        if quiet {
            xml += "<Quiet>true</Quiet>"
        }

        for key in keys {
            xml += "<Object><Key>\(escapeXML(key))</Key></Object>"
        }

        xml += "</Delete>"
        return Data(xml.utf8)
    }

    /// Builds CompleteMultipartUpload request body.
    static func buildCompleteMultipartUpload(parts: [R2CompletedPart]) -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        xml += "<CompleteMultipartUpload>"

        for part in parts.sorted(by: { $0.partNumber < $1.partNumber }) {
            xml += "<Part>"
            xml += "<PartNumber>\(part.partNumber)</PartNumber>"
            xml += "<ETag>\(escapeXML(part.etag))</ETag>"
            xml += "</Part>"
        }

        xml += "</CompleteMultipartUpload>"
        return Data(xml.utf8)
    }

    /// Escapes special characters for XML.
    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
