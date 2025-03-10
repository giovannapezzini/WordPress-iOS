import XCTest

private struct ElementStringIDs {
    static let readerTable = "Reader"
    static let discoverButton = "Discover"
}

public class ReaderScreen: BaseScreen {
    let tabBar: TabNavComponent
    let discoverButton: XCUIElement

    init() {
        let readerTable = XCUIApplication().tables[ElementStringIDs.readerTable]
        tabBar = TabNavComponent()
        discoverButton = XCUIApplication().buttons[ElementStringIDs.discoverButton]

        super.init(element: readerTable)
    }

    public static func isLoaded() -> Bool {
        return XCUIApplication().tables[ElementStringIDs.readerTable].exists
    }

    public func openDiscover() -> ReaderScreen {
        discoverButton.tap()

        return self
    }
}
