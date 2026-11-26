import XCTest
@testable import AMSTracking

/// One small test per rule of the core (lean, Martin's rule 9 Nov 2026).
final class CoreTests: XCTestCase {
    func testPlaceholder() { XCTAssertEqual(Fmt.duration(16 * 3_600_000 + 5 * 60_000), "16:05") }
}
