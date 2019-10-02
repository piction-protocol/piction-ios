//
//  DeepLinkManager.swift
//  piction-ios
//
//  Created by jhseo on 02/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

struct DeepLinkManager {
    static func executeDeepLink(with url: URL) -> Bool {
        // Create a recognizer with this app's custom deep link types.
        let recognizer = DeepLinkRecognizer(deepLinkTypes: [
                LoginDeepLink.self,
                SignupDeepLink.self,
                HomeExploreDeepLink.self,
                SearchDeepLink.self,
                ProjectDeepLink.self,
                ProjectPostsDeepLink.self,
                ProjectSeriesDeepLink.self,
                ProjectInfoDeepLink.self,
                SeriesDeepLink.self,
                ViewerDeepLink.self,
                MySubscriptionDeepLink.self,
                HomeDonationDeepLink.self,
                DonationDeepLink.self,
                DonationQRCodeDeepLink.self,
                DonationPayDeepLink.self,
                DonationLogDeepLink.self,
                MypageDeepLink.self,
                TransactionDeepLink.self,
                WalletDeepLink.self,
                MyinfoDeepLink.self,
                PasswordDeepLink.self
            ]
        )

        var replaceUrlString: String {
            let infoDictionary: [AnyHashable: Any] = Bundle.main.infoDictionary!
            guard let appID: String = infoDictionary["CFBundleIdentifier"] as? String else { return "" }
            let isStaging = appID == "com.pictionnetwork.piction-test"

            if isStaging {
                return url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "piction://", with: "piction-test://", options: NSString.CompareOptions.literal, range: nil)
            } else {
                return url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let replaceUrl = URL(string: replaceUrlString) else { return false }

        // Try to create a deep link object based on the URL.
        guard let deepLink = recognizer.deepLink(matching: replaceUrl) else {
//            print("Unable to match URL: \(url.absoluteString)")

            if replaceUrlString.range(of: "piction://") == nil && replaceUrlString.range(of: "piction-test://") == nil {
                UIApplication.shared.openURL(replaceUrl)
            }
            return false
        }

        // Navigate to the view or content specified by the deep link.
        switch deepLink {
        case let link as LoginDeepLink: return showLogin(with: link)
        case let link as SignupDeepLink: return showSignup(with: link)
        case let link as HomeExploreDeepLink: return showHomeExplore(with: link)
        case let link as SearchDeepLink: return showSearch(with: link)
        case let link as ProjectDeepLink: return showProject(with: link)
        case let link as ProjectPostsDeepLink: return showProjectPosts(with: link)
        case let link as ProjectSeriesDeepLink: return showProjectSeries(with: link)
        case let link as ProjectInfoDeepLink: return showProjectInfo(with: link)
        case let link as SeriesDeepLink: return showSeries(with: link)
        case let link as ViewerDeepLink: return showViewer(with: link)
        case let link as MySubscriptionDeepLink: return showMySubscription(with: link)
        case let link as HomeDonationDeepLink: return showHomeDonation(with: link)
        case let link as DonationDeepLink: return showDonation(with: link)
        case let link as DonationQRCodeDeepLink: return showDonationQRCode(with: link)
        case let link as DonationPayDeepLink: return showDonationPay(with: link)
        case let link as DonationLogDeepLink: return showDonationLog(with: link)
        case let link as MypageDeepLink: return showMypage(with: link)
        case let link as TransactionDeepLink: return showTransaction(with: link)
        case let link as WalletDeepLink: return showWallet(with: link)
        case let link as MyinfoDeepLink: return showMyinfo(with: link)
        case let link as PasswordDeepLink: return showPassword(with: link)
        default: fatalError("Unsupported DeepLink: \(type(of: deepLink))")
        }
    }

    static func showLogin(with deepLink: LoginDeepLink) -> Bool {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
            return true
        }
        return false
    }

    static func showSignup(with deepLink: SignupDeepLink) -> Bool {
        let vc = SignUpViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
            return true
        }
        return false
    }

    static func showHomeExplore(with deepLink: HomeExploreDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.explore, toRoot: true)
            return true
        }
        return false
    }

    static func showSearch(with deepLink: SearchDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.explore, toRoot: true)

            if let topViewController = UIApplication.topViewController() {
                if topViewController is ExplorerViewController {
                    if let vc = topViewController as? ExplorerViewController {
                        vc.openSearchBar()
                        return true
                    }
                }
            }
        }
        return false
    }

    static func showProject(with deepLink: ProjectDeepLink) -> Bool {
        let vc = ProjectViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showProjectPosts(with deepLink: ProjectPostsDeepLink) -> Bool {
        let vc = ProjectViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)

            if let topViewController = UIApplication.topViewController() {
                if topViewController is ProjectViewController {
                    if let vc = topViewController as? ProjectViewController {
                        vc.postBtnDidTap()
                        return true
                    }
                }
            }
        }
        return false
    }

    static func showProjectSeries(with deepLink: ProjectSeriesDeepLink) -> Bool {
        let vc = ProjectViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)

            if let topViewController = UIApplication.topViewController() {
                if topViewController is ProjectViewController {
                    if let vc = topViewController as? ProjectViewController {
                        vc.seriesBtnDidTap()
                        return true
                    }
                }
            }
        }
        return false
    }

    static func showProjectInfo(with deepLink: ProjectInfoDeepLink) -> Bool {
        let vc = ProjectInfoViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showSeries(with deepLink: SeriesDeepLink) -> Bool {
        let vc = SeriesPostViewController.make(uri: deepLink.uri ?? "", seriesId: deepLink.seriesId ?? 0)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showViewer(with deepLink: ViewerDeepLink) -> Bool {
        let vc = PostViewController.make(uri: deepLink.uri ?? "", postId: deepLink.postId ?? 0)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showMySubscription(with deepLink: MySubscriptionDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.subscription, toRoot: true)
            return true
        }
        return false
    }

    static func showHomeDonation(with deepLink: HomeDonationDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.sponsorship, toRoot: true)
            return true
        }
        return false
    }

    static func showDonation(with deepLink: DonationDeepLink) -> Bool {
        let vc = SearchSponsorViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showDonationQRCode(with deepLink: DonationQRCodeDeepLink) -> Bool {
        let vc = QRCodeScannerViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
            return true
        }
        return false
    }

    static func showDonationPay(with deepLink: DonationPayDeepLink) -> Bool {
        let searchVC = SearchSponsorViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.navigationController?.pushViewController(searchVC, animated: false)
        }
        let sendVC = SendDonationViewController.make(loginId: deepLink.id ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(sendVC, type: .push)
            return true
        }
        return false
    }

    static func showDonationLog(with deepLink: DonationLogDeepLink) -> Bool {
        let vc = SponsorshipHistoryViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showMypage(with deepLink: MypageDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.myPage, toRoot: true)
            return true
        }
        return false
    }

    static func showTransaction(with deepLink: TransactionDeepLink) -> Bool {
        let vc = TransactionHistoryViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showWallet(with deepLink: WalletDeepLink) -> Bool {
        let vc = DepositViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
        }
        return false
    }

    static func showMyinfo(with deepLink: MyinfoDeepLink) -> Bool {
        let vc = ChangeMyInfoViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
            return true
        }
        return false
    }

    static func showPassword(with deepLink: PasswordDeepLink) -> Bool {
        let vc = ChangePasswordViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
            return true
        }
        return false
    }
}
