//
//  String+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 31/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import Kanna

extension String {
    func getYoutubeId() -> [String] {
        let regexStr = "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)"

        let htmlString = self

        let regex = try? NSRegularExpression(pattern: regexStr, options: .caseInsensitive)

        var youtubeIds: [String] = []

        if let results = regex?.matches(in: htmlString, range: NSRange(location: 0, length: htmlString.count)) {

            for match in results {
                let startIndex = htmlString.index(htmlString.startIndex, offsetBy: match.range.location)
                let endIndex = htmlString.index(startIndex, offsetBy: match.range.length - 1)
                let id = htmlString[startIndex...endIndex]
                youtubeIds.append(String(id))
            }
        }

        return youtubeIds
    }

    func getYoutubePosterUrlString() -> String {

        let youtubeIds = self.getYoutubeId()

        var htmlString = self

        return "https://img.youtube.com/vi/\(youtubeIds.first ?? "")/maxresdefault.jpg"
    }

    func convertTagIFrameToVideo() -> String {
        let youtubeIds = self.getYoutubeId()

        var htmlString = self

        htmlString = htmlString.replacingOccurrences(of: "<div class=\"video\">  ", with: "<p>")
        htmlString = htmlString.replacingOccurrences(of: " </div> ", with: "</p>")

        if let doc = try? HTML(html: self, encoding: .utf8) {
            for (index, element) in doc.xpath("//iframe").enumerated() {
                if let youtubeId = youtubeIds[safe: index] {
                    htmlString = htmlString.replacingOccurrences(of: element.toHTML ?? "", with: "<video src=\"https://www.youtube.com/watch?v=\(youtubeId)\" poster=\"https://img.youtube.com/vi/\(youtubeId)/maxresdefault.jpg\"></video>")
                }
            }
        }
        return htmlString
    }

    func convertTagVideoToIFrame() -> String {
        let youtubeIds = self.getYoutubeId()

        var htmlString = self

        if let doc = try? HTML(html: self, encoding: .utf8) {
            for (index, element) in doc.xpath("//video").enumerated() {
                if let youtubeId = youtubeIds[safe: index] {
                    htmlString = htmlString.replacingOccurrences(of: element.toHTML ?? "", with: "<iframe frameborder=\"0\" allowfullscreen=\"true\" src=\"https://www.youtube.com/embed/\(youtubeId)\"></iframe>")
                }
            }
        }
        htmlString = htmlString.replacingOccurrences(of: "<p><iframe", with: "<div class=\"video\">  <iframe")
        htmlString = htmlString.replacingOccurrences(of: "</iframe></p>", with: "</iframe> </div> ")

        return htmlString
    }
}
