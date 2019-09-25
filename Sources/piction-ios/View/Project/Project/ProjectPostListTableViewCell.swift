//
//  ProjectPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 03/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var seriesLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeStackView: UIStackView!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var lockView: UIView!
    @IBOutlet weak var lockMessageLabel: UILabel!
    @IBOutlet weak var maskImage: VisualEffectView!

    typealias Model = PostModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, isSubscribing: Bool) {
        let (thumbnail, seriesName, title, date, likeCount, fanPassId) = (model.cover, model.series?.name, model.title, model.createdAt, model.likeCount, model.fanPass?.id)

        let coverImageWithIC = "\(thumbnail ?? "")?w=656&h=246&quality=80&output=webp"
        if let url = URL(string: coverImageWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-post-960-x-360")
        }
        seriesLabel.isHidden = seriesName == nil
        seriesLabel.text = "시리즈 · \(seriesName ?? "")"

        titleLabel.text = title
        dateLabel.text = date?.toString(format: "M월 d일")

        likeStackView.isHidden = (likeCount ?? 0) == 0
        likeLabel.text = "\(likeCount ?? 0)"
        
        if (fanPassId != nil) && !isSubscribing {
            lockMessageLabel.text = "구독자 전용 포스트입니다."
            thumbnailView.isHidden = false
            maskImage.isHidden = false
            lockView.isHidden = false
            maskImage.blurRadius = thumbnail == nil ? 0 : 5
            lockView.backgroundColor = thumbnail == nil ? UIColor(r: 51, g: 51, b: 51, a: 0.2) : .clear
        } else {
            thumbnailView.isHidden = thumbnail == nil
            maskImage.isHidden = true
            lockView.isHidden = true
        }
    }
}
