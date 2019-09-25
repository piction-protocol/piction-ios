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
//import RxPictionSDK

final class CreateProjectViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    private let updater: UpdaterProtocol
    var uri: String = ""

    private let title = PublishSubject<String>()
    private let id = PublishSubject<String>()
    private let synopsis = PublishSubject<String>()
    private let wideThumbnailImageId = PublishSubject<String?>()
    private let thumbnailImageId = PublishSubject<String?>()

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let inputProjectTitle: Driver<String>
        let inputProjectId: Driver<String>
        let wideThumbnailBtnDidTap: Driver<Void>
        let thumbnailBtnDidTap: Driver<Void>
        let wideThumbnailImageDidPick: Driver<UIImage>
        let thumbnailImageDidPick: Driver<UIImage>
        let deleteWideThumbnailBtnDidTap: Driver<Void>
        let deleteThumbnailBtnDidTap: Driver<Void>
        let inputSynopsis: Driver<String>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let isModify: Driver<Bool>
        let loadProject: Driver<ProjectModel>
        let projectIdChanged: Driver<String>
        let openWideThumbnailImagePicker: Driver<Void>
        let openThumbnailImagePicker: Driver<Void>
        let changeWideThumbnail: Driver<UIImage?>
        let changeThumbnail: Driver<UIImage?>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let updater = self.updater

        let viewWillAppear = input.viewWillAppear

        let isModify = input.viewWillAppear
            .flatMap { [weak self] _ -> Driver<Bool> in
                guard let `self` = self else { return Driver.empty() }
                return Driver.just(self.uri != "")
            }

        let loadProjectAction = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .do(onNext: { [weak self] in
                self?.thumbnailImageId.onNext(nil)
                self?.wideThumbnailImageId.onNext(nil)
            })
            .filter { self.uri != "" }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: self.uri))
                return Action.makeDriver(response)
            }

        let loadProjectSuccess = loadProjectAction.elements
            .flatMap { [weak self] response -> Driver<ProjectModel> in
                guard let project = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }

                self?.title.onNext(project.title ?? "")
                self?.id.onNext(project.uri ?? "")
                self?.thumbnailImageId.onNext("")
                self?.wideThumbnailImageId.onNext("")
                self?.synopsis.onNext(project.synopsis ?? "")

                print(project)
                return Driver.just(project)
            }

        let projectTitleChanged = Driver.merge(input.inputProjectTitle, title.asDriver(onErrorDriveWith: .empty()))
            .flatMap { title -> Driver<String> in
                return Driver.just(title)
            }

        let projectIdChanged = Driver.merge(input.inputProjectId, id.asDriver(onErrorDriveWith: .empty()))
            .flatMap { id -> Driver<String> in
                return Driver.just(id)
            }

        let synopsisChanged = Driver.merge(input.inputSynopsis, synopsis.asDriver(onErrorDriveWith: .empty()))
            .flatMap { synopsis -> Driver<String> in
                return Driver.just(synopsis)
            }

        let uploadWideThumbnailImageAction = input.wideThumbnailImageDidPick
            .flatMap { image -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.uploadWideThumbnail(image: image))
                return Action.makeDriver(response)
            }

        let uploadWideThumbnailError = uploadWideThumbnailImageAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let uploadWideThumbnailSuccess = uploadWideThumbnailImageAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self) else {
                    return Driver.empty()
                }
                self?.wideThumbnailImageId.onNext(imageInfo.id ?? "")
                return Driver.just(imageInfo.id ?? "")
            }

        let changeWideThumbnail = uploadWideThumbnailSuccess
            .withLatestFrom(input.wideThumbnailImageDidPick)
            .flatMap { image -> Driver<UIImage?> in
                return Driver.just(image)
            }

        let deleteWideThumbnail = input.deleteWideThumbnailBtnDidTap
            .flatMap { [weak self] _ -> Driver<UIImage?> in
                self?.wideThumbnailImageId.onNext(nil)
                return Driver.just(nil)
            }

        let wideThumbnailImage = Driver.merge(changeWideThumbnail, deleteWideThumbnail)

        let uploadThumbnailImageAction = input.thumbnailImageDidPick
            .flatMap { image -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.uploadThumbnail(image: image))
                return Action.makeDriver(response)
            }

        let uploadThumbnailError = uploadThumbnailImageAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let uploadThumbnailSuccess = uploadThumbnailImageAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self) else {
                    return Driver.empty()
                }
                self?.thumbnailImageId.onNext(imageInfo.id ?? "")
                return Driver.just(imageInfo.id ?? "")
            }

        let changeThumbnail = uploadThumbnailSuccess
            .withLatestFrom(input.thumbnailImageDidPick)
            .flatMap { image -> Driver<UIImage?> in
                return Driver.just(image)
            }

        let deleteThumbnail = input.deleteThumbnailBtnDidTap
            .flatMap { [weak self] _ -> Driver<UIImage?> in
                self?.thumbnailImageId.onNext(nil)
                return Driver.just(nil)
            }

        let thumbnailImage = Driver.merge(changeThumbnail, deleteThumbnail)

        let changeProjectInfo = Driver.combineLatest(projectTitleChanged, projectIdChanged, wideThumbnailImageId.asDriver(onErrorJustReturn: nil), thumbnailImageId.asDriver(onErrorJustReturn: nil), synopsisChanged) { (title: $0, id: $1, wideThumbnailImageId: $2, thumbnailImageId: $3, synopsis: $4) }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changeProjectInfo)
            .flatMap { [weak self] changeProjectInfo -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                if self.uri == "" {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.create(uri: changeProjectInfo.id, title: changeProjectInfo.title, synopsis: changeProjectInfo.synopsis, thumbnail: changeProjectInfo.thumbnailImageId, wideThumbnail: changeProjectInfo.wideThumbnailImageId, tags: [], status: "PUBLIC"))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.update(uri: changeProjectInfo.id, title: changeProjectInfo.title, synopsis: changeProjectInfo.synopsis, thumbnail: changeProjectInfo.thumbnailImageId, wideThumbnail: changeProjectInfo.wideThumbnailImageId, tags: [], status: "PUBLIC"))
                    return Action.makeDriver(response)
                }
            }

        let changeProjectInfoSuccess = saveButtonAction.elements
            .flatMap { response -> Driver<Void> in
                guard let project = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }
                print(project)
                updater.refreshContent.onNext(())
                return Driver.just(())
            }

        let changeProjectInfoError = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let showActivityIndicator = Driver.merge(input.wideThumbnailImageDidPick,  input.thumbnailImageDidPick)
            .flatMap { _ in Driver.just(true) }

        let hideActivityIndicator = Driver.merge(uploadWideThumbnailSuccess, uploadWideThumbnailError, uploadThumbnailSuccess, uploadThumbnailError)
            .flatMap { _ in Driver.just(false) }

        let activityIndicator = Driver.merge(showActivityIndicator, hideActivityIndicator)

        let showToast = Driver.merge(uploadWideThumbnailError, uploadThumbnailError, changeProjectInfoError)

        return Output(
            viewWillAppear: viewWillAppear,
            isModify: isModify,
            loadProject: loadProjectSuccess,
            projectIdChanged: projectIdChanged,
            openWideThumbnailImagePicker: input.wideThumbnailBtnDidTap,
            openThumbnailImagePicker: input.thumbnailBtnDidTap,
            changeWideThumbnail: wideThumbnailImage,
            changeThumbnail: thumbnailImage,
            popViewController: changeProjectInfoSuccess,
            activityIndicator: activityIndicator,
            showToast: showToast
        )
    }
}
