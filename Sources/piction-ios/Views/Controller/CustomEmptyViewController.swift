//
//  CustomEmptyViewController.swift
//  PictionSDK
//
//  Created by jhseo on 05/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

// MARK: - UIViewController
final class CustomEmptyViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var button: UIButton!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CustomEmptyViewController: ViewModelBindable {
    typealias ViewModel = CustomEmptyViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = CustomEmptyViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            btnDidTap: button.rx.tap.asDriver() // 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // emptyView의 style에 맞게 버튼과 description text 출력
        output
            .emptyViewStyle
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.emptyImageView.image = style.image
                self.descriptionLabel.text = style.description

                self.button.isHidden = style.buttonTitle == nil
                self.button.setTitle(style.buttonTitle, for: .normal)
                if style.buttonImage != nil {
                    self.button.imageView?.contentMode = .scaleAspectFit
                    self.button.setImage(style.buttonImage, for: .normal)
                }
            })
            .disposed(by: disposeBag)

        // 버튼을 누를 경우 처리
        output
            .buttonAction
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                switch style {
                case .defaultLogin:
                    self.openView(type: .signIn, openType: .swipePresent)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
}
