//
//  AppShortcut.swift
//  piction-ios
//
//  Created by jhseo on 14/10/2019.
//  Copyright © 2018년 thewhalegames. All rights reserved.
//

import UIKit

enum AppShortcutType: String {
    case search = "search"
    case explore = "explore"
    case subscription = "subscription"
    case mypage = "mypage"

    var title: String {
        switch self {
        case .search:
            return LocalizationKey.hint_project_and_tag_search.localized()
        case .explore:
            return LocalizationKey.tab_explore.localized()
        case .subscription:
            return LocalizationKey.tab_subscription.localized()
        case .mypage:
            return LocalizationKey.menu_my_info.localized()
        }
    }

    var icon: UIApplicationShortcutIcon {
        switch self {
        case .search:
            return UIApplicationShortcutIcon(type: .search)
        case .explore:
            return UIApplicationShortcutIcon(templateImageName: "icTab2Unselected")
        case .subscription:
            return UIApplicationShortcutIcon(templateImageName: "icTab3Unselected")
        case .mypage:
            return UIApplicationShortcutIcon(templateImageName: "icTab5Unselected")
        }
    }
}

class AppShortcut: UIMutableApplicationShortcutItem {
    var segue: String

    init(type: AppShortcutType, segue: String) {
        self.segue = segue
        super.init(type: String(describing: type), localizedTitle: type.title, localizedSubtitle: nil, icon: type.icon, userInfo: nil)
    }
}

class AppShortcuts {
    static var shortcuts: [AppShortcut] = []

    class func sync() {
        var newShortcuts: [AppShortcut] = []

        newShortcuts.append(AppShortcut(type: .search, segue: "openSearch"))
        newShortcuts.append(AppShortcut(type: .explore, segue: "openExplore"))
        newShortcuts.append(AppShortcut(type: .subscription, segue: "openSubscription"))
        newShortcuts.append(AppShortcut(type: .mypage, segue: "openMyPage"))

        UIApplication.shared.shortcutItems = newShortcuts
        shortcuts = newShortcuts
    }

    class func performShortcut(window: UIWindow, shortcut: UIApplicationShortcutItem) {
        sync()

        switch AppShortcutType(rawValue: shortcut.type) ?? .explore {
        case .search:
            if let url = URL(string: "\(AppInfo.urlScheme)://search") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .explore:
            if let url = URL(string: "\(AppInfo.urlScheme)://home-explore") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .subscription:
            if let url = URL(string: "\(AppInfo.urlScheme)://my-subscription") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        case .mypage:
            if let url = URL(string: "\(AppInfo.urlScheme)://mypage") {
                _ = DeepLinkManager.executeDeepLink(with: url)
            }
        }
    }
}

