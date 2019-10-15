//
//  ProjectHeaderView.swift
//  PictionView
//
//  Created by jhseo on 17/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import PictionSDK
import GSKStretchyHeaderView

protocol ProjectHeaderViewDelegate: class {
    func postBtnDidTap()
    func seriesBtnDidTap()
    func subscriptionBtnDidTap()
    func shareBtnDidTap()
}

class ProjectHeaderView: GSKStretchyHeaderView {

    weak var delegate: ProjectHeaderViewDelegate?

    @IBOutlet weak var subscriptionButton: UIButtonExtension!
    @IBOutlet weak var thumbnailImageView: UIImageView! {
        didSet {
            let gradientLayer = CAGradientLayer()
            let color1 = UIColor(white: 0.0, alpha: 0.38).cgColor
            let color2 = UIColor.clear.cgColor
            gradientLayer.colors = [color1, color2]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.frame = CGRect(x: 0, y: 0, width: SCREEN_H, height: SCREEN_W / 3)
            thumbnailImageView.layer.addSublayer(gradientLayer)
        }
    }
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var subscriptionCountLabel: UILabel!
    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var seriesButton: UIButton!

    @IBOutlet weak var maskImage: VisualEffectView!
    @IBOutlet weak var naviView: UIView!
    @IBOutlet var naviViewImageHeight: NSLayoutConstraint!
    @IBOutlet weak var projectInfoView: UIView!

    @IBAction func postBtnDidTap(_ sender: Any) {
        delegate?.postBtnDidTap()
    }

    @IBAction func seriesBtnDidTap(_ sender: Any) {
        delegate?.seriesBtnDidTap()
    }

    @IBAction func subscriptionBtnDidTap(_ sender: Any) {
        delegate?.subscriptionBtnDidTap()
    }

    @IBAction func shareBtnDidTap(_ sender: Any) {
        delegate?.shareBtnDidTap()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        minimumContentHeight = DEFAULT_NAVIGATION_HEIGHT + 52
        maximumContentHeight = projectInfoView.frame.origin.y + projectInfoView.frame.size.height + 52
        naviViewImageHeight.constant = DEFAULT_NAVIGATION_HEIGHT

        expansionMode = .topOnly

        thumbnailImageView.contentMode = .scaleAspectFill
    }

    func configureProjectInfo(model: ProjectModel) {
        let (thumbnail, title, profileImage, writerName, writerloginId, subscriptionUserCount) = (model.thumbnail, model.title, model.user?.picture, model.user?.username, model.user?.loginId, model.subscriptionUserCount)

        let thumbnailWithIC = "\(thumbnail ?? "")?w=720&h=720&quality=80&output=webp"
        if let url = URL(string: thumbnailWithIC) {
            thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
        }

        titleLabel.text = title
        titleLabel.textColor = UIColor(named: "PictionDarkGray")

        let userPictureWithIC = "\(profileImage ?? "")?w=240&h=240&quality=80&output=webp"
        if let url = URL(string: userPictureWithIC) {
            profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
        }
        writerLabel.text = writerName
        loginIdLabel.text = "@\(writerloginId ?? "")"
        subscriptionCountLabel.text = LocalizedStrings.str_subs_count_plural.localized(with: subscriptionUserCount ?? 0)
    }

    func configureSubscription(isWriter: Bool, isSubscribing: Bool) {
        if isSubscribing {
            subscriptionButton.isHidden = false
            subscriptionButton.backgroundColor = UIColor(r: 242, g: 242, b: 242)
            subscriptionButton.setTitle(LocalizedStrings.str_project_subscribing.localized(), for: .normal)
            subscriptionButton.setTitleColor(UIColor(r: 191, g: 191, b: 191), for: .normal)
        } else {
            if isWriter {
                if FEATURE_EDITOR {
                    subscriptionButton.isHidden = false
                    subscriptionButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                    subscriptionButton.setTitle(LocalizedStrings.btn_new_post.localized(), for: .normal)
                    subscriptionButton.setTitleColor(.white, for: .normal)
                } else {
                    subscriptionButton.isHidden = true
                }
            } else {
                subscriptionButton.isHidden = false
                subscriptionButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                subscriptionButton.setTitle(LocalizedStrings.btn_subs.localized(), for: .normal)
                subscriptionButton.setTitleColor(.white, for: .normal)
            }
        }
    }

    func controlMenuButton(menu: Int) {
        if #available(iOS 13.0, *) {
            postButton.backgroundColor = menu == 0 ? .clear : .systemBackground
            seriesButton.backgroundColor = menu == 0 ? .systemBackground : .clear
        } else {
            postButton.backgroundColor = menu == 0 ? .clear : .white
            seriesButton.backgroundColor = menu == 0 ? .white : .clear
        }
        postButton.setTitleColor(menu == 0 ? UIColor(named: "PictionDarkGray") : UIColor(r: 191, g: 191, b: 191), for: .normal)
        seriesButton.setTitleColor(menu == 0 ? UIColor(r: 191, g: 191, b: 191) : UIColor(named: "PictionDarkGray"), for: .normal)
    }
}

extension ProjectHeaderView {
    static func getView() -> ProjectHeaderView {
        let view = Bundle.main.loadNibNamed("ProjectHeaderView", owner: self, options: nil)!.first as! ProjectHeaderView
        return view
    }
}
