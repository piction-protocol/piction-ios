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
import RxPictionSDK

final class SponsorshipListViewModel: InjectableViewModel {

    typealias Dependency = (
        UpdaterProtocol
    )

    let updater: UpdaterProtocol

    var sections: [SponsorshipListBySection] = []

    init(dependency: Dependency) {
        (updater) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let sponsorshipList: Driver<[SponsorshipListBySection]>
        let selectedIndexPath: Driver<IndexPath>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let viewWillDisappear = input.viewWillDisappear

        let selectedIndexPath = input.selectedIndexPath

        let refreshSession = updater.refreshSession.asDriver(onErrorDriveWith: .empty())
        let refreshContent = updater.refreshContent.asDriver(onErrorDriveWith: .empty())
        let refreshAmount = updater.refreshAmount.asDriver(onErrorDriveWith: .empty())

        let initialLoad = Driver.merge(viewWillAppear, refreshSession, refreshContent, refreshAmount)
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                self.sections = []
                return Driver.just(())
            }

        let sponsorshipListAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(SponsorshipsAPI.get(page: 1, size: 5))
                return Action.makeDriver(response)
            }

        let sponsorshipListSuccess = sponsorshipListAction.elements
            .flatMap { [weak self] response -> Driver<[SponsorshipListBySection]> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<SponsorshipModel>.self) else {
                    return Driver.empty()
                }
                let headerSection: [SponsorshipListItemType] = [
                    SponsorshipListItemType.button(type: .sponsorship),
                    SponsorshipListItemType.button(type: .history),
                    SponsorshipListItemType.header,
                ]
                self.sections.append(SponsorshipListBySection.Section(title: "header", items: headerSection))

                let sponsorList: [SponsorshipListItemType] = (pageList.content ?? []).map { .list(model: $0) }

                self.sections.append(SponsorshipListBySection.Section(title: "list", items: sponsorList))

                return Driver.just(self.sections)
            }

        let sponsorshipListError = sponsorshipListAction.error
            .flatMap { _ -> Driver<[SponsorshipListBySection]> in
                return Driver.just([])
            }

        let sponsorshipList = Driver.merge(sponsorshipListSuccess, sponsorshipListError)

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

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: viewWillDisappear, 
            sponsorshipList: sponsorshipList,
            selectedIndexPath: selectedIndexPath,
            embedEmptyViewController: embedEmptyViewController
        )
    }
}
