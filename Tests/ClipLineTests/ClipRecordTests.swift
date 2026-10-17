import Foundation
import XCTest
@testable import ClipLine

final class ClipRecordTests: XCTestCase {
    func testTextRecordRoundTripsThroughJSON() throws {
        let note = ClipRecord(kind: .text, title: "笔记", text: "hello\nworld")
        let saved = try JSONEncoder().encode(note)
        let loaded = try JSONDecoder().decode(ClipRecord.self, from: saved)
        XCTAssertEqual(loaded.id, note.id)
        XCTAssertEqual(loaded.text, "hello\nworld")
        XCTAssertEqual(loaded.kind, .text)
    }

    func testImageRecordPreservesFilename() throws {
        let image = ClipRecord(kind: .image, title: "截图", imageFilename: "abc.png")
        let result = try JSONDecoder().decode(ClipRecord.self, from: JSONEncoder().encode(image))
        XCTAssertEqual(result.imageFilename, "abc.png")
    }
}
