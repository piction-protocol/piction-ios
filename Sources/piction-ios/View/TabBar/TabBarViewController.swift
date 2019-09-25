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

    override func viewDidLoad() {
        super.viewDidLoad()
        setTabBar(with: TabBarItem.all)

        UITabBar.appearance().tintColor = UIColor(r: 26, g: 146, b: 255)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func setTabBar(with types: [TabBarItem]) {
        viewControllers = types.map { item -> UINavigationController in
            let viewController = item.makeViewController()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.navigationBar.prefersLargeTitles = true
            navigationController.navigationBar.isTranslucent = true
            navigationController.navigationItem.largeTitleDisplayMode = .always

            UINavigationBar.appearance().setBackgroundImage(UIImage().imageWithColor(color: .white) ,for: UIBarMetrics.default)
            UINavigationBar.appearance().largeTitleTextAttributes =
                [NSAttributedString.Key.foregroundColor: UIColor(r: 51, g: 51, b: 51),
                 NSAttributedString.Key.font:UIFont.boldSystemFont(ofSize: 34)]

            return navigationController
        }
//        viewControllers = types.map { item -> UIViewController in
//            let viewController = item.makeViewController()
//            return viewController
//        }

    }
}

enum TabBarItem {
    case home
    case subscription
    case sponsorship
    case myPage

    static var all: [TabBarItem] {
        return [.home, .subscription, .sponsorship, .myPage]
    }
}

extension TabBarItem {
    private func makeTabBarItem() -> UITabBarItem {
        let items: (String, UIImage?, UIImage?)

        switch self {
        case .home:
            items = (
                "탐색",
                #imageLiteral(resourceName: "icTab1Unselected"),
                #imageLiteral(resourceName: "icTab1Active")
            )
        case .subscription:
            items = (
                "구독",
                #imageLiteral(resourceName: "icTab2Unselected"),
                #imageLiteral(resourceName: "icTab2Active")
            )
        case .sponsorship:
            items = (
                "후원",
                #imageLiteral(resourceName: "icTab3Unselected"),
                #imageLiteral(resourceName: "icTab3Active")
            )
        case .myPage:
            items = (
                "마이페이지",
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
        case .home:
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
