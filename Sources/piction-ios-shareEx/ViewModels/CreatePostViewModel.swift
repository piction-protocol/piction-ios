//
//  CreatePostViewModel.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreatePostViewModel: ViewModel {

    let context: NSExtensionContext?

    let selectedImages = PublishSubject<[UIImage]>()
    let coverImageId = PublishSubject<String?>()
    let selectedStatus = PublishSubject<String>()

    var contentHtml = ""

    init(dependency: Dependency) {
        (keyboardManager, context) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let inputTitle: Driver<String>
        let contentText: Driver<String>
        let selectedImages: Driver<[UIImage]>
        let projectBtnDidTap: Driver<Void>
        let selectedProject: Driver<ProjectModel?>
        let seriesBtnDidTap: Driver<Void>
        let selectedSeries: Driver<SeriesModel?>
        let statusBtnDidTap: Driver<Void>
        let selectedStatus: Driver<String>
        let saveBtnDidTap: Driver<Void>
        let cancelBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let loadContents: Driver<Void>
        let contentText: Driver<String>
        let selectedImages: Driver<[UIImage]>
        let openProjectListViewController: Driver<[ProjectModel]>
        let selectedProject: Driver<ProjectModel?>
        let openManageSeriesViewController: Driver<String>
        let selectedSeries: Driver<SeriesModel?>
        let openStatusActionSheet: Driver<Void>
        let selectedStatus: Driver<String>
        let enableSaveButton: Driver<Void>
        let keyboardWillChangeFrame: Driver<ChangedKeyboardFrame>
        let activityIndicator: Driver<Bool>
        let toastMessage: Driver<String>
        let dismissViewController: Driver<String?>
    }

    func build(input: Input) -> Output {
        let keyboardManager = self.keyboardManager

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                keyboardManager.beginMonitoring()
            })

        let viewWillDisappear = input.viewWillDisappear
            .do(onNext: { _ in
                keyboardManager.stopMonitoring()
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .do(onNext: { [weak self] _ in
                self?.selectedImages.onNext([])
                self?.coverImageId.onNext(nil)
                self?.selectedStatus.onNext("PUBLIC")
            })

        let userMeAction = initialLoad
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(UserAPI.me)
                return Action.makeDriver(response)
            }

        let userMeError = userMeAction.error
            .flatMap { _ -> Driver<String?> in
                return Driver.just(LocalizationKey.str_login_first.localized())
        }

        let projectListAction = userMeAction.elements
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(MyAPI.projects)
                return Action.makeDriver(response)
            }

        let projectList = projectListAction.elements
            .flatMap { response -> Driver<[ProjectModel]> in
                guard let projects = try? response.map(to: [ProjectModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(projects)
            }

        let projectListError = projectListAction.error
            .flatMap { _ -> Driver<String?> in
                return Driver.just(LocalizationKey.str_create_project_first.localized())
            }

        let openProjectListViewController = input.projectBtnDidTap
            .withLatestFrom(projectList)

        let selectedProjectSuccess = input.selectedProject
            .flatMap { project -> Driver<ProjectModel?> in
                return Driver.just(project)
            }

        let selectedProjectError = initialLoad
            .flatMap { _ -> Driver<ProjectModel?> in
                return Driver.just(nil)
            }

        let selectedProject = Driver.merge(selectedProjectSuccess, selectedProjectError)

        let membershipAction = selectedProject
            .flatMap { project -> Driver<Action<ResponseData>> in
                guard let uri = project?.uri else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(MembershipAPI.all(uri: uri))
                return Action.makeDriver(response)
            }

        let membershipSuccess = membershipAction.elements
            .flatMap { response -> Driver<Int?> in
                guard let membership = try? response.map(to: [MembershipModel].self) else { return Driver.empty() }
                return Driver.just(membership.first?.id)
            }

        let membershipError = membershipAction.error
            .flatMap { _ in Driver<Int?>.just(nil) }

        let mnembershipId = Driver.merge(membershipSuccess, membershipError)

        let openManageSeriesViewController = input.seriesBtnDidTap
            .withLatestFrom(selectedProject)
            .filter { $0 != nil }
            .flatMap { project -> Driver<String> in
                return Driver.just(project?.uri ?? "")
            }

        let openSeriesError = input.seriesBtnDidTap
            .withLatestFrom(selectedProject)
            .filter { $0 == nil }
            .flatMap { _ -> Driver<String> in
                return Driver.just(LocalizationKey.str_select_project_first.localized())
            }

        let selectedSeries = input.selectedSeries
            .flatMap { series -> Driver<SeriesModel?> in
                return Driver.just(series)
            }

        let selectedImages = Driver.merge(input.selectedImages, self.selectedImages.asDriver(onErrorDriveWith: .empty()))
            .flatMap { images -> Driver<[UIImage]> in
                return Driver.just(images)
            }

        let selectedStatus = Driver.merge(input.selectedStatus, self.selectedStatus.asDriver(onErrorDriveWith: .empty()))
            .flatMap { status -> Driver<String> in
                return Driver.just(status)
            }

        let postItems = Driver.combineLatest(
                selectedProject,
                selectedSeries,
                input.inputTitle,
                coverImageId.asDriver(onErrorDriveWith: .empty()),
                selectedImages,
                input.contentText,
                membershipId,
                selectedStatus
        ) { (project: $0, series: $1, title: $2, coverId: $3, images: $4, contentText: $5, membershipId: $6, status: $7) }

        let enableSaveButton = postItems
            .flatMap { _ in Driver.just(()) }

        let saveBtnDidTap = input.saveBtnDidTap
            .flatMap { _ in Driver<String>.just(LocalizationKey.str_saving_post.localized()) }

        let uploadCoverImageAction = input.saveBtnDidTap
            .withLatestFrom(postItems)
            .filter { $0.images.count > 0 }
            .filter { $0.coverId == nil }
            .flatMap { postItems -> Driver<Action<ResponseData>> in
                guard let coverImage = postItems.images.first else { return Driver.empty() }
                guard let uri = postItems.project?.uri else { return Driver.empty() }

                let response = PictionSDK.rx.requestAPI(PostAPI.uploadCoverImage(uri: uri, image: coverImage))

                return Action.makeDriver(response)
            }

        let uploadCoverImageSuccess = uploadCoverImageAction.elements
            .flatMap { [weak self] response -> Driver<String?> in
                guard let `self` = self else { return Driver.empty() }
                guard let storageAttachment = try? response.map(to: StorageAttachmentModel.self) else { return Driver.empty() }
                self.coverImageId.onNext(storageAttachment.id ?? "")
                return Driver.just(storageAttachment.id ?? "")
            }

        let uploadCoverImageError = uploadCoverImageAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let uploadCoverImageNotExist = input.saveBtnDidTap
            .withLatestFrom(postItems)
            .filter { $0.images.count == 0 }
            .filter { $0.coverId == nil }
            .flatMap { _ in return Driver<String?>.just(nil) }

        let uploadCoverImage = Driver.merge(uploadCoverImageSuccess, uploadCoverImageNotExist)

        let uploadContentImageAction = uploadCoverImage
            .withLatestFrom(postItems)
            .filter { $0.images.count > 0 }
            .flatMap { postItems -> Driver<[Action<ResponseData>]> in
                guard let uri = postItems.project?.uri else { return Driver.empty() }

                var responses: [Driver<Action<ResponseData>>] = []
                for image in postItems.images {
                    let response = Action.makeDriver(PictionSDK.rx.requestAPI(PostAPI.uploadContentImage(uri: uri, image: image)))
                    responses.append(response)
                }
                return Driver.zip(responses)
            }

        let uploadContentImageSuccess = uploadContentImageAction
            .flatMap { [weak self] responses -> Driver<Void> in
                guard let `self` = self else { return Driver.empty() }
                for (index, element) in responses.enumerated() {
                    switch element {
                    case .succeeded(let response):
                        guard let storageAttachment = try? response.map(to: StorageAttachmentModel.self) else { return Driver.empty() }
                        self.contentHtml += "<p><img src=\"\(storageAttachment.url ?? "")\"></p>"

                        if index >= responses.count - 1 {
                            return Driver.just(())
                        }
                    default:
                        return Driver.empty()
                    }
                }
                return Driver.empty()
            }

        let uploadContentImageError = uploadContentImageAction
            .flatMap { responses -> Driver<String> in
                for response in responses {
                    switch response {
                    case .failed(let error):
                        let errorMsg = error as? ErrorType
                        return Driver.just(errorMsg?.message ?? "")
                    default:
                        return Driver.empty()
                    }
                }
                return Driver.empty()
            }

        let uploadContentImageNotExist = input.saveBtnDidTap
            .withLatestFrom(postItems)
            .filter { $0.images.count == 0 }
            .flatMap { _ in return Driver<Void>.just(()) }

        let uploadContentImage = Driver.merge(uploadContentImageSuccess, uploadContentImageNotExist)

        let alreadyUploadImage = input.saveBtnDidTap
            .withLatestFrom(postItems)
            .filter { $0.coverId != nil }
            .flatMap { _ in Driver<Void>.just(()) }

        let uploadSuccess = Driver.merge(alreadyUploadImage, uploadContentImage)

        let saveAction = uploadSuccess
            .withLatestFrom(postItems)
            .flatMap { [weak self] postItems -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                guard let uri = postItems.project?.uri else { return Driver.empty() }
                let contentHtml = "\(self.contentHtml)<p>\(postItems.contentText.parseSpecialStrToHtmlStr)</p>"
                let response = PictionSDK.rx.requestAPI(PostAPI.create(uri: uri, title: postItems.title, content: contentHtml, cover: postItems.coverId, seriesId: postItems.series?.id, membershipId: postItems.status == "MEMBERSHIP" ? postItems.membershipId : nil, status: postItems.status, publishedAt: Date().millisecondsSince1970))
                return Action.makeDriver(response)
            }

        let saveSuccess = saveAction.elements
            .flatMap { _ -> Driver<String?> in
                return Driver.just(LocalizationKey.str_save_post_complete.localized())
            }

        let saveError = saveAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let cancelAction = input.cancelBtnDidTap
            .flatMap { _ -> Driver<String?> in
                return Driver.just(nil)
            }

        let keyboardWillChangeFrame = keyboardManager.keyboardWillChangeFrame.asDriver(onErrorDriveWith: .empty())

        let activityIndicator = Driver.merge(
            uploadCoverImageAction.isExecuting,
            uploadContentImage.isExecuting,
            saveAction.isExecuting)

        let toastMessage = Driver.merge(saveBtnDidTap, openSeriesError, uploadCoverImageError, saveError, uploadContentImageError)

        let dismissViewController = Driver.merge(saveSuccess, userMeError, cancelAction, projectListError)

        return Output(
            viewWillAppear: viewWillAppear,
            loadContents: initialLoad,
            contentText: input.contentText,
            selectedImages: selectedImages,
            openProjectListViewController: openProjectListViewController,
            selectedProject: selectedProject,
            openManageSeriesViewController: openManageSeriesViewController,
            selectedSeries: selectedSeries,
            openStatusActionSheet: input.statusBtnDidTap,
            selectedStatus: selectedStatus,
            enableSaveButton: enableSaveButton,
            keyboardWillChangeFrame: keyboardWillChangeFrame,
            activityIndicator: activityIndicator,
            toastMessage: toastMessage,
            dismissViewController: dismissViewController
        )
    }
}
