//
//  SeriesPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!

    typealias Model = PostModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, isSubscribing: Bool, number: Int) {
        let (title, date, fanPass) = (model.title, model.createdAt, model.fanPass)

        numberLabel.text = "#\(number)"

        titleLabel.text = title

        if isSubscribing || fanPass?.id == nil {
            subTitleLabel.textColor = UIColor(r: 191, g: 191, b: 191)
            subTitleLabel.text = date?.toString(format: "YYYY년 M월 d일 hh:ss 발행")
        } else {
            subTitleLabel.textColor = UIColor(r: 213, g: 19, b: 21)
            if fanPass?.id != nil {
                subTitleLabel.text = "구독자 전용"
            } else {
                subTitleLabel.text = "\(fanPass?.name) 이상 구독자 전용"
            }
        }
    }
}
