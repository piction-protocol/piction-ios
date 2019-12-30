//
//  String+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 31/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension String {
    func getYoutubeId() -> [String] {
        let regexStr = "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)"

        let regex = try? NSRegularExpression(pattern: regexStr, options: .caseInsensitive)

        var youtubeIds: [String] = []

        if let results = regex?.matches(in: self, range: NSRange(location: 0, length: self.count)) {

            for match in results {
                let startIndex = self.index(self.startIndex, offsetBy: match.range.location)
                let endIndex = self.index(startIndex, offsetBy: match.range.length - 1)
                let id = self[startIndex...endIndex]
                youtubeIds.append(String(id))
            }
        }

        return youtubeIds
    }
}

// Localization
extension String {
    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
        return NSLocalizedString(self, tableName: tableName, value: "**\(self)**", comment: "")
    }
}
