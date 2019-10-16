//
//  HomeRecommendedProjectHeaderTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//

import UIKit

final class HomeRecommendedProjectHeaderTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var descriptionLabel: UILabel! {
        didSet {
            descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        }
    }
}
