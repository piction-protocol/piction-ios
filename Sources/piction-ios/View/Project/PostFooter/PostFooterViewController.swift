//
//  PostFooterViewController.swift
//  PictionView
//
//  Created by jhseo on 11/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class PostFooterViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var likeView: UIViewExtension! {
        didSet {
            likeView.layer.shadowOpacity = 1
            likeView.layer.shadowColor = UIColor(r: 0, g: 0, b: 0, a: 0.1).cgColor
            likeView.layer.shadowRadius = 4
            likeView.layer.shadowOffset = CGSize(width: 0, height: 1)
            likeView.layer.masksToBounds = false
            likeView.layer.borderColor = UIColor.white.cgColor
            likeView.layer.borderWidth = 0.5
        }
    }
    @IBOutlet weak var likeImageView: UIImageView!
    @IBOutlet weak var likeCountLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!


    private func controlLikeButton(isLike: Bool, likeCount: Int) {
        self.likeCountLabel.textColor = isLike ? UIColor(r: 26, g: 146, b: 255) : UIColor(r: 191, g: 191, b: 191)
        self.likeCountLabel.text = String(likeCount)
        self.likeButton.isEnabled = !isLike
        self.likeImageView.image = isLike ? #imageLiteral(resourceName: "icFavoriteOn") : #imageLiteral(resourceName: "icFavoriteOff")
    }

    private func openSignInViewController() {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }
}

extension PostFooterViewController: ViewModelBindable {
    typealias ViewModel = PostFooterViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = PostFooterViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            likeBtnDidTap: likeButton.rx.tap.asDriver().throttle(1, latest: true)
        )

        let output = viewModel.build(input: input)

        output
            .footerInfo
            .drive(onNext: { [weak self] (postItem, seriesPostItems, isLike) in
                self?.controlLikeButton(isLike: isLike, likeCount: postItem.likeCount ?? 0)
                self?.dateLabel.text = postItem.createdAt?.toString(format: LocalizedStrings.str_post_date_format.localized())
            })
            .disposed(by: disposeBag)

        output
            .addLike
            .drive(onNext: { [weak self] isExecuting in
                if isExecuting {
                    self?.controlLikeButton(isLike: true, likeCount: (Int(self?.likeCountLabel.text ?? "0") ?? 0) + 1)
                }
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] uri in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)
    }
}


