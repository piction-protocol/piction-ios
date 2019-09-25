//
//  PostHeaderViewController.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class PostHeaderViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var seriesNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
}

extension PostHeaderViewController: ViewModelBindable {
    typealias ViewModel = PostHeaderViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = PostHeaderViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .headerInfo
            .drive(onNext: { [weak self] (postItem, userInfo) in
                let userPictureWithIC = "\(userInfo.picture ?? "")?w=240&h=240&quality=80&output=webp"
                if let url = URL(string: userPictureWithIC) {
                    self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                }
                self?.seriesNameLabel.isHidden = postItem.series?.name == nil
                self?.seriesNameLabel.text = "시리즈 · \(postItem.series?.name ?? "")"
                self?.writerLabel.text = userInfo.username
                self?.titleLabel.text = postItem.title
            })
            .disposed(by: disposeBag)
    }
}
