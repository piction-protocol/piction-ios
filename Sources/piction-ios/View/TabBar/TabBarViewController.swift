//
//  TabBarViewController.swift
//  PictionSDK
//
//  Created by jhseo on 02/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import Swinject

final class TabBarController: UITabBarController {

    var previousViewController: UIViewController?
    private var lastIndex = 0 {
        didSet {
            lastIndexExceptLibrary = lastIndex != 2 ? lastIndex : lastIndexExceptLibrary
        }
    }
    private var lastIndexExceptLibrary = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setTabBar(with: TabBarItem.all)
        self.delegate = self

        UITabBar.appearance().tintColor = UIColor(r: 26, g: 146, b: 255)
    }

    private func setTabBar(with types: [TabBarItem]) {
        viewControllers = types.map { item -> UINavigationController in
            let viewController = item.makeViewController()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.navigationBar.prefersLargeTitles = true

            return navigationController
        }
    }

    func moveToSelectTab(_ type: TabBarItem, toRoot: Bool = false) {
        selectedIndex = type.rawValue

        if toRoot {
            self.tabBar.isHidden = false
            if let vc = viewControllers?[type.rawValue] as? UINavigationController {
                vc.popToRootViewController(animated: true)
                tabBarController(self, didSelect: vc)
            }
        }
    }
}
extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        self.previousViewController = tabBarController.selectedViewController?.children.last

        guard let toIndex = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return false
        }

        animateToTab(toIndex)
        return true
    }

    func animateToTab(_ toIndex: Int) {
        guard let tabViewControllers = self.viewControllers else { return }
        guard let fromIndex = tabViewControllers.firstIndex(of: selectedViewController!) else { return }
        guard let fromView = tabViewControllers[fromIndex].view else { return }
        guard let toView = tabViewControllers[toIndex].view else { return }
        if fromIndex == toIndex { return }

        // Add the toView to the tab bar view
        fromView.superview?.addSubview(toView)

        // Position toView off screen (to the left/right of fromView)
        let scrollRight = toIndex > fromIndex
        let offset = (scrollRight ? SCREEN_W : -SCREEN_W)
        toView.center = CGPoint(x: fromView.center.x + offset, y: toView.center.y)

        // Disable interaction during animation
        view.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0.7, options: .curveEaseInOut, animations: {
            // Slide the views by -offset
            fromView.center = CGPoint(x: fromView.center.x - offset, y: fromView.center.y)
            toView.center   = CGPoint(x: toView.center.x - offset, y: toView.center.y)
        }, completion: { _ in
            // Remove the old view from the tabbar view.
            fromView.removeFromSuperview()
            self.selectedIndex = toIndex
            self.view.isUserInteractionEnabled = true
        })
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let topViewController = UIApplication.topViewController()
            if previousViewController == tabBarController.selectedViewController?.children.last  {
                if viewController.children.count == 1 {
                    if topViewController is ExplorerViewController {
                        if let vc = topViewController as? ExplorerViewController {
                            vc.tableView.setContentOffset(CGPoint.zero, animated: true)
                        }
                    } else if topViewController is SubscriptionListViewController {
                        if let vc = topViewController as? SubscriptionListViewController {
                            vc.collectionView.setContentOffset(CGPoint.zero, animated: true)
                        }
                    } else if topViewController is SponsorshipListViewController {
                        if let vc = topViewController as? SponsorshipListViewController {
                            vc.tableView.setContentOffset(CGPoint.zero, animated: true)
                        }
                    } else if topViewController is MyPageViewController {
                        if let vc = topViewController as? MyPageViewController {
                            vc.tableView.setContentOffset(CGPoint.zero, animated: true)
                        }
                    }
                }
            }

            lastIndex = selectedIndex
        }
}

enum TabBarItem: Int {
    case explore
    case subscription
    case sponsorship
    case myPage

    static var all: [TabBarItem] {
        return [.explore, .subscription, .sponsorship, .myPage]
    }
}

extension TabBarItem {
    private func makeTabBarItem() -> UITabBarItem {
        let items: (String, UIImage?, UIImage?)

        switch self {
        case .explore:
            items = (
                LocalizedStrings.tab_explore.localized(),
                #imageLiteral(resourceName: "icTab1Unselected"),
                #imageLiteral(resourceName: "icTab1Active")
            )
        case .subscription:
            items = (
                LocalizedStrings.tab_subscription.localized(),
                #imageLiteral(resourceName: "icTab2Unselected"),
                #imageLiteral(resourceName: "icTab2Active")
            )
        case .sponsorship:
            items = (
                LocalizedStrings.tab_sponsorship.localized(),
                #imageLiteral(resourceName: "icTab3Unselected"),
                #imageLiteral(resourceName: "icTab3Active")
            )
        case .myPage:
            items = (
                LocalizedStrings.menu_my_info.localized(),
                #imageLiteral(resourceName: "icTab4Unselected"),
                #imageLiteral(resourceName: "icTab4Unselected")
            )
        }

        let tabBarItem = UITabBarItem(
            title: items.0,
            image: items.1,
            selectedImage: items.2
        )

        return tabBarItem
    }

    fileprivate func makeViewController() -> UIViewController {
        let viewController: UIViewController

        switch self {
        case .explore:
            viewController = ExplorerViewController.make()
        case .subscription:
            viewController = SubscriptionListViewController.make()
        case .sponsorship:
            viewController = SponsorshipListViewController.make()
        case .myPage:
            viewController = MyPageViewController.make()
        }

        viewController.tabBarItem = makeTabBarItem()
        return viewController
    }
}
