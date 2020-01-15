//
//  EmptyViewController.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class EmptyViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
}

extension EmptyViewController: ViewModelBindable {

    typealias ViewModel = EmptyViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = EmptyViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .emptyViewStyle
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.emptyImageView.image = style.image
                self.descriptionLabel.text = style.description
            })
            .disposed(by: disposeBag)
    }
}
