import XCTest
@testable import PROJECT_NAME

final class PROJECT_NAMETests: XCTestCase {
    
    override func setUp() async throws {
        print()
        print("==== \(self.description) ====")
    }
    
    func testSomething() throws {
        let testee = "hello"
        XCTAssertEqual(testee, "hello")
    }
}
