//
//  AppShortcut.swift
//  piction-ios
//
//  Created by jhseo on 14/10/2019.
//  Copyright © 2018년 thewhalegames. All rights reserved.
//

import UIKit

enum AppShortcutType: String {
    case home = "home"
    case explore = "explore"
    case subscription = "subscription"
    case sponsorship = "sponsorship"
    case mypage = "mypage"

    var title: String {
        switch self {
        case .home:
            return ""
        case .explore:
            return LocalizedStrings.tab_explore.localized()
        case .subscription:
            return LocalizedStrings.tab_subscription.localized()
        case .sponsorship:
            return LocalizedStrings.tab_sponsorship.localized()
        case .mypage:
            return LocalizedStrings.menu_my_info.localized()
        }
    }

    var icon: String {
        switch self {
        case .home:
            return ""
        case .explore:
            return "icTab1Unselected"
        case .subscription:
            return "icTab2Unselected"
        case .sponsorship:
            return "icTab3Unselected"
        case .mypage:
            return "icTab4Unselected"
        }
    }
}

class AppShortcut: UIMutableApplicationShortcutItem {
    var segue: String

    init(type: AppShortcutType, segue: String) {
        self.segue = segue
        let iconImage = UIApplicationShortcutIcon(templateImageName: type.icon)
        super.init(type: String(describing: type), localizedTitle: type.title, localizedSubtitle: nil, icon: iconImage, userInfo: nil)
    }
}

class AppShortcuts {
    static var shortcuts: [AppShortcut] = []

    class func sync() {
        var newShortcuts: [AppShortcut] = []

        newShortcuts.append(AppShortcut(type: .explore, segue: "openExplore"))
        newShortcuts.append(AppShortcut(type: .subscription, segue: "openSubscription"))
        newShortcuts.append(AppShortcut(type: .sponsorship, segue: "openSponsorship"))
        newShortcuts.append(AppShortcut(type: .mypage, segue: "openMyPage"))

        UIApplication.shared.shortcutItems = newShortcuts
        shortcuts = newShortcuts
    }

    class func performShortcut(window: UIWindow, shortcut: UIApplicationShortcutItem) {
        sync()

        switch AppShortcutType(rawValue: shortcut.type) ?? .home {
        case .home:
            break
        case .explore:
            if let url = URL(string: "\(AppInfo.urlScheme)://home-explore") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .subscription:
            if let url = URL(string: "\(AppInfo.urlScheme)://my-subscription") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .sponsorship:
            if let url = URL(string: "\(AppInfo.urlScheme)://home-donation") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .mypage:
            if let url = URL(string: "\(AppInfo.urlScheme)://mypage") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        }
    }
}

