//
//  CreatorProfileLinkCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 2020/02/20.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import Foundation
import PictionSDK

class CreatorProfileLinkCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    typealias Model = CreatorLinkModel

    func configure(with model: Model) {
        nameLabel.text = model.name

        if let url = model.url,
            let domain = url.components(separatedBy: ["http://", "https://"])[safe: 1] {
            switch domain {
            case _ where domain.hasPrefix("facebook.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-share-fb")
            case _ where domain.hasPrefix("instagram.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-instagram")
            case _ where domain.hasPrefix("twitter.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-share-twitter")
            case _ where domain.hasPrefix("tumblr.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-tumblr")
            case _ where domain.hasPrefix("discordapp.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-discord")
            case _ where domain.hasPrefix("youtube.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-youtube")
            case _ where domain.hasPrefix("twitch.tv"):
                iconImageView.image = #imageLiteral(resourceName: "ic-twitch")
            case _ where domain.hasPrefix("pixiv.net"):
                iconImageView.image = #imageLiteral(resourceName: "ic-pixiv")
            case _ where domain.hasPrefix("deviantart.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-deviantart")
            case _ where domain.hasPrefix("soundcloud.com"):
                iconImageView.image = #imageLiteral(resourceName: "ic-soundcloud")
            default:
                break
            }
        }


    }
}
