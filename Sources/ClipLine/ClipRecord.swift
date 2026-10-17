import Foundation

enum ClipKind: String, Codable {
    case image
    case text
}

struct ClipRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipKind
    let createdAt: Date
    var title: String
    var text: String?
    var imageFilename: String?

    init(kind: ClipKind, title: String, text: String? = nil, imageFilename: String? = nil) {
        id = UUID()
        self.kind = kind
        createdAt = Date()
        self.title = title
        self.text = text
        self.imageFilename = imageFilename
    }
}
