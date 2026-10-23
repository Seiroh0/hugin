import XCTest
import FoundationModels
@testable import Hugin

final class AppleSystemModelTests: XCTestCase {
    func testAvailabilityGuard() throws {
        // API-Abweichung ggü. Brief: isAvailable ist Instanz-Eigenschaft von
        // SystemLanguageModel.default (Apple-Doku), nicht statisch am Typ.
        if SystemLanguageModel.default.isAvailable {
            throw XCTSkip("FM verfügbar – Guard-Test gilt nur für Umgebungen ohne Apple Intelligence (CI)")
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let model = AppleSystemModel(fileTools: FileTools(roots: [Grant(id: UUID(), name: "D", url: tmp)]),
                                      backupDir: tmp, onCard: { _ in }, onFinding: { _ in }, confirm: { _ in true })
        XCTAssertNil(model)
    }
}
