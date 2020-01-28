//
//  EmptyViewModel.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

enum EmptyViewStyle {
    case seriesListEmpty

    var image: UIImage {
        switch self {
        case .seriesListEmpty:
            return #imageLiteral(resourceName: "icMoodBad")
        }
    }

    var description: String {
        switch self {
        case .seriesListEmpty:
            return LocalizationKey.str_series_empty.localized()
        }
    }

    var buttonTitle: String? {
        switch self {
        case .seriesListEmpty:
            return nil
        }
    }
}

final class EmptyViewModel: ViewModel {

    private let style: EmptyViewStyle

    init(style: EmptyViewStyle) {
        self.style = style
    }

    struct Input {
        let viewWillAppear: Driver<Void>
    }

    struct Output {
        let emptyViewStyle: Driver<EmptyViewStyle>
    }

    func build(input: Input) -> Output {
        let emptyViewStyle = input.viewWillAppear
            .flatMap { return Driver.just(self.style) }

        return Output(
            emptyViewStyle: emptyViewStyle
        )
    }
}

