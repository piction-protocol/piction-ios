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
}

class ProjectHeaderView: GSKStretchyHeaderView {
    weak var delegate: ProjectHeaderViewDelegate?

    let menuHeight: CGFloat = 48

    @IBOutlet weak var thumbnailImageView: UIImageView! {
        didSet {
            let gradientLayer = CAGradientLayer()
            let color1 = UIColor(white: 0.0, alpha: 0.38).cgColor
            let color2 = UIColor.clear.cgColor
            gradientLayer.colors = [color1, color2]
            gradientLayer.locations = [0.0, 1.0]
            let width = SCREEN_W > SCREEN_H ? SCREEN_W : SCREEN_H
            gradientLayer.frame = CGRect(x: 0, y: 0, width: width, height: SCREEN_W / 3)
            thumbnailImageView.layer.addSublayer(gradientLayer)
        }
    }

    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var seriesButton: UIButton!

    @IBOutlet weak var maskImage: VisualEffectView!
    @IBOutlet weak var naviView: UIView!
    @IBOutlet var naviViewImageHeight: NSLayoutConstraint!
    @IBOutlet weak var projectDetailView: UIView!

    @IBAction func postBtnDidTap(_ sender: Any) {
        delegate?.postBtnDidTap()
    }

    @IBAction func seriesBtnDidTap(_ sender: Any) {
        delegate?.seriesBtnDidTap()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        minimumContentHeight = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT + menuHeight

        setMaximumContentHeight(detailHeight: projectDetailView.frame.size.height)

        naviViewImageHeight.constant = STATUS_HEIGHT + DEFAULT_NAVIGATION_HEIGHT

        expansionMode = .topOnly

        thumbnailImageView.contentMode = .scaleAspectFill
    }

    func configure(with projectInfo: ProjectModel) {
        if let thumbnail = projectInfo.thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-post-960-x-360"), completed: nil)
            }
        }
    }

    func setMaximumContentHeight(detailHeight: CGFloat) {
        let thumbnailWidth = SCREEN_W < SCREEN_H ? SCREEN_W : SCREEN_H
        let projectDetailPosY = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad ? thumbnailWidth / 2 - 70 : thumbnailWidth - 30
        maximumContentHeight = projectDetailPosY + detailHeight + menuHeight - STATUS_HEIGHT - DEFAULT_NAVIGATION_HEIGHT
    }

    func controlMenuButton(menu: Int) {
        if #available(iOS 13.0, *) {
            postButton.backgroundColor = menu == 0 ? .clear : .systemBackground
            seriesButton.backgroundColor = menu == 0 ? .systemBackground : .clear
        } else {
            postButton.backgroundColor = menu == 0 ? .clear : .white
            seriesButton.backgroundColor = menu == 0 ? .white : .clear
        }
        postButton.setTitleColor(menu == 0 ? .pictionBlue : .pictionGray, for: .normal)
        seriesButton.setTitleColor(menu == 0 ? .pictionGray : .pictionBlue, for: .normal)
    }
}

extension ProjectHeaderView {
    static func getView() -> ProjectHeaderView {
        let view = Bundle.main.loadNibNamed("ProjectHeaderView", owner: self, options: nil)!.first as! ProjectHeaderView
        return view
    }
}
