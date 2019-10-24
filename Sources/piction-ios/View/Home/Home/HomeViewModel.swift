//
//  HomeViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class HomeViewModel: ViewModel {

    var loadTrigger = PublishSubject<Void>()

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let projectList: Driver<HomeBySection>
        let openProjectViewController: Driver<IndexPath>
        let openErrorPopup: Driver<Void>
        let isFetching: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let openProjectViewController = input.selectedIndexPath

        let recommendedProjectAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(RecommendationAPI.all(size: 10))
                return Action.makeDriver(response)
            }

        let recommendedProjectListSuccess = recommendedProjectAction.elements
            .flatMap { response -> Driver<[HomeItemType]> in
                guard let projectList = try? response.map(to: [ProjectModel].self) else {
                    return Driver.empty()
                }

                let projects: [HomeItemType] = projectList.map { .recommendedProject(project: $0) }
                return Driver.just(projects)
            }

        let recommendedProjectListError = recommendedProjectAction.error
            .flatMap { response -> Driver<[HomeItemType]> in
                return Driver.just([])
            }

        let recommendedProject = Driver.merge(recommendedProjectListSuccess, recommendedProjectListError)
            .flatMap { projects in Driver.just(projects) }

        let noticeListAction = Driver.merge(viewWillAppear, input.refreshControlDidRefresh, loadTrigger.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(BannersAPI.all)
                return Action.makeDriver(response)
            }

        let noticeListSuccess = noticeListAction.elements
            .flatMap { response -> Driver<[HomeItemType]> in
                guard let bannerList = try? response.map(to: [BannerModel].self) else {
                    return Driver.empty()
                }

                let notices: [HomeItemType] = bannerList.map { .notice(notice: $0) }
                return Driver.just(notices)
            }

        let noticeListError = noticeListAction.error
            .flatMap { response -> Driver<[HomeItemType]> in
                return Driver.just([])
            }

        let notices = Driver.merge(noticeListSuccess, noticeListError)
            .flatMap { notices in Driver.just(notices) }

        let projectList = Driver.zip(recommendedProject, notices)
            .flatMap { projects, notices -> Driver<HomeBySection> in

                var section: [HomeItemType] = []
                if projects.count > 0 {
                    section.append(.recommendedHeader)
                    section.append(contentsOf: projects)
                }
                if notices.count > 0 {
                    section.append(.noticeHeader)
                    section.append(contentsOf: notices)
                }
                return Driver.just(HomeBySection.Section(title: "home", items: section))
            }

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(projectList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let openErrorPopup = Driver.zip(recommendedProjectAction.error, noticeListAction.error)
            .flatMap { _ -> Driver<Void> in
                return Driver.just(())
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            projectList: projectList,
            openProjectViewController: openProjectViewController,
            openErrorPopup: openErrorPopup,
            isFetching: refreshAction.isExecuting
        )
    }
}