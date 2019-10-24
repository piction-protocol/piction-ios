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

enum CustomEmptyViewStyle {
    case defaultLogin
    case projectPostListEmpty
    case projectSeriesListEmpty
    case sponsorshipListEmpty
    case sponsorshipListLogin
    case subscriptionListEmpty
    case searchProjectGuide
    case searchTagGuide
    case searchListEmpty
    case transactionListEmpty
    case myProjectListEmpty
    case searchSponsorEmpty
    case searchSponsorGuide

    var image: UIImage {
        switch self {
        case .defaultLogin,
             .projectPostListEmpty,
             .projectSeriesListEmpty,
             .subscriptionListEmpty,
             .searchListEmpty,
             .transactionListEmpty,
             .myProjectListEmpty,
             .searchSponsorEmpty:
            return #imageLiteral(resourceName: "icMoodBad")
        case .sponsorshipListEmpty,
             .sponsorshipListLogin:
            return #imageLiteral(resourceName: "icStartup")
        case .searchProjectGuide,
             .searchSponsorGuide,
             .searchTagGuide:
            return #imageLiteral(resourceName: "imgSearchNull")
        }
    }

    var description: String {
        switch self {
        case .defaultLogin,
             .sponsorshipListLogin:
            return LocalizedStrings.str_need_login.localized()
        case .projectPostListEmpty:
            return LocalizedStrings.str_post_empty.localized()
        case .projectSeriesListEmpty:
            return LocalizedStrings.str_series_empty.localized()
        case .sponsorshipListEmpty:
            return LocalizedStrings.str_empty_sponsorship.localized()
        case .subscriptionListEmpty:
            return LocalizedStrings.str_subscription_empty.localized()
        case .searchListEmpty,
             .searchSponsorEmpty:
            return LocalizedStrings.str_search_empty.localized()
        case .transactionListEmpty:
            return LocalizedStrings.str_transaction_empty.localized()
        case .myProjectListEmpty:
            return LocalizedStrings.str_project_empty.localized()
        case .searchProjectGuide:
            return LocalizedStrings.str_project_search_info.localized()
        case .searchSponsorGuide:
            return LocalizedStrings.str_creator_search_info.localized()
        case .searchTagGuide:
            return LocalizedStrings.str_tag_search_info.localized()
        }
    }

    var buttonTitle: String? {
        switch self {
        case .defaultLogin,
             .sponsorshipListLogin:
            return LocalizedStrings.login.localized()
        case .searchSponsorGuide:
            return LocalizedStrings.btn_qrcode.localized()
        case .projectPostListEmpty,
             .projectSeriesListEmpty,
             .sponsorshipListEmpty,
             .subscriptionListEmpty,
             .searchListEmpty,
             .transactionListEmpty,
             .myProjectListEmpty,
             .searchSponsorEmpty,
             .searchProjectGuide,
             .searchTagGuide:
            return nil
        }
    }

    var buttonImage: UIImage? {
        switch self {
        case .searchSponsorGuide:
            return #imageLiteral(resourceName: "icQrcode")
        default:
            return nil
        }
    }
}

final class CustomEmptyViewModel: ViewModel {

    private let style: CustomEmptyViewStyle

    init(style: CustomEmptyViewStyle) {
        self.style = style
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let btnDidTap: Driver<Void>
    }

    struct Output {
        let emptyViewStyle: Driver<CustomEmptyViewStyle>
        let buttonAction: Driver<CustomEmptyViewStyle>
    }

    func build(input: Input) -> Output {
        let emptyViewStyle = input.viewWillAppear
            .flatMap { return Driver.just(self.style) }

        let buttonAction = input.btnDidTap
            .flatMap { return Driver.just(self.style) }

        return Output(
            emptyViewStyle: emptyViewStyle,
            buttonAction: buttonAction
        )
    }
}

