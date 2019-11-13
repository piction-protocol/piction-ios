//
//  AppInfo.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//

import Foundation

let BUNDLEID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? "").replacingOccurrences(of: ".shareEx", with: "")
