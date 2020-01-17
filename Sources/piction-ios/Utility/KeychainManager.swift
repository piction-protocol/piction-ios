//
//  KeychainManager.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import KeychainAccess

enum KeychainKeyType: String {
    case pincode = "pincode"
    case accessToken = "accessToken"
}

protocol KeychainManagerProtocol {
    func get(key: KeychainKeyType) -> String
    func set(key: KeychainKeyType, value: String)
}

final class KeychainManager: KeychainManagerProtocol {
    init() {}

    func get(key: KeychainKeyType) -> String {
        let keychain = Keychain(service: BUNDLEID, accessGroup: "group.\(BUNDLEID)")
        return keychain[key.rawValue] ?? ""
    }

    func set(key: KeychainKeyType, value: String) {
        let keychain = Keychain(service: BUNDLEID, accessGroup: "group.\(BUNDLEID)")
        keychain[key.rawValue] = value
    }
}
