//
//  HomeNoticeViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class HomeNoticeViewModel: ViewModel {

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let noticeList: Driver<[BannerModel]>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let noticeListAction = viewWillAppear
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(BannersAPI.all)
                return Action.makeDriver(response)
            }

        let noticeListSuccess = noticeListAction.elements
            .flatMap { response -> Driver<[BannerModel]> in
                guard let noticeList = try? response.map(to: [BannerModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(noticeList)
            }

        let noticeListError = noticeListAction.error
            .flatMap { _ in Driver.just(()) }

        let noticeList = noticeListSuccess
        let showErrorPopup = noticeListError

        return Output(
            viewWillAppear: input.viewWillAppear,
            noticeList: noticeList,
            selectedIndexPath: input.selectedIndexPath,
            showErrorPopup: showErrorPopup
        )
    }
}
