import XCTest

private struct ElementStringIDs {
    static let passwordOption = "Use Password"
    static let mailButton = "Open Mail Button"
}

public class LoginCheckMagicLinkScreen: BaseScreen {
    let passwordOption: XCUIElement
    let mailButton: XCUIElement
    let mailAlert: XCUIElement

    init() {
        let app = XCUIApplication()
        passwordOption = app.buttons[ElementStringIDs.passwordOption]
        mailButton = app.buttons[ElementStringIDs.mailButton]
        mailAlert = app.alerts.element(boundBy: 0)

        super.init(element: mailButton)
    }

    func proceedWithPassword() -> LoginPasswordScreen {
        passwordOption.tap()

        return LoginPasswordScreen()
    }

    public func openMagicLoginLink() -> LoginEpilogueScreen {
        openMagicLink()

        return LoginEpilogueScreen()
    }

    public static func isLoaded() -> Bool {
        return XCUIApplication().buttons[ElementStringIDs.mailButton].exists
    }
}
