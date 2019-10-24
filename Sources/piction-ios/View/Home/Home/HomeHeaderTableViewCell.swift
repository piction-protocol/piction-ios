//
//  HomeHeaderTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//

import UIKit

enum HomeHeaderType: Int {
    case trending
    case subscription
    case popularTag
    case notice

    var title: String {
        switch self {
        case .trending:
            return LocalizedStrings.str_trending.localized()
        case .subscription:
            return LocalizedStrings.str_subscription_project.localized()
        case .popularTag:
            return LocalizedStrings.str_popular_tag.localized()
        case .notice:
            return LocalizedStrings.str_banner_header.localized()
        }
    }

    var description: String? {
        switch self {
        case .trending:
            return LocalizedStrings.str_trending_info.localized()
        case .subscription:
            return nil
        case .popularTag:
            return nil
        case .notice:
            return LocalizedStrings.str_banner_header_info.localized()
        }
    }

    var moreAction: Bool {
        switch self {
        case .trending,
             .notice:
            return false
        case .subscription,
             .popularTag:
            return true
        }
    }
}

final class HomeHeaderTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel! {
        didSet {
            descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        }
    }
    @IBOutlet weak var moreButton: UIButton!

    typealias Model = HomeHeaderType

    func configure(with model: Model) {
        let (title, description, moreAction) = (model.title, model.description, model.moreAction)

        titleLabel.text = title
        descriptionLabel.text = description
        moreButton.tag = model.rawValue

        moreButton.isHidden = !moreAction
    }

    @IBAction func moreBtnDidTap(_ sender: Any) {
        guard let tag = (sender as AnyObject).tag else { return }

        switch HomeHeaderType(rawValue: tag) {
        case .subscription:
            if let url = URL(string: "\(AppInfo.urlScheme)://my-subscription") {
                UIApplication.dismissAllPresentedController {
                    _ = DeepLinkManager.executeDeepLink(with: url)
                }
            }
        case .popularTag:
            openTagListViewController()
        default:
            break
        }
    }

    func openTagListViewController() {
        let vc = TagListViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}
