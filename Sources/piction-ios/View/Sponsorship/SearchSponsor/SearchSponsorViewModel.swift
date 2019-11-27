//
//  SearchSponsorViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 19/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class SearchSponsorViewModel: ViewModel {

    var page = 0
    var sections: [UserModel] = []
    var shouldInfiniteScroll = true

    var loadNextTrigger = PublishSubject<Void>()

    var searchText = BehaviorSubject<String>(value: "")

    init() {}

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let searchText: Driver<String>
        let selectedIndexPath: Driver<IndexPath>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let searchList: Driver<[UserModel]>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let openSendDonationViewController: Driver<IndexPath>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let viewWillDisappear = input.viewWillDisappear

        let openSendDonationViewController = input.selectedIndexPath

        let inputSearchText = input.searchText
            .distinctUntilChanged()
            .flatMap { [weak self] searchText -> Driver<Void> in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
                self?.searchText.onNext(searchText)
                return Driver.just(())
            }

        let loadNext = loadNextTrigger.asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                guard let `self` = self, self.shouldInfiniteScroll else {
                    return Driver.empty()
                }
                return Driver.just(())
            }

        let searchTextIsEmpty = self.searchText.asDriver(onErrorDriveWith: .empty())
            .filter { $0 == "" }
            .flatMap { _ -> Driver<[UserModel]> in
                return Driver.just([])
            }

        let searchSponsorGuideEmptyView = Driver.merge(viewWillAppear, inputSearchText)
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 == "" }
            .flatMap { [weak self] _ -> Driver<CustomEmptyViewStyle> in
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = false
                return Driver.just(.searchSponsorGuide)
            }

        let searchAction = Driver.merge(inputSearchText, loadNext)
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .flatMap { [weak self] searchText -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(SearchAPI.writer(writer: searchText, page: self.page + 1, size: 20))
                return Action.makeDriver(response)
            }

        let searchActionSuccess = searchAction.elements
            .flatMap { [weak self] response -> Driver<[UserModel]> in
                guard let `self` = self else { return Driver.empty() }
                guard let pageList = try? response.map(to: PageViewResponse<UserModel>.self) else {
                    return Driver.empty()
                }
                self.page = self.page + 1
                if (pageList.pageable?.pageNumber ?? 0) >= (pageList.totalPages ?? 0) - 1 {
                    self.shouldInfiniteScroll = false
                }
                let users: [UserModel] = pageList.content ?? []
                self.sections.append(contentsOf: users)
                return Driver.just(self.sections)
            }

        let searchList = Driver.merge(searchActionSuccess, searchTextIsEmpty)

        let embedEmptyView = searchList
            .withLatestFrom(self.searchText.asDriver(onErrorDriveWith: .empty()))
            .filter { $0 != "" }
            .withLatestFrom(searchList)
            .flatMap { searchList -> Driver<CustomEmptyViewStyle> in
                if searchList.count == 0 {
                    return Driver.just(.searchSponsorEmpty)
                }
                return Driver.empty()
            }

        let embedEmptyViewController = Driver.merge(searchSponsorGuideEmptyView, embedEmptyView)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            searchList: searchList,
            embedEmptyViewController: embedEmptyViewController,
            openSendDonationViewController: openSendDonationViewController
        )
    }
}
