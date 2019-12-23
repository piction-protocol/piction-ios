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
        action: String = LocalizedStrings.confirm.localized(),
        completion: @escaping () -> Void) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert)

        let cancelButton = UIAlertAction(title: LocalizedStrings.cancel.localized(), style: .cancel)
        let confirmAction = UIAlertAction(title: action, style: .default, handler: { _ in
            completion()
        })

        alert.addAction(cancelButton)
        alert.addAction(confirmAction)

        self.present(alert, animated: false, completion: nil)
    }
}

extension UIViewController {
    func openRegisterPincodeViewController(type: ViewOpenType = .present) {
        let vc = RegisterPincodeViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: type)
        }
    }

    func openConfirmPincodeViewController(inputPincode: String) {
        let vc = ConfirmPincodeViewController.make(inputPincode: inputPincode)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openSignUpViewController() {
        let vc = SignUpViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openSignUpCompleteViewController(loginId: String) {
        let vc = SignUpCompleteViewController.make(loginId: loginId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openTagResultProjectViewController(tag: String) {
        let vc = TagResultProjectViewController.make(tag: tag)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openTagListViewController() {
        let vc = TagListViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openCheckPincodeViewController(delegate: CheckPincodeDelegate? = nil) {
        let vc = CheckPincodeViewController.make(style: .check)
        vc.delegate = delegate
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    func openMyProjectViewController() {
        let vc = MyProjectViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openTransactionHistoryListViewController() {
        let vc = TransactionHistoryViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openDepositViewController() {
        let vc = DepositViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openChangeMyInfoViewController() {
        let vc = ChangeMyInfoViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    func openChangePasswordViewController() {
        let vc = ChangePasswordViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    func openCheckPincodeViewController() {
        let vc = CheckPincodeViewController.make(style: .change)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    func openSafariViewController(url urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safariViewController = SFSafariViewController(url: url)
        self.present(safariViewController, animated: true, completion: nil)
    }

    func openCreateProjectViewController(uri: String) {
        let vc = CreateProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openManageSeriesViewController(uri: String, seriesId: Int? = nil, delegate: ManageSeriesDelegate? = nil) {
        let vc = ManageSeriesViewController.make(uri: uri, seriesId: seriesId)
        vc.delegate = delegate
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    func openManageFanPassViewController(uri: String, fanPassId: Int? = nil, delegate: ManageFanPassDelegate? = nil) {
        let vc = ManageFanPassViewController.make(uri: uri, fanPassId: fanPassId)
        vc.delegate = delegate
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    func openTransactionDetailViewController(transaction: TransactionModel) {
        let vc = TransactionDetailViewController.make(transaction: transaction)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openSeriesPostViewController(uri: String, seriesId: Int) {
        let vc = SeriesPostViewController.make(uri: uri, seriesId: seriesId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openPostViewController(uri: String, postId: Int) {
        let vc = PostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openCreatePostViewController(uri: String, postId: Int = 0) {
        let vc = CreatePostViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openProjectInfoViewController(uri: String) {
        let vc = ProjectInfoViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openSubscriptionUserViewController(uri: String) {
        let vc = SubscriptionUserViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    func openFanPassListViewController(uri: String, postId: Int? = nil) {
        let vc = FanPassListViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    func openSignInViewController() {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    func openSubscribeFanPassViewController(uri: String, selectedFanPass: FanPassModel) {
        let vc = SubscribeFanPassViewController.make(uri: uri, selectedFanPass: selectedFanPass)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    func openCreateFanPassViewController(uri: String, fanPass: FanPassModel? = nil) {
        let vc = CreateFanPassViewController.make(uri: uri, fanPass: fanPass)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}
