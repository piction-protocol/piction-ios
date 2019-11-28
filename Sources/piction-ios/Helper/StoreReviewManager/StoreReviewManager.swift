//
//  StoreReviewManager.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/28.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import StoreKit

enum UserDefaultsKeys: String {
    case userPushNotificationAlreadySeenKey, storeReviewInitialDelayCountKey, lastDateReviewPromptedKey, lastVersionPromptedForReviewKey
}

class StoreReviewManager {
    private let minimumDaysSinceLastReview = 122
    private let minimumInitialDelayCount = 10

    func askForReview(navigationController: UINavigationController?) {
        guard let navigationController = navigationController else { return }

        if #available(iOS 10.3, *) {
            let oldTopViewController = navigationController.topViewController
            let currentVersion = version()
            let count = initialDelayCount
            incrementInitialDelayCount()

            // Has the task/process been completed several times and the user has not already been prompted for this version?
            if count >= minimumInitialDelayCount && currentVersion != lastVersionPromptedForReview && lastDatePromptedUser <= Date().daysAgo(minimumDaysSinceLastReview) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if navigationController.topViewController == oldTopViewController {
                        SKStoreReviewController.requestReview()
                        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)
                        UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(Date(), forKey:UserDefaultsKeys.lastDateReviewPromptedKey.rawValue)
                    }
                }
            }
        }
    }

    private var lastDatePromptedUser: Date {
        get {
            return UserDefaults(suiteName: "group.\(BUNDLEID)")?.object(forKey: UserDefaultsKeys.lastDateReviewPromptedKey.rawValue) as? Date ?? Date().daysAgo(minimumDaysSinceLastReview + 1)
        }
    }

    private var lastVersionPromptedForReview: String? {
        get {
            return UserDefaults(suiteName: "group.\(BUNDLEID)")?.string(forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)
        }
    }

    private func version() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String
        return "\(version).\(build)"
    }

    private var initialDelayCount: Int {
        get {
            return UserDefaults(suiteName: "group.\(BUNDLEID)")?.integer(forKey: UserDefaultsKeys.storeReviewInitialDelayCountKey.rawValue) ?? 0
        }
    }

    private func incrementInitialDelayCount() {
        var count = initialDelayCount
        if count < minimumInitialDelayCount {
            count += 1
            UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(count, forKey: UserDefaultsKeys.storeReviewInitialDelayCountKey.rawValue)
        }
    }
}
