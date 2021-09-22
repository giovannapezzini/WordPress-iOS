import ScreenObject
import XCTest

public class EditorPublishEpilogueScreen: ScreenObject {

    private static let getDoneButton: (XCUIApplication) -> XCUIElement = {
        $0.navigationBars.buttons["doneButton"]
    }

    private static let getPublishedLabel: (XCUIApplication) -> XCUIElement = {
        $0.staticTexts["publishedPostStatusLabel"]
    }

    private static let getViewButton: (XCUIApplication) -> XCUIElement = {
        $0.buttons["viewPostButton"]
    }

    var doneButton: XCUIElement { Self.getDoneButton(app) }
    var viewButton: XCUIElement { Self.getViewButton(app) }

    public init(app: XCUIApplication = XCUIApplication()) throws {
        try super.init(
            expectedElementGetters: [
                Self.getDoneButton,
                Self.getPublishedLabel,
                Self.getViewButton
            ],
            app: app
        )
    }

    /// - Note: Returns `Void` since the return screen depends on which screen we started from.
    public func done() {
        doneButton.tap()
    }

    public func verifyEpilogueDisplays(postTitle expectedPostTitle: String, siteAddress expectedSiteAddress: String) -> EditorPublishEpilogueScreen {
        let actualPostTitle = app.staticTexts["postTitle"].label
        let actualSiteAddress = app.staticTexts["siteUrl"].label

        XCTAssertEqual(expectedPostTitle, actualPostTitle, "Post title doesn't match expected title")
        XCTAssertEqual(expectedSiteAddress, actualSiteAddress, "Site address doesn't match expected address")

        return self
    }
}
