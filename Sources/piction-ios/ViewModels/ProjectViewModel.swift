//
//  ProjectViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

// MARK: - ContentsSection
enum ContentsSection {
    case postCardTypeList(post: PostModel, subscriptionInfo: SponsorshipModel?, isWriter: Bool)
    case postListTypeList(post: PostModel, subscriptionInfo: SponsorshipModel?, isWriter: Bool)
    case seriesPostList(post: PostModel, subscriptionInfo: SponsorshipModel?, number: Int)
    case seriesList(series: SeriesModel)
}

// MARK: - ViewModel
final class ProjectViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    let uri: String

    var page = 0
    var isWriter: Bool = false
    var shouldInfiniteScroll = true
    var sections: [ContentsSection] = []
    var loadNextTrigger = PublishSubject<Void>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri) = dependency
    }
}

// MARK: - Input & Output
extension ProjectViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let changeMenu: Driver<Int>
        let infoBtnDidTap: Driver<Void>
        let shareBtnDidTap: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let deletePost: Driver<Int>
        let deleteSeries: Driver<Int>
        let updateSeries: Driver<(String, SeriesModel)>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let viewWillLayoutSubviews: Driver<Void>
        let traitCollectionDidChange: Driver<Void>
        let embedProjectDetailViewController: Driver<String>
        let projectInfo: Driver<ProjectModel>
        let contentList: Driver<SectionType<ContentsSection>>
        let embedEmptyViewController: Driver<CustomEmptyViewStyle>
        let selectedIndexPath: Driver<IndexPath>
        let openProjectInfoViewController: Driver<String>
        let openSharePopup: Driver<ProjectModel>
        let activityIndicator: Driver<Bool>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension ProjectViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri) = (self.firebaseManager, self.updater, self.uri)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("프로젝트_\(uri)")
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        // 세션 갱신 시
        let refreshSession = updater.refreshSession
            .asDriver(onErrorDriveWith: .empty())

        // 컨텐츠의 내용 갱신 필요 시
        let refreshContent = updater.refreshContent
            .asDriver(onErrorDriveWith: .empty())

        // 메뉴 변경 시
        let updateSelectedProjectMenu = input.changeMenu

        // 컨텐츠의 내용 갱신 필요 시, 세션 갱신 시
        // 현재 선택된 메뉴 전달
        let refreshMenu = Driver.merge(refreshContent, refreshSession)
            .withLatestFrom(updateSelectedProjectMenu)

        // infinite scroll로 다음 페이지 호출
        let loadNext = loadNextTrigger
            .asDriver(onErrorDriveWith: .empty())
            .filter { self.shouldInfiniteScroll }

        // 최초 진입 시 ProjectDetailViewController embed
        let embedProjectDetailViewController = initialLoad
            .map { self.uri }

        // 다음 페이지 호출 시
        // 현재 선택된 메뉴 전달
        let loadNextMenu = loadNext
            .withLatestFrom(updateSelectedProjectMenu)

        // 메뉴 변경 시, 컨텐츠의 내용 갱신 필요 시, 세션 갱신 시
        // 메뉴가 0이면(Post)
        let selectPostMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 0 }
            .map { _ in Void() }
            .do(onNext: { [weak self] _ in
                // 데이터 초기화
                self?.page = 0
                self?.sections = []
                self?.shouldInfiniteScroll = true
            })

        // 메뉴 변경 시, 컨텐츠의 내용 갱신 필요 시, 세션 갱신 시
        // 메뉴가 1이면(Series)
        let selectSeriesMenu = Driver.merge(updateSelectedProjectMenu, refreshMenu)
            .filter { $0 == 1 }
            .map { _ in Void() }
            .do(onNext: { [weak self] _ in
                // 데이터 초기화
                self?.page = 1
                self?.sections = []
                self?.shouldInfiniteScroll = false
            })

        let postSubscriptionInfoAction = Driver.merge(updateSelectedProjectMenu, refreshMenu, loadNextMenu)
            .filter { $0 == 0 }

        let seriesSubscriptionInfoAction = refreshMenu
            .filter { $0 == 1 }

        // 구독중인 멤버십 정보 호출
        let subscriptionInfoAction = Driver.merge(postSubscriptionInfoAction, seriesSubscriptionInfoAction)
            .map{ _ in MembershipAPI.getSponsoredMembership(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 구독중인 멤버십 정보 호출 성공 시
        let subscriptionInfoSuccess = subscriptionInfoAction.elements
            .map { try? $0.map(to: SponsorshipModel.self) }
            .flatMap(Driver<SponsorshipModel?>.from)

        // 구독중인 멤버십 정보 호출 에러 시
        let subscriptionInfoError = subscriptionInfoAction.error
            .map { _ in SponsorshipModel?(nil) }

        // 구독중인 멤버십 정보
        let projectSubscriptionInfo = Driver.merge(subscriptionInfoSuccess, subscriptionInfoError)

        // 포스트 메뉴 선택 시, 시리즈 메뉴 선택 시, infinite scroll로 다음 페이지 호출 시
        // 프로젝트 정보 호출
        let loadProjectInfoAction = Driver.merge(selectPostMenu, selectSeriesMenu, loadNext)
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 프로젝트 정보 호출 성공 시
        let loadProjectInfoSuccess = loadProjectInfoAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)

        // 프로젝트 정보 호출 에러 시
        let loadProjectInfoError = loadProjectInfoAction.error
            .map { _ in ProjectModel.from([:])! }

        // 프로젝트 정보
        let loadProjectInfo = Driver.merge(loadProjectInfoSuccess, loadProjectInfoError)

        // 최초 진입 시, 세션 갱신 시
        // 유저 정보 호출
        let userInfoAction = Driver.merge(initialLoad, refreshSession)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 유저 정보 호출 성공 시
        let currentUserInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        // 유저 정보 호출 에러 시
        let currentUserInfoError = userInfoAction.error
            .map { _ in UserModel.from([:])! }

        // 유저 정보
        let currentUserInfo = Driver.merge(currentUserInfoSuccess, currentUserInfoError)

        // 크리에이터 인지 확인
        let isWriter = Driver.combineLatest(loadProjectInfo, currentUserInfo)
            .map { $0.user?.loginId == $1.loginId }
            .do(onNext: { [weak self] isWriter in
                self?.isWriter = isWriter
            })

        // 포스트 메뉴 선택 시, infinite scroll로 다음 페이지 호출 시, 크리에이터가 아니면
        // 포스트 목록 호출
        let loadOthersPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { !$0.1 }
            .map { _ in PostAPI.all(uri: uri, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 메뉴 선택 시, infinite scroll로 다음 페이지 호출 시, 크리에이터가이면
        // 크리에이터 포스트 목록 호출
        let loadWriterPostAction = Driver.zip(Driver.merge(selectPostMenu, loadNext), isWriter)
            .filter { $0.1 }
            .map { _ in CreatorAPI.posts(uri: uri, page: self.page + 1, size: 20) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 목록 호출 액션
        let loadPostAction = Driver.merge(loadOthersPostAction, loadWriterPostAction)

        // 포스트 목록 호출 성공 시
        let loadPostSuccess = loadPostAction.elements
            .map { try? $0.map(to: PageViewResponse<PostModel>.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] pageList in
                guard
                    let `self` = self,
                    let pageNumber = pageList.pageable?.pageNumber,
                    let totalPages = pageList.totalPages
                else { return }

                // 페이지 증가
                self.page = self.page + 1

                // 현재 페이지가 전체페이지보다 작을때만 infiniteScroll 동작
                self.shouldInfiniteScroll = pageNumber < totalPages - 1
            })

        // 포스트 목록 호출 성공 시
        // 포스트 카드 타입 섹션 생성
        let postCardTypeSection = loadPostSuccess
            .withLatestFrom(loadProjectInfo) { ($0, $1) }
            .filter { $1.viewType == "CARD" }
            .withLatestFrom(projectSubscriptionInfo) { ($0.0, $1) }
            .withLatestFrom(isWriter) { ($0.0, $0.1, $1) }
            .map { (postList, subscriptionInfo, isWriter) in (postList.content ?? []).map { .postCardTypeList(post: $0, subscriptionInfo: subscriptionInfo, isWriter: isWriter) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        // 포스트 목록 호출 성공 시
        // 포스트 리스트 타입 섹션 생성
        let postListTypeSection = loadPostSuccess
            .withLatestFrom(loadProjectInfo) { ($0, $1) }
            .filter { $1.viewType == "LIST" }
            .withLatestFrom(projectSubscriptionInfo) { ($0.0, $1) }
            .withLatestFrom(isWriter) { ($0.0, $0.1, $1) }
            .map { (postList, subscriptionInfo, isWriter) in (postList.content ?? []).map { .postListTypeList(post: $0, subscriptionInfo: subscriptionInfo, isWriter: isWriter) } }
            .map { self.sections.append(contentsOf: $0) }
            .map { SectionType<ContentsSection>.Section(title: "post", items: self.sections) }

        // 시리즈 메뉴 선택 시
        // 시리즈 목록 호출
        let loadSeriesListAction = selectSeriesMenu
            .map { _ in SeriesAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 시리즈 목록 호출 성공 시
        let loadSeriesSuccess = loadSeriesListAction.elements
            .map { try? $0.map(to: [SeriesModel].self) }
            .flatMap(Driver.from)
            .map { $0.filter { ($0.postCount ?? 0) > 0 } }

        // 시리즈 섹션 생성
        let seriesSection = loadSeriesSuccess
            .map { $0.map { .seriesList(series: $0) } }
            .map { self.sections = $0 }
            .map { SectionType<ContentsSection>.Section(title: "series", items: self.sections) }

        // 프로젝트 정보 버튼 누르면 ProjectInfo 화면으로 이동
        let openProjectInfoViewController = input.infoBtnDidTap
            .map { uri }

        // 공유 버튼 누르면 공유 팝업 출력
        let openSharePopup = input.shareBtnDidTap
            .withLatestFrom(loadProjectInfo)

        // post 목록이 없으면 emptyView 출력
        let embedPostEmptyView = loadPostSuccess
            .map { $0.content?.isEmpty }
            .map { _ in .projectPostListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // series 목록이 없으면 emptyView 출력
        let embedSeriesEmptyView = loadSeriesSuccess
            .filter { $0.isEmpty }
            .map { _ in .projectSeriesListEmpty }
            .flatMap(Driver<CustomEmptyViewStyle>.from)

        // emptyView
        let embedEmptyViewController = Driver.merge(embedPostEmptyView, embedSeriesEmptyView)

        // tableView에 출력할 card post, list post, series
        let contentList = Driver.merge(postCardTypeSection, postListTypeSection, seriesSection)

        // swipe로 포스트 삭제 눌렀을 때 (에디터 기능 지원 안함)
        // 포스트 삭제 호출
        let deletePostAction = input.deletePost
            .map { PostAPI.delete(uri: uri, postId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 삭제 호출 성공 시 (에디터 기능 지원 안함)
        let deletePostSuccess = deletePostAction.elements
            .map { _ in LocalizationKey.msg_delete_post_success.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 포스트 삭제 호출 에러 시 (에디터 기능 지원 안함)
        let deletePostError = deletePostAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // swipe로 시리즈 삭제 눌렀을 때 (에디터 기능 지원 안함)
        // 포스트 삭제 호출
        let deleteSeriesAction = input.deleteSeries
            .map { SeriesAPI.delete(uri: uri, seriesId: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 포스트 삭제 호출 성공 시 (에디터 기능 지원 안함)
        let deleteSeriesSuccess = deleteSeriesAction.elements
            .map { _ in LocalizationKey.str_deleted_series.localized() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 포스트 삭제 호출 에러 시 (에디터 기능 지원 안함)
        let deleteSeriesError = deleteSeriesAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // swipe로 시리즈 수정 눌렀을 때 (에디터 기능 지원 안함)
        // 시리즈 수정 호출
        let updateSeriesAction = input.updateSeries
            .map { SeriesAPI.update(uri: uri, seriesId: $0.1.id ?? 0, name: $0.0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        // 시리즈 수정 호출 성공 시 (에디터 기능 지원 안함)
        let updateSeriesSuccess = updateSeriesAction.elements
            .map { _ in "" }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        // 시리즈 수정 호출 에러 시 (에디터 기능 지원 안함)
        let updateSeriesError = updateSeriesAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            userInfoAction.isExecuting,
            deletePostAction.isExecuting,
            deleteSeriesAction.isExecuting,
            updateSeriesAction.isExecuting)

        // 토스트 메시지
        let toastMessage = Driver.merge(
            deletePostSuccess,
            deleteSeriesSuccess,
            updateSeriesSuccess,
            deletePostError,
            deleteSeriesError,
            updateSeriesError)

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            viewWillLayoutSubviews: input.viewWillLayoutSubviews,
            traitCollectionDidChange: input.traitCollectionDidChange,
            embedProjectDetailViewController: embedProjectDetailViewController,
            projectInfo: loadProjectInfo,
            contentList: contentList,
            embedEmptyViewController: embedEmptyViewController,
            selectedIndexPath: input.selectedIndexPath,
            openProjectInfoViewController: openProjectInfoViewController,
            openSharePopup: openSharePopup,
            activityIndicator: activityIndicator,
            toastMessage: toastMessage
        )
    }
}
