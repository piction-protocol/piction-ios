//
//  KeychainManager.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import KeychainAccess

public class KeychainManager {
    public static func get(key: String) -> String {
        let keychain = Keychain(service: BUNDLEID, accessGroup: "group.\(BUNDLEID)")
        return keychain[key] ?? ""
    }

    public static func set(key: String, value: String) {
        let keychain = Keychain(service: BUNDLEID, accessGroup: "group.\(BUNDLEID)")
        keychain[key] = value
    }
}
