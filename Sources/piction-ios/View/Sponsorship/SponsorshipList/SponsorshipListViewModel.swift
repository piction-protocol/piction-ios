//
//  SponsorshipListViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 02/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

enum SponsorshipListSection {
    case button(type: SponsorshipListButtonType)
    case header
    case list(model: SponsorshipModel)
}

final class SponsorshipListViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var sections: [SectionType<SponsorshipListSection>] = []

    var loadRetryTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let refreshControlDidRefresh: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let sponsorshipList: Driver<[SectionType<SponsorshipListSection>]>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let isFetching: Driver<Bool>
        let activityIndicator: Driver<Bool>
        let showErrorPopup: Driver<Void>
        let refreshSession: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let viewWillDisappear = input.viewWillDisappear

        let selectedIndexPath = input.selectedIndexPath

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshAmount = updater.refreshAmount.asDriver(onErrorDriveWith: .empty())

        let refreshControlDidRefresh = input.refreshControlDidRefresh

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent, refreshAmount, refreshControlDidRefresh)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.sections = []
                return Driver.just(())
            }

        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { _ in Driver.just(()) }

        let sponsorshipListAction = Driver.merge(initialLoad, loadRetry)
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SponsorshipsAPI.get(page: 1, size: UI_USER_INTERFACE_IDIOM() == .pad ? 10 : 5))
                return Action.makeDriver(response)
            }

        let sponsorshipListSuccess = sponsorshipListAction.elements
            .flatMap { [weak self] response -> Driver<[SectionType<SponsorshipListSection>]> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<SponsorshipModel>.self) else {
                    return Driver.empty()
                }
                let headerSection: [SponsorshipListSection] = [
                    SponsorshipListSection.button(type: .sponsorship),
                    SponsorshipListSection.button(type: .history),
                    SponsorshipListSection.header,
                ]
                self.sections.append(SectionType<SponsorshipListSection>.Section(title: "header", items: headerSection))

                let sponsorList: [SponsorshipListSection] = (pageList.content ?? []).map { .list(model: $0) }

                self.sections.append(SectionType<SponsorshipListSection>.Section(title: "list", items: sponsorList))

                return Driver.just(self.sections)
            }

        let sponsorshipListError = sponsorshipListAction.error
            .flatMap { response -> Driver<Void> in
                let errorMsg = response as? ErrorType
                switch errorMsg {
                case .unauthorized:
                    return Driver.empty()
                default:
                    return Driver.just(())
                }
            }

        let sponsorshipEmptyList = sponsorshipListAction.error
            .flatMap { _ -> Driver<[SectionType<SponsorshipListSection>]> in
                return Driver.just([])
            }

        let sponsorshipList = Driver.merge(sponsorshipListSuccess, sponsorshipEmptyList)
        let showErrorPopup = sponsorshipListError

        let embedEmptyLoginView = sponsorshipListAction.error
            .flatMap { response -> Driver<CustomEmptyViewStyle> in
                guard let errorMsg = response as? ErrorType else {
                    return Driver.empty()
                }
                switch errorMsg {
                case .unauthorized:
                    return Driver.just(.sponsorshipListLogin)
                default:
                    return Driver.empty()
                }
            }

        let embedEmptyView = sponsorshipListAction.elements
            .flatMap { response -> Driver<CustomEmptyViewStyle> in
                guard let pageList = try? response.map(to: PageViewResponse<SponsorshipModel>.self) else {
                    return Driver.empty()
                }
                if (pageList.content?.count ?? 0) == 0 {
                    return Driver.just(.sponsorshipListEmpty)
                }
                return Driver.empty()
            }

        let embedEmptyViewController = Driver.merge(embedEmptyView, embedEmptyLoginView)

        let refreshAction = input.refreshControlDidRefresh
            .withLatestFrom(sponsorshipList)
            .flatMap { _ -> Driver<Action<Void>> in
                return Action.makeDriver(Driver.just(()))
            }

        let showActivityIndicator = Driver.merge(initialLoad, loadRetry)
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = sponsorshipList
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: viewWillDisappear, 
            sponsorshipList: sponsorshipList,
            selectedIndexPath: selectedIndexPath,
            embedEmptyViewController: embedEmptyViewController,
            isFetching: refreshAction.isExecuting,
            activityIndicator: activityIndicator,
            showErrorPopup: showErrorPopup,
            refreshSession: refreshSession
        )
    }
}
