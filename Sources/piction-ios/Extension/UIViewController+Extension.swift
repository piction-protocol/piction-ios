//
//  UIViewController+Extension.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

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

