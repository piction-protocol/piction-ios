//
//  String+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 31/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension String {
    static let youtubeIdRegex = #"((?<=(v|V)/)|(?<=be/)|(?<=(\?|\&)v=)|(?<=embed/))([\w-]++)"#
    static let pictionUrlRegex = #"https?:\/\/(staging\.)?piction.network\/project\/([a-z0-9-]{5,20})(\/posts((\/)(\d+))?)?"#

    func getRegexCaptureList(pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let nsString = NSString(string: self)
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            return (results.map { match in
                (0 ..< match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsString.substring(with: match.range(at: $0)) }
            }).first ?? []
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    func getRegexMatches(pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map { String(self[Range($0.range, in: self)!]) }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

// Localization
extension String {
    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
        return NSLocalizedString(self, tableName: tableName, value: "**\(self)**", comment: "")
    }
}
