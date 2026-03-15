import XCTest

/// UI tests for GitHubExplorer.
/// These run against the live app (real API), so they use `waitForExistence`
/// to handle network latency and the 1.8s splash screen.
final class GitHubExplorerUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    // MARK: - List View
    
    @MainActor
    func testNavigationTitleIsExplore() {
        let navTitle = app.navigationBars["Explore"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 10), "Navigation bar should show 'Explore'")
    }
    
    @MainActor
    func testFavoritesToggleButtonExists() {
        let navBar = app.navigationBars["Explore"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        
        let favButton = navBar.buttons.matching(
            NSPredicate(format: "label CONTAINS 'favorites' OR label CONTAINS 'favourites'")
        ).firstMatch
        XCTAssertTrue(favButton.exists, "Toolbar should have a favorites toggle button")
    }
    
    @MainActor
    func testGroupingMenuButtonExists() {
        let navBar = app.navigationBars["Explore"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10))
        
        let groupButton = navBar.buttons["Group repositories"]
        XCTAssertTrue(groupButton.exists, "Toolbar should have a grouping menu button")
    }
}
