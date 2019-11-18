//
//  HomeTrendingViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class HomeTrendingViewModel: ViewModel {

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let trendingList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let showErrorPopup: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let trendingListAction = viewWillAppear
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.trending)
                return Action.makeDriver(response)
            }

        let trendingListSuccess = trendingListAction.elements
            .flatMap { response -> Driver<[ProjectModel]> in
                guard let projectList = try? response.map(to: [ProjectModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(projectList)
            }

        let trendingListError = trendingListAction.error
            .flatMap { _ in Driver.just(()) }

        let trendingList = trendingListSuccess
        let showErrorPopup = trendingListError

        return Output(
            viewWillAppear: input.viewWillAppear,
            trendingList: trendingList,
            selectedIndexPath: input.selectedIndexPath,
            showErrorPopup: showErrorPopup
        )
    }
}
