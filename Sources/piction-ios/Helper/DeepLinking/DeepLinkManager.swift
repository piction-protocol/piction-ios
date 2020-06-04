//
//  DeepLinkManager.swift
//  piction-ios
//
//  Created by jhseo on 02/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import SafariServices

struct DeepLinkManager {
    static func executeDeepLink(with url: URL) -> Bool {
        // Create a recognizer with this app's custom deep link types.
        let recognizer = DeepLinkRecognizer(deepLinkTypes: [
                LoginDeepLink.self,
                SignupDeepLink.self,
                HomeDeepLink.self,
                HomeExploreDeepLink.self,
                CategorizedProjectDeepLink.self,
                SearchDeepLink.self,
                TaggingProjectDeepLink.self,
                ProjectDeepLink.self,
                ProjectPostsDeepLink.self,
                ProjectSeriesDeepLink.self,
                ProjectInfoDeepLink.self,
                SeriesDeepLink.self,
                ViewerDeepLink.self,
                MySubscriptionDeepLink.self,
                MypageDeepLink.self,
                TransactionDeepLink.self,
                WalletDeepLink.self,
                MyinfoDeepLink.self,
                PasswordDeepLink.self,
                TermsDeepLink.self,
                PrivacyDeepLink.self,
                MembershipListDeepLink.self
            ]
        )

        var replaceUrlString: String {
            return url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let replaceUrl = URL(string: replaceUrlString) else { return false }

        // Try to create a deep link object based on the URL.
        guard let deepLink = recognizer.deepLink(matching: replaceUrl) else {
            //print("Unable to match URL: \(url.absoluteString)")

            if replaceUrlString.range(of: "piction://") == nil && replaceUrlString.range(of: "piction-test://") == nil && replaceUrlString.range(of: "applinks://") == nil {
                UIApplication.shared.open(replaceUrl)
            }
            return false
        }

        // Navigate to the view or content specified by the deep link.
        switch deepLink {
        case let link as LoginDeepLink: return showLogin(with: link)
        case let link as SignupDeepLink: return showSignup(with: link)
        case let link as HomeDeepLink: return showHome(with: link)
        case let link as HomeExploreDeepLink: return showHomeExplore(with: link)
        case let link as CategorizedProjectDeepLink: return showCategorizedProject(with: link)
        case let link as SearchDeepLink: return showSearch(with: link)
        case let link as TaggingProjectDeepLink: return showTaggingProject(with: link)
        case let link as ProjectDeepLink: return showProject(with: link)
        case let link as ProjectPostsDeepLink: return showProjectPosts(with: link)
        case let link as ProjectSeriesDeepLink: return showProjectSeries(with: link)
        case let link as ProjectInfoDeepLink: return showProjectInfo(with: link)
        case let link as SeriesDeepLink: return showSeries(with: link)
        case let link as ViewerDeepLink: return showViewer(with: link)
        case let link as MySubscriptionDeepLink: return showMySubscription(with: link)
        case let link as MypageDeepLink: return showMypage(with: link)
        case let link as TransactionDeepLink: return showTransaction(with: link)
        case let link as WalletDeepLink: return showWallet(with: link)
        case let link as MyinfoDeepLink: return showMyinfo(with: link)
        case let link as PasswordDeepLink: return showPassword(with: link)
        case let link as TermsDeepLink: return showTerms(with: link)
        case let link as PrivacyDeepLink: return showPrivacy(with: link)
        case let link as MembershipListDeepLink: return showMembershipList(with: link)
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

    static func showHome(with deepLink: HomeDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.home, toRoot: true)
            return true
        }
        return false
    }

    static func showSearch(with deepLink: SearchDeepLink) -> Bool {
        if let tabBarController = UIApplication.topViewController()?.tabBarController as? TabBarController {
            tabBarController.moveToSelectTab(.home, toRoot: true)

            if let topViewController = UIApplication.topViewController() {
                if topViewController is HomeViewController {
                    if let vc = topViewController as? HomeViewController {
                        vc.openSearchBar()
                        return true
                    }
                }
            }
        }
        return false
    }

    static func showTaggingProject(with deepLink: TaggingProjectDeepLink) -> Bool {
        let vc = TaggingProjectViewController.make(tag: deepLink.keyword ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
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

    static func showCategorizedProject(with deepLink: CategorizedProjectDeepLink) -> Bool {
        let vc = CategorizedProjectViewController.make(categoryId: deepLink.id ?? 0)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
            return true
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
        let projectVC = ProjectViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.navigationController?.pushViewController(projectVC, animated: false)
        }
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

    static func showTerms(with deepLink: TermsDeepLink) -> Bool {
        guard let url = URL(string: "https://piction.network/terms") else { return false }

        if let topViewController = UIApplication.topViewController() {
           let safariViewController = SFSafariViewController(url: url)
            topViewController.present(safariViewController, animated: true)
            return true
        }
        return false
    }

    static func showPrivacy(with deepLink: PrivacyDeepLink) -> Bool {
        guard let url = URL(string: "https://piction.network/privacy") else { return false }

        if let topViewController = UIApplication.topViewController() {
           let safariViewController = SFSafariViewController(url: url)
            topViewController.present(safariViewController, animated: true)
            return true
        }
        return false
    }
    
    static func showMembershipList(with deepLink: MembershipListDeepLink) -> Bool {
        let vc = MembershipListViewController.make(uri: deepLink.uri ?? "")
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
            return true
        }
        return false
    }
}
