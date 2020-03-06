//
//  CreateProjectViewModel.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

// MARK: - ViewModel
final class CreateProjectViewModel: InjectableViewModel {
    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        KeyboardManagerProtocol,
        String
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let keyboardManager: KeyboardManagerProtocol
    private let uri: String

    private let title = PublishSubject<String>()
    private let id = PublishSubject<String>()
    private let synopsis = PublishSubject<String>()
    private let wideThumbnailImageId = PublishSubject<String?>()
    private let thumbnailImageId = PublishSubject<String?>()
    private let status = PublishSubject<String>()
    private let tags = PublishSubject<[String]>()

    init(dependency: Dependency) {
        (firebaseManager, updater, keyboardManager, uri) = dependency
    }
}

// MARK: - Input & Output
extension CreateProjectViewModel {
    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let inputProjectTitle: Driver<String>
        let inputProjectId: Driver<String>
        let wideThumbnailBtnDidTap: Driver<Void>
        let thumbnailBtnDidTap: Driver<Void>
        let wideThumbnailImageDidPick: Driver<UIImage>
        let thumbnailImageDidPick: Driver<UIImage>
        let deleteWideThumbnailBtnDidTap: Driver<Void>
        let deleteThumbnailBtnDidTap: Driver<Void>
        let inputTags: Driver<[String]>
        let privateProjectCheckBoxBtnDidTap: Driver<Void>
        let inputSynopsis: Driver<String>
        let saveBtnDidTap: Driver<Void>
    }
    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let isModify: Driver<Bool>
        let loadProject: Driver<ProjectModel>
        let projectIdChanged: Driver<String>
        let openWideThumbnailImagePicker: Driver<Void>
        let openThumbnailImagePicker: Driver<Void>
        let changeWideThumbnail: Driver<UIImage?>
        let changeThumbnail: Driver<UIImage?>
        let statusChanged: Driver<String>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Bool>
        let toastMessage: Driver<String>
    }
}

// MARK: - ViewModel Build
extension CreateProjectViewModel {
    func build(input: Input) -> Output {
        let (firebaseManager, updater, keyboardManager, uri) = (self.firebaseManager, self.updater, self.keyboardManager, self.uri)

        // 화면이 보여지기 전에
        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                // analytics screen event
                firebaseManager.screenName("프로젝트 생성")
                // 키보드가 올라오는지 모니터링
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                // 키보드 모니터링 중단
                keyboardManager.stopMonitoring()
            })

        // 최초 진입 시
        let initialLoad = input.viewWillAppear
            .asObservable()
            .take(1)
            .asDriver(onErrorDriveWith: .empty())

        let isModify = initialLoad
            .map { uri != "" }

        let loadProjectAction = initialLoad
            .do(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.thumbnailImageId.onNext(nil)
                self.wideThumbnailImageId.onNext(nil)
                self.synopsis.onNext("")
                self.status.onNext("PUBLIC")
                self.tags.onNext([])
            })
            .filter { uri != "" }
            .map { ProjectAPI.get(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadProjectSuccess = loadProjectAction.elements
            .map { try? $0.map(to: ProjectModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] project in
                guard
                    let title = project.title,
                    let uri = project.uri,
                    let synopsis = project.synopsis,
                    let status = project.status
                else { return }

                self?.title.onNext(title)
                self?.id.onNext(uri)
                self?.thumbnailImageId.onNext("")
                self?.wideThumbnailImageId.onNext("")
                self?.synopsis.onNext(synopsis)
                self?.status.onNext(status)
                self?.tags.onNext([])
            })

        let projectTitleChanged = Driver.merge(input.inputProjectTitle, title.asDriver(onErrorDriveWith: .empty()))

        let projectIdChanged = Driver.merge(input.inputProjectId, id.asDriver(onErrorDriveWith: .empty()))

        let synopsisChanged = Driver.merge(input.inputSynopsis, synopsis.asDriver(onErrorDriveWith: .empty()))

        let uploadWideThumbnailImageAction = input.wideThumbnailImageDidPick
            .map { ProjectAPI.uploadWideThumbnail(image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadWideThumbnailError = uploadWideThumbnailImageAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let uploadWideThumbnailSuccess = uploadWideThumbnailImageAction.elements
            .map { try? $0.map(to: StorageAttachmentModel.self) }
            .map { $0?.id }
            .flatMap(Driver<String>.from)
            .do(onNext: { [weak self] imageId in
                self?.wideThumbnailImageId.onNext(imageId)
            })

        let changeWideThumbnail = uploadWideThumbnailSuccess
            .withLatestFrom(input.wideThumbnailImageDidPick)
            .flatMap(Driver<UIImage?>.from)

        let deleteWideThumbnail = input.deleteWideThumbnailBtnDidTap
            .map { nil }
            .flatMap(Driver<UIImage?>.from)
            .do(onNext: { [weak self] _ in
                self?.wideThumbnailImageId.onNext(nil)
            })

        let wideThumbnailImage = Driver.merge(changeWideThumbnail, deleteWideThumbnail)

        let uploadThumbnailImageAction = input.thumbnailImageDidPick
            .map { ProjectAPI.uploadThumbnail(image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadThumbnailError = uploadThumbnailImageAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let uploadThumbnailSuccess = uploadThumbnailImageAction.elements
            .map { try? $0.map(to: StorageAttachmentViewResponse.self) }
            .map { $0?.id }
            .flatMap(Driver<String?>.from)
            .do(onNext: { [weak self] imageId in
                self?.thumbnailImageId.onNext(imageId)
            })

        let changeThumbnail = uploadThumbnailSuccess
            .withLatestFrom(input.thumbnailImageDidPick)
            .flatMap(Driver<UIImage?>.from)

        let deleteThumbnail = input.deleteThumbnailBtnDidTap
            .map { nil }
            .flatMap(Driver<UIImage?>.from)
            .do(onNext: { [weak self] _ in
                self?.thumbnailImageId.onNext(nil)
            })

        let statusChanged = input.privateProjectCheckBoxBtnDidTap
            .withLatestFrom(status.asDriver(onErrorDriveWith: .empty()))
            .map { $0 == "PUBLIC" ? "HIDDEN" : "PUBLIC" }
            .do(onNext: { [weak self] status in
                self?.status.onNext(status)
            })

        let tagsChanged = Driver.merge(input.inputTags, tags.asDriver(onErrorDriveWith: .empty()))

        let thumbnailImage = Driver.merge(changeThumbnail, deleteThumbnail)

        let changeProjectInfo = Driver.combineLatest(projectTitleChanged, projectIdChanged, wideThumbnailImageId.asDriver(onErrorJustReturn: nil), thumbnailImageId.asDriver(onErrorJustReturn: nil), synopsisChanged, status.asDriver(onErrorDriveWith: .empty()), tagsChanged) { (title: $0, id: $1, wideThumbnailImageId: $2, thumbnailImageId: $3, synopsis: $4, status: $5, tags: $6) }

        let updateAction = input.saveBtnDidTap
            .filter { uri == "" }
            .withLatestFrom(changeProjectInfo)
            .map { ProjectAPI.create(uri: $0.id, title: $0.title, synopsis: $0.synopsis, thumbnail: $0.thumbnailImageId, wideThumbnail: $0.wideThumbnailImageId, tags: $0.tags, status: $0.status) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let createAction = input.saveBtnDidTap
            .filter { uri != "" }
            .withLatestFrom(changeProjectInfo)
            .map { ProjectAPI.update(uri: $0.id, title: $0.title, synopsis: $0.synopsis, thumbnail: $0.thumbnailImageId, wideThumbnail: $0.wideThumbnailImageId, tags: $0.tags, status: $0.status) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let saveButtonAction = Driver.merge(updateAction, createAction)

        let changeProjectInfoSuccess = saveButtonAction.elements
            .map { _ in Void() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let changeProjectInfoError = saveButtonAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        // 키보드로 인한 frame 변경 시
        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame
            .asDriver(onErrorDriveWith: .empty())

        // 로딩 뷰
        let activityIndicator = Driver.merge(
            uploadWideThumbnailImageAction.isExecuting,
            uploadThumbnailImageAction.isExecuting,
            saveButtonAction.isExecuting)

        // 토스트 메시지
        let toastMessage = Driver.merge(
            uploadWideThumbnailError,
            uploadThumbnailError,
            changeProjectInfoError)

        let dismissKeyboard = saveButtonAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            viewWillDisappear: viewWillDisappear,
            isModify: isModify,
            loadProject: loadProjectSuccess,
            projectIdChanged: projectIdChanged,
            openWideThumbnailImagePicker: input.wideThumbnailBtnDidTap,
            openThumbnailImagePicker: input.thumbnailBtnDidTap,
            changeWideThumbnail: wideThumbnailImage,
            changeThumbnail: thumbnailImage,
            statusChanged: statusChanged,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            popViewController: changeProjectInfoSuccess,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            toastMessage: toastMessage
        )
    }
}
