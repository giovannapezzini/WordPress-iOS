import SwiftUI
import UIKit
import WebKit
import WordPressAuthenticator
import WordPressFlux

class RegisterDomainSuggestionsViewController: UIViewController, DomainSuggestionsButtonViewPresenter {

    @IBOutlet weak var buttonContainerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonContainerViewHeightConstraint: NSLayoutConstraint!

    private var site: JetpackSiteRef!
    private var domainPurchasedCallback: ((String) -> Void)!

    private var domain: DomainSuggestion?
    private var siteName: String?
    private var domainsTableViewController: RegisterDomainSuggestionsTableViewController?
    private var domainType: DomainType = .registered

    private var webViewURLChangeObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showButtonView(show: false, withAnimation: false)
    }

    @IBOutlet private var buttonViewContainer: UIView! {
        didSet {
            buttonViewController.move(to: self, into: buttonViewContainer)
        }
    }

    private lazy var buttonViewController: NUXButtonViewController = {
        let buttonViewController = NUXButtonViewController.instance()
        buttonViewController.view.backgroundColor = .basicBackground
        buttonViewController.delegate = self
        buttonViewController.setButtonTitles(
            primary: TextContent.primaryButtonTitle
        )
        return buttonViewController
    }()

    static func instance(site: JetpackSiteRef,
                         domainType: DomainType = .registered,
                         domainPurchasedCallback: @escaping ((String) -> Void)) -> RegisterDomainSuggestionsViewController {
        let storyboard = UIStoryboard(name: Constants.storyboardIdentifier, bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(withIdentifier: Constants.viewControllerIdentifier) as! RegisterDomainSuggestionsViewController
        controller.site = site
        controller.domainType = domainType
        controller.domainPurchasedCallback = domainPurchasedCallback
        controller.siteName = siteNameForSuggestions(for: site)

        return controller
    }

    private static func siteNameForSuggestions(for site: JetpackSiteRef) -> String? {
        if let siteTitle = BlogService.blog(with: site)?.settings?.name?.nonEmptyString() {
            return siteTitle
        }

        if let siteUrl = BlogService.blog(with: site)?.url {
            let components = URLComponents(string: siteUrl)
            if let firstComponent = components?.host?.split(separator: ".").first {
                return String(firstComponent)
            }
        }

        return nil
    }

    private func configure() {
        title = TextContent.title
        WPStyleGuide.configureColors(view: view, tableView: nil)

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel,
                                           target: self,
                                           action: #selector(handleCancelButtonTapped))
        navigationItem.leftBarButtonItem = cancelButton

        let supportButton = UIBarButtonItem(title: TextContent.supportButtonTitle,
                                            style: .plain,
                                            target: self,
                                            action: #selector(handleSupportButtonTapped))
        navigationItem.rightBarButtonItem = supportButton
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let vc = segue.destination as? RegisterDomainSuggestionsTableViewController {
            vc.delegate = self
            vc.siteName = siteName

            if BlogService.blog(with: site)?.hasBloggerPlan == true {
                vc.domainSuggestionType = .allowlistedTopLevelDomains(["blog"])
            }

            domainsTableViewController = vc
        }
    }

    // MARK: - Nav Bar Button Handling

    @objc private func handleCancelButtonTapped(sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @objc private func handleSupportButtonTapped(sender: UIBarButtonItem) {
        let supportVC = SupportTableViewController()
        supportVC.showFromTabBar()
    }

}

// MARK: - DomainSuggestionsTableViewControllerDelegate

extension RegisterDomainSuggestionsViewController: DomainSuggestionsTableViewControllerDelegate {
    func domainSelected(_ domain: DomainSuggestion) {
        WPAnalytics.track(.automatedTransferCustomDomainSuggestionSelected)
        self.domain = domain
        showButtonView(show: true, withAnimation: true)
    }

    func newSearchStarted() {
        WPAnalytics.track(.automatedTransferCustomDomainSuggestionQueried)
        showButtonView(show: false, withAnimation: true)
    }
}

// MARK: - NUXButtonViewControllerDelegate

extension RegisterDomainSuggestionsViewController: NUXButtonViewControllerDelegate {
    func primaryButtonPressed() {
        guard let domain = domain else {
            return
        }
        switch domainType {
        case .registered:
            pushRegisterDomainDetailsViewController(domain)
        case .siteRedirect:
            createCartAndPresentWebView(domain)
        default:
            break
        }
    }

    private func pushRegisterDomainDetailsViewController(_ domain: DomainSuggestion) {
        let controller = RegisterDomainDetailsViewController()
        controller.viewModel = RegisterDomainDetailsViewModel(site: site, domain: domain, domainPurchasedCallback: domainPurchasedCallback)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func createCartAndPresentWebView(_ domain: DomainSuggestion) {
        let proxy = RegisterDomainDetailsServiceProxy()
        proxy.createPersistentDomainShoppingCart(siteID: site.siteID,
                                                 domainSuggestion: domain,
                                                 privacyProtectionEnabled: false,
                                                 success: { [weak self] _ in
            self?.presentWebViewForCurrentSite(domain: domain.domainName)
        },
                                                 failure: { error in })
    }

    static private let checkoutURLPrefix = "https://wordpress.com/checkout"
    static private let checkoutSuccessURLPrefix = "https://wordpress.com/checkout/thank-you/"

    /// Handles URL changes in the web view.  We only allow the user to stay within certain URLs.  Falling outside these URLs
    /// results in the web view being dismissed.  This method also handles the success condition for a successful domain registration
    /// through said web view.
    ///
    /// - Parameters:
    ///     - newURL: the newly set URL for the web view.
    ///     - domain: the domain the user is purchasing.
    ///     - onCancel: the closure that will be executed if we detect the conditions for cancelling the registration were met.
    ///     - onSuccess: the closure that will be executed if we detect a successful domain registration.
    ///
    private func handleWebViewURLChange(
        _ newURL: URL,
        domain: String,
        onCancel: () -> Void,
        onSuccess: () -> Void) {

        let canOpenNewURL = newURL.absoluteString.starts(with: Self.checkoutURLPrefix)

        guard canOpenNewURL else {
            onCancel()
            return
        }

        let domainRegistrationSucceeded = newURL.absoluteString.starts(with: Self.checkoutSuccessURLPrefix)

        if domainRegistrationSucceeded {
            onSuccess()
            return
        }
    }

    private func presentWebViewForCurrentSite(domain: String) {
        guard let siteUrl = URL(string: "\(site.homeURL)"), let host = siteUrl.host,
              let url = URL(string: Constants.checkoutWebAddress + host) else {
            return
        }

        let webViewController = WebViewControllerFactory.controllerWithDefaultAccountAndSecureInteraction(url: url)
        let navController = LightNavigationController(rootViewController: webViewController)

        // WORKAROUND: The reason why we have to use this mechanism to detect success and failure conditions
        // for domain registration is because our checkout process (for some unknown reason) doesn't trigger
        // call to WKWebViewDelegate methods.
        //
        // This was last checked by @diegoreymendez on 2021-09-22.
        //
        webViewURLChangeObservation = webViewController.webView.observe(\.url, options: .new) { [weak self] _, change in
            guard let self = self,
                  let newURL = change.newValue as? URL else {
                return
            }

            self.handleWebViewURLChange(newURL, domain: domain, onCancel: {
                navController.dismiss(animated: true)
            }) {
                self.dismiss(animated: true, completion: { [weak self] in
                    self?.domainPurchasedCallback(domain)
                })
            }
        }

        if let storeSandobxCookie = (HTTPCookieStorage.shared.cookies?.first {

            $0.properties?[.name] as? String == Constants.storeSandboxCookieName &&
            $0.properties?[.domain] as? String == Constants.storeSandboxCookieDomain
        }) {
            // this code will only run if a store sandbox cookie has been set
            let webView = webViewController.webView
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies { [weak self] cookies in

                    var newCookies = cookies
                    newCookies.append(storeSandobxCookie)

                    cookieStore.setCookies(newCookies) {
                        self?.present(navController, animated: true)
                    }
            }
        } else {
            present(navController, animated: true)
        }
    }
}

// MARK: - Constants
extension RegisterDomainSuggestionsViewController {

    enum TextContent {

        static let title = NSLocalizedString("Register domain",
                                             comment: "Register domain - Title for the Suggested domains screen")
        static let primaryButtonTitle = NSLocalizedString("Choose domain",
                                                          comment: "Register domain - Title for the Choose domain button of Suggested domains screen")
        static let supportButtonTitle = NSLocalizedString("Help", comment: "Help button")
    }

    enum Constants {
        // storyboard identifiers
        static let storyboardIdentifier = "RegisterDomain"
        static let viewControllerIdentifier = "RegisterDomainSuggestionsViewController"

        static let checkoutWebAddress = "https://wordpress.com/checkout/"
        // store sandbox cookie
        static let storeSandboxCookieName = "store_sandbox"
        static let storeSandboxCookieDomain = ".wordpress.com"
    }
}
