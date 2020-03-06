//
//  CustomEmptyViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 05/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

// MARK: - CustomEmptyViewStyle
enum CustomEmptyViewStyle {
    case defaultLogin
    case projectPostListEmpty
    case projectSeriesListEmpty
    case subscriptionListEmpty
    case searchProjectGuide
    case searchTagGuide
    case searchListEmpty
    case transactionListEmpty
    case myProjectListEmpty
    case searchSponsorEmpty
    case membershipEmpty

    var image: UIImage {
        switch self {
        case .defaultLogin,
             .projectPostListEmpty,
             .projectSeriesListEmpty,
             .subscriptionListEmpty,
             .searchListEmpty,
             .transactionListEmpty,
             .myProjectListEmpty,
             .searchSponsorEmpty,
             .membershipEmpty:
            return #imageLiteral(resourceName: "icMoodBad")
        case .searchProjectGuide,
             .searchTagGuide:
            return #imageLiteral(resourceName: "imgSearchNull")
        }
    }

    var description: String {
        switch self {
        case .defaultLogin:
            return LocalizationKey.str_need_login.localized()
        case .projectPostListEmpty:
            return LocalizationKey.str_post_empty.localized()
        case .projectSeriesListEmpty:
            return LocalizationKey.str_series_empty.localized()
        case .subscriptionListEmpty:
            return LocalizationKey.str_subscription_empty.localized()
        case .searchListEmpty,
             .searchSponsorEmpty:
            return LocalizationKey.str_search_empty.localized()
        case .transactionListEmpty:
            return LocalizationKey.str_transaction_empty.localized()
        case .myProjectListEmpty:
            return LocalizationKey.str_project_empty.localized()
        case .searchProjectGuide:
            return LocalizationKey.str_project_search_info.localized()
        case .searchTagGuide:
            return LocalizationKey.str_tag_search_info.localized()
        case .membershipEmpty:
            return LocalizationKey.str_membership_empty.localized()
        }
    }

    var buttonTitle: String? {
        switch self {
        case .defaultLogin:
            return LocalizationKey.login.localized()
        case .projectPostListEmpty,
             .projectSeriesListEmpty,
             .subscriptionListEmpty,
             .searchListEmpty,
             .transactionListEmpty,
             .myProjectListEmpty,
             .searchSponsorEmpty,
             .searchProjectGuide,
             .searchTagGuide,
             .membershipEmpty:
            return nil
        }
    }

    var buttonImage: UIImage? {
        switch self {
        default:
            return nil
        }
    }
}

// MARK: - ViewModel
final class CustomEmptyViewModel: ViewModel {

    private let style: CustomEmptyViewStyle

    init(style: CustomEmptyViewStyle) {
        self.style = style
    }
}

// MARK: - Input & Output
extension CustomEmptyViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let btnDidTap: Driver<Void>
    }
    struct Output {
        let emptyViewStyle: Driver<CustomEmptyViewStyle>
        let buttonAction: Driver<CustomEmptyViewStyle>
    }
}

// MARK: - ViewModel Build
extension CustomEmptyViewModel {
    func build(input: Input) -> Output {
        let style = self.style

        // 화면이 보여지기 전에 style 전달
        let emptyViewStyle = input.viewWillAppear
            .map { style }

        // 버튼 눌렀을 때 style 전달
        let buttonAction = input.btnDidTap
            .map { style }

        return Output(
            emptyViewStyle: emptyViewStyle,
            buttonAction: buttonAction
        )
    }
}

