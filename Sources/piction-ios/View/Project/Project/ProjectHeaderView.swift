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
    func managementBtnDidTap()
    func subscriptionUserBtnDidTap()
}

class ProjectHeaderView: GSKStretchyHeaderView {

    weak var delegate: ProjectHeaderViewDelegate?

    @IBOutlet weak var subscriptionButton: UIButton!
    @IBOutlet weak var managementButton: UIButton!
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
    @IBOutlet weak var subscriptionUserButton: UIButton!

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

    @IBAction func managementBtnDidTap(_ sender: Any) {
        delegate?.managementBtnDidTap()
    }

    @IBAction func subscriptionUserBtnDidTap(_ sender: Any) {
        delegate?.subscriptionUserBtnDidTap()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        minimumContentHeight = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT + 52
        maximumContentHeight = projectInfoView.frame.origin.y + projectInfoView.frame.size.height + 52 - STATUS_HEIGHT - DEFAULT_NAVIGATION_HEIGHT
        naviViewImageHeight.constant = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT

        expansionMode = .topOnly

        thumbnailImageView.contentMode = .scaleAspectFill
    }

    func configureProjectInfo(model: ProjectModel) {
        let (thumbnail, title, profileImage, writerName, writerloginId, subscriptionUserCount) = (model.thumbnail, model.title, model.user?.picture, model.user?.username, model.user?.loginId, model.subscriptionUserCount)

        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450"), completed: nil)
            }
        } else {
            thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-projectcover-1440-x-450")
        }

        titleLabel.text = title
        titleLabel.textColor = .pictionDarkGray

        if let profileImage = profileImage {
            let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
            if let url = URL(string: userPictureWithIC) {
                profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
            }
        } else {
           profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
        }
        writerLabel.text = writerName
        loginIdLabel.text = "@\(writerloginId ?? "")"
        subscriptionCountLabel.text = LocalizedStrings.str_subs_count_plural.localized(with: subscriptionUserCount ?? 0)
    }

    func configureSubscription(isWriter: Bool, fanPassList: [FanPassModel], subscriptionInfo: SubscriptionModel?) {

        if subscriptionInfo != nil {
            subscriptionUserButton.isHidden = true
            managementButton.isHidden = true
            subscriptionButton.isHidden = false
            subscriptionButton.backgroundColor = .pictionLightGray
            subscriptionButton.setTitle(LocalizedStrings.str_project_subscribing.localized(), for: .normal)
            subscriptionButton.setTitleColor(.pictionGray, for: .normal)
        } else {
            if isWriter {
                if FEATURE_EDITOR {
                    subscriptionUserButton.isHidden = false
                    managementButton.isHidden = false
                    subscriptionButton.isHidden = false
                    subscriptionButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                    subscriptionButton.setTitle(LocalizedStrings.btn_new_post.localized(), for: .normal)
                    subscriptionButton.setTitleColor(.white, for: .normal)
                } else {
                    managementButton.isHidden = true
                    subscriptionButton.isHidden = true
                }
            } else {
                subscriptionUserButton.isHidden = true
                managementButton.isHidden = true
                subscriptionButton.isHidden = false
                subscriptionButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
                subscriptionButton.setTitle(fanPassList.count > 1 ? LocalizedStrings.btn_subs.localized() : LocalizedStrings.btn_subs_free.localized(), for: .normal)
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
        postButton.setTitleColor(menu == 0 ? .pictionDarkGray : .pictionGray, for: .normal)
        seriesButton.setTitleColor(menu == 0 ? .pictionGray : .pictionDarkGray, for: .normal)
    }
}

extension ProjectHeaderView {
    static func getView() -> ProjectHeaderView {
        let view = Bundle.main.loadNibNamed("ProjectHeaderView", owner: self, options: nil)!.first as! ProjectHeaderView
        return view
    }
}
