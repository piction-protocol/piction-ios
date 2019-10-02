//
//  ProjectInfoViewController.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class ProjectInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var synopsisLabel: UILabel!
    @IBOutlet weak var sendDonationButton: UIButton!

    private func openSendDonationViewController(loginId: String) {
        let vc = SendDonationViewController.make(loginId: loginId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }
}

extension ProjectInfoViewController: ViewModelBindable {
    typealias ViewModel = ProjectInfoViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = ProjectInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            sendDonationBtnDidTap: sendDonationButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                let userPictureWithIC = "\(projectInfo.user?.picture ?? "")?w=240&h=240&quality=80&output=webp"
                if let url = URL(string: userPictureWithIC) {
                    self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                }
                self?.writerLabel.text = projectInfo.user?.username
                self?.loginIdLabel.text = "@\(projectInfo.user?.loginId ?? "")"
                self?.synopsisLabel.text = projectInfo.synopsis ?? ""
            })
            .disposed(by: disposeBag)

        output
            .openSendDonationViewController
            .drive(onNext: { [weak self] loginId in
                self?.openSendDonationViewController(loginId: loginId)
            })
            .disposed(by: disposeBag)
    }
}
