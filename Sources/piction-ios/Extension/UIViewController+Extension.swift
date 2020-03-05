//
//  UIViewController+Extension.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import SafariServices
import PictionSDK

enum ViewOpenType: Int {
    case present
    case swipePresent
    case push
}

extension UIViewController {
    public static var defaultNib: String {
        return self.description().components(separatedBy: ".").dropFirst().joined(separator: ".")
    }

    public static var storyboardIdentifier: String {
        return self.description().components(separatedBy: ".").dropFirst().joined(separator: ".")
    }

    func openViewController(_ childView: UIViewController, type: ViewOpenType) {
        switch type {
        case .present:
            let navigation = UINavigationController(rootViewController: childView)
            navigation.modalPresentationStyle = .fullScreen
            self.present(navigation, animated: true, completion: nil)
        case .swipePresent:
            let navigation = UINavigationController(rootViewController: childView)
            self.present(navigation, animated: true, completion: nil)
        case .push:
            self.navigationController?.pushViewController(childView, animated: true)
        }
    }
}

extension UIViewController {
    func embed(_ childViewController: UIViewController, to view: UIView) {
        childViewController.view.frame = view.bounds
        view.addSubview(childViewController.view)
        addChild(childViewController)
        childViewController.didMove(toParent: self)
    }

    func remove(_ childViewController: UIViewController) {
        childViewController.willMove(toParent: nil)
        childViewController.view.removeFromSuperview()
        childViewController.removeFromParent()
    }
}

extension UIViewController {
    public var visibleHeight: CGFloat {
        return self.view.bounds.size.height - statusHeight - navigationHeight - tabbarHeight
    }

    public var statusHeight: CGFloat {
        return UIApplication.shared.statusBarFrame.size.height
    }

    public var navigationHeight: CGFloat {
        return (self.navigationController?.navigationBar.bounds.size.height ?? 0)
    }

    public var largeTitleNavigationHeight: CGFloat {
        return (self.navigationController?.navigationBar.sizeThatFits(.zero).height ?? 0)
    }

    public var tabbarHeight: CGFloat {
        return (self.tabBarController?.tabBar.bounds.size.height ?? 0)
    }

    public var toolbarHeight: CGFloat {
        return (self.navigationController?.toolbar.bounds.size.height ?? 0)
    }
}

extension UIViewController {
    func showPopup(
        title: String? = nil,
        message: String? = nil,
        action: [String] = [LocalizationKey.confirm.localized()],
        completion: @escaping () -> Void) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: action[0], style: .default, handler: { _ in
            completion()
        })
        alert.addAction(confirmAction)

        action.filter { $0 == LocalizationKey.cancel.localized() }
            .map { alert.addAction(UIAlertAction(title: $0, style: .cancel)) }

        self.present(alert, animated: false, completion: nil)
    }
}

extension UIViewController {
    enum ViewType {
        case registerPincode
        case checkPincode(delegate: CheckPincodeDelegate? = nil)
        case confirmPincode(inputPincode: String)
        case signIn
        case signUp
        case signUpComplete(loginId: String)
        case taggingProject(tag: String)
        case project(uri: String)
        case categorizedProject(id: Int)
        case myProject
        case transactionHistory
        case deposit
        case changeMyInfo
        case changePassword
        case transactionDetail(transaction: TransactionModel)
        case seriesPost(uri: String, seriesId: Int)
        case post(uri: String, postId: Int)
        case projectInfo(uri: String)
        case subscriptionUser(uri: String)
        case membershipList(uri: String, postId: Int? = nil)
        case purchaseMembership(uri: String, selectedMembership: MembershipModel)
        case creatorProfile(loginId: String)
        case createProject(uri: String)
        case createPost(uri: String, postId: Int = 0)
        case manageSeries(uri: String, seriesId: Int? = nil, delegate: ManageSeriesDelegate? = nil)
        case manageMembership(uri: String, membershipId: Int? = nil, delegate: ManageMembershipDelegate? = nil)
        case createMembership(uri: String, membership: MembershipModel? = nil)
    }

    func openView(type: ViewType , openType: ViewOpenType) {
        var viewController: UIViewController?

        switch type {
        case .registerPincode:
            viewController = RegisterPincodeViewController.make()
        case .checkPincode(let delegate):
            let style: CheckPincodeStyle = delegate == nil ? .change : .check
            let vc = CheckPincodeViewController.make(style: style)
            vc.delegate = delegate
            viewController = vc
        case .confirmPincode(let inputPincode):
            viewController = ConfirmPincodeViewController.make(inputPincode: inputPincode)
        case .signIn:
            viewController = SignInViewController.make()
        case .signUp:
            viewController = SignUpViewController.make()
        case .signUpComplete(let loginId):
            viewController = SignUpCompleteViewController.make(loginId: loginId)
        case .taggingProject(let tag):
            viewController = TaggingProjectViewController.make(tag: tag)
        case .project(let uri):
            viewController = ProjectViewController.make(uri: uri)
        case .categorizedProject(let id):
            viewController = CategorizedProjectViewController.make(categoryId: id)
        case .myProject:
            viewController = MyProjectViewController.make()
        case .transactionHistory:
            viewController = TransactionHistoryViewController.make()
        case .deposit:
            viewController = DepositViewController.make()
        case .changeMyInfo:
            viewController = ChangeMyInfoViewController.make()
        case .changePassword:
            viewController = ChangePasswordViewController.make()
        case .transactionDetail(let transaction):
            viewController = TransactionDetailViewController.make(transaction: transaction)
        case .seriesPost(let uri, let seriesId):
            viewController = SeriesPostViewController.make(uri: uri, seriesId: seriesId)
        case .post(let uri, let postId):
            viewController = PostViewController.make(uri: uri, postId: postId)
        case .projectInfo(let uri):
            viewController = ProjectInfoViewController.make(uri: uri)
        case .subscriptionUser(let uri):
            viewController = SubscriptionUserViewController.make(uri: uri)
        case .membershipList(let uri, let postId):
            viewController = MembershipListViewController.make(uri: uri, postId: postId)
        case .purchaseMembership(let uri, let selectedMembership):
            viewController = PurchaseMembershipViewController.make(uri: uri, selectedMembership: selectedMembership)
        case .creatorProfile(let loginId):
            viewController = CreatorProfileViewController.make(loginId: loginId)
        case .createProject(let uri):
            viewController = CreateProjectViewController.make(uri: uri)
        case .createPost(let uri, let postId):
            viewController = CreatePostViewController.make(uri: uri, postId: postId)
        case .manageSeries(let uri, let seriesId, let delegate):
            let vc = ManageSeriesViewController.make(uri: uri, seriesId: seriesId)
            vc.delegate = delegate
            viewController = vc
        case .manageMembership(let uri, let membershipId, let delegate):
            let vc = ManageMembershipViewController.make(uri: uri, membershipId: membershipId)
            vc.delegate = delegate
            viewController = vc
        case .createMembership(let uri, let membership):
            viewController = CreateMembershipViewController.make(uri: uri, membership: membership)
        }

        if let viewController = viewController,
            let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(viewController, type: openType)
        }
    }

    func openSafariViewController(url urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safariViewController = SFSafariViewController(url: url)
        self.present(safariViewController, animated: true, completion: nil)
    }
}
