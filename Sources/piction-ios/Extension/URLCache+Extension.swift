//
//  URLCache+Extension.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension URLCache {
    private static let memoryCapacity = 4 * 1024 * 1024
    private static let diskCapacity = 32 * 1024 * 1024

    public static func initCache() {
        let cache = URLCache(memoryCapacity: memoryCapacity,
                             diskCapacity: diskCapacity,
                             diskPath: "nsurlcache")
        URLCache.shared = cache
    }
}
