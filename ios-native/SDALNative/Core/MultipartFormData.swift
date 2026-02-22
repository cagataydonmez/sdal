import Foundation

struct MultipartPart {
    let name: String
    let fileName: String?
    let mimeType: String?
    let data: Data
}

enum MultipartFormData {
    static func build(parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for part in parts {
            appendUTF8("--\(boundary)\(lineBreak)", to: &body)
            if let fileName = part.fileName, let mimeType = part.mimeType {
                appendUTF8("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(fileName)\"\(lineBreak)", to: &body)
                appendUTF8("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)", to: &body)
            } else {
                appendUTF8("Content-Disposition: form-data; name=\"\(part.name)\"\(lineBreak)\(lineBreak)", to: &body)
            }
            body.append(part.data)
            appendUTF8(lineBreak, to: &body)
        }

        appendUTF8("--\(boundary)--\(lineBreak)", to: &body)
        return body
    }

    private static func appendUTF8(_ value: String, to body: inout Data) {
        guard let data = value.data(using: .utf8) else { return }
        body.append(data)
    }
}
