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

protocol ProjectHeaderViewProtocol: class {
    func postBtnDidTap()
    func seriesBtnDidTap()
    func subscriptionBtnDidTap()
}

class ProjectHeaderView: GSKStretchyHeaderView {

    weak var delegate: ProjectHeaderViewProtocol?

    @IBOutlet weak var subscriptionButton: UIButtonExtension!
    @IBOutlet weak var thumbnailImageView: UIImageView! {
        didSet {
            let gradientLayer = CAGradientLayer()
            let color1 = UIColor(white: 0.0, alpha: 0.38).cgColor
            let color2 = UIColor.clear.cgColor
            gradientLayer.colors = [color1, color2]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.frame = CGRect(x: 0, y: 0, width: SCREEN_W, height: SCREEN_W / 3)
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

    @IBAction func postBtnDidTap(_ sender: Any) {
        controlMenuButton(menu: 0)
        delegate?.postBtnDidTap()
    }

    @IBAction func seriesBtnDidTap(_ sender: Any) {
        controlMenuButton(menu: 1)
        delegate?.seriesBtnDidTap()
    }

    @IBAction func subscriptionBtnDidTap(_ sender: Any) {
        delegate?.subscriptionBtnDidTap()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        minimumContentHeight = DEFAULT_NAVIGATION_HEIGHT + 52
        maximumContentHeight = SCREEN_W + 274
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

        let userPictureWithIC = "\(profileImage ?? "")?w=240&h=240&quality=80&output=webp"
        if let url = URL(string: userPictureWithIC) {
            profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
        }
        writerLabel.text = writerName
        loginIdLabel.text = "@\(writerloginId ?? "")"
        subscriptionCountLabel.text = "구독자 수 \(subscriptionUserCount ?? 0)"
    }

    func configureSubscription(isWriter: Bool, isSubscribing: Bool) {
        if isSubscribing {
            subscriptionButton.backgroundColor = UIColor(r: 242, g: 242, b: 242)
            subscriptionButton.setTitle("프로젝트 구독 중", for: .normal)
            subscriptionButton.setTitleColor(UIColor(r: 191, g: 191, b: 191), for: .normal)
        } else {
            subscriptionButton.backgroundColor = UIColor(r: 51, g: 51, b: 51)
            subscriptionButton.setTitle(isWriter ? "새 포스트" : "무료로 구독하기", for: .normal)
            subscriptionButton.setTitleColor(.white, for: .normal)
        }
    }

    private func controlMenuButton(menu: Int) {
        postButton.backgroundColor = menu == 0 ? .clear : .white
        postButton.setTitleColor(menu == 0 ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 191, g: 191, b: 191), for: .normal)
        seriesButton.backgroundColor = menu == 0 ? .white : .clear
        seriesButton.setTitleColor(menu == 0 ? UIColor(r: 191, g: 191, b: 191) : UIColor(r: 51, g: 51, b: 51), for: .normal)
    }
}

extension ProjectHeaderView {
    static func getView() -> ProjectHeaderView {
        let view = Bundle.main.loadNibNamed("ProjectHeaderView", owner: self, options: nil)!.first as! ProjectHeaderView
        return view
    }
}
