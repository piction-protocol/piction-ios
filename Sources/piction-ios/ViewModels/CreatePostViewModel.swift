//
//  CreatePostViewModel.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Kanna
import PictionSDK

final class CreatePostViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int
    )

    private let updater: UpdaterProtocol
    var uri: String = ""
    var postId: Int = 0

    private let title = PublishSubject<String>()
    private let content = PublishSubject<String>()
    private let coverImageId = PublishSubject<String?>()
    private let status = PublishSubject<String>()
    private let fanPassId = PublishSubject<Int?>()
    private let publishedAt = PublishSubject<Date?>()
    private let seriesId = PublishSubject<Int?>()

    init(dependency: Dependency) {
        (updater, uri, postId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectSeriesBtnDidTap: Driver<Void>
        let seriesChanged: Driver<SeriesModel?>
        let fanPassChanged: Driver<FanPassModel?>
        let inputPostTitle: Driver<String>
        let inputContent: Driver<String>
        let contentImageDidPick: Driver<UIImage>
        let coverImageBtnDidTap: Driver<Void>
        let coverImageDidPick: Driver<UIImage>
        let deleteCoverImageBtnDidTap: Driver<Void>
        let forAllCheckBtnDidTap: Driver<Void>
        let forSubscriptionCheckBtnDidTap: Driver<Void>
        let forPrivateCheckBtnDidTap: Driver<Void>
        let selectFanPassBtnDidTap: Driver<Void>
        let publishNowCheckBtnDidTap: Driver<Void>
        let publishDatePickerBtnDidTap: Driver<Void>
        let publishDatePickerValueChanged: Driver<Date>
        let publishDateChanged: Driver<Date?>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let isModify: Driver<Bool>
        let openManageSeriesViewController: Driver<(String, Int?)>
        let loadPostInfo: Driver<(PostModel, String)>
        let uploadContentImage: Driver<(String, UIImage)>
        let openCoverImagePicker: Driver<Void>
        let changeCoverImage: Driver<UIImage?>
        let statusChanged: Driver<String>
        let seriesChanged: Driver<SeriesModel?>
        let fanPassChanged: Driver<FanPassModel?>
        let openManageFanPassViewController: Driver<(String, Int?)>
        let publishNowChanged: Driver<Void>
        let openDatePicker: Driver<Date>
        let publishDatePickerValueChanged: Driver<Date>
        let publishDateChanged: Driver<Date?>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri, postId) = (self.updater, self.uri, self.postId)
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .do(onNext: { [weak self] _ in
                self?.title.onNext("")
                self?.coverImageId.onNext("")
                self?.content.onNext("")
                self?.fanPassId.onNext(nil)
                self?.status.onNext("PUBLIC")
                self?.publishedAt.onNext(nil)
                self?.seriesId.onNext(nil)
            })

        let isModify = input.viewWillAppear
            .map { postId != 0 }

        let loadPostAction = viewWillAppear
            .filter { self.postId != 0 }
            .map { PostAPI.get(uri: uri, postId: postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadPostSuccess = loadPostAction.elements
            .map { try? $0.map(to: PostModel.self) }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] post in
                self?.title.onNext(post.title ?? "")
                self?.coverImageId.onNext("")
                self?.publishedAt.onNext(post.publishedAt)
                self?.fanPassId.onNext(post.fanPass?.id ?? nil)
                self?.status.onNext(post.status ?? "PUBLIC")
                self?.seriesId.onNext(post.series?.id ?? nil)
            })

        let loadContentAction = viewWillAppear
            .filter { self.postId != 0 }
            .map { PostAPI.getContent(uri: uri, postId: postId) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadContentSuccess = loadContentAction.elements
            .map { try? $0.map(to: ContentModel.self) }
            .map { ($0?.content ?? "").replacingOccurrences(of: "</p> <p>", with: "</p><p>") }
            .map(convertTagIFrameToVideo)
            .flatMap(Driver.from)
            .do(onNext: { [weak self] content in
                self?.content.onNext(content)
            })

        let loadFanPassAction = viewWillAppear
            .map { FanPassAPI.all(uri: uri) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let loadFanPassSuccess = loadFanPassAction.elements
            .map { try? $0.map(to: [FanPassModel].self) }
            .flatMap(Driver.from)

        let loadPostInfo = Driver.combineLatest(loadPostSuccess, loadContentSuccess)

        let postTitleChanged = Driver.merge(input.inputPostTitle, title.asDriver(onErrorDriveWith: .empty()))

        let postContentChanged = Driver.merge(input.inputContent, content.asDriver(onErrorDriveWith: .empty()))
            .map(changeContent)
            .map(convertTagVideoToIFrame)

        let uploadCoverImageAction = input.coverImageDidPick
            .map { PostAPI.uploadCoverImage(uri: uri, image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadCoverImageError = uploadCoverImageAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let uploadCoverImageSuccess = uploadCoverImageAction.elements
            .map { try? $0.map(to: StorageAttachmentViewResponse.self) }
            .map { $0?.id }
            .flatMap(Driver<String?>.from)
            .do(onNext: { [weak self] imageId in
                self?.coverImageId.onNext(imageId)
            })

        let changeCoverImage = uploadCoverImageSuccess
            .withLatestFrom(input.coverImageDidPick)
            .flatMap(Driver<UIImage?>.from)

        let deleteCoverImage = input.deleteCoverImageBtnDidTap
            .map { _ in UIImage?(nil) }
            .do(onNext: { [weak self] _ in  self?.coverImageId.onNext(nil)
            })

        let coverImage = Driver.merge(changeCoverImage, deleteCoverImage)

        let uploadContentImageAction = input.contentImageDidPick
            .map { PostAPI.uploadContentImage(uri: uri, image: $0) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let uploadContentImageSuccess = uploadContentImageAction.elements
            .map { try? $0.map(to: StorageAttachmentModel.self) }
            .map { $0?.url }
            .flatMap(Driver.from)

        let contentImage = Driver.zip(uploadContentImageSuccess, input.contentImageDidPick)

        let uploadContentImageError = uploadContentImageAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let checkforAll = input.forAllCheckBtnDidTap
            .map { "PUBLIC" }
            .flatMap(Driver<String>.from)
            .do(onNext: { [weak self] _ in
                self?.status.onNext("PUBLIC")
                self?.fanPassId.onNext(nil)
            })

        let checkforSubscription = input.forSubscriptionCheckBtnDidTap
            .withLatestFrom(loadFanPassSuccess)
            .do(onNext: { [weak self] fanPassInfo in
                self?.status.onNext("FAN_PASS")
                let fanPassId = fanPassInfo[safe: 0]?.id ?? nil
                self?.fanPassId.onNext(fanPassId)
            })
            .map { _ in "FAN_PASS" }

        let checkforPrivate = input.forPrivateCheckBtnDidTap
            .map { "PRIVATE" }
            .flatMap(Driver<String>.from)
            .do(onNext: { [weak self] _ in
                self?.status.onNext("PRIVATE")
                self?.fanPassId.onNext(nil)
            })

        let openManageFanPassViewController = input.selectFanPassBtnDidTap
            .withLatestFrom(fanPassId.asDriver(onErrorDriveWith: .empty()))
            .map { (uri, $0) }

        let publishNowChanged = input.publishNowCheckBtnDidTap

        let statusChanged = Driver.merge(checkforAll, checkforSubscription, checkforPrivate)

        let seriesChanged = input.seriesChanged
            .do(onNext: { [weak self] series in
                self?.seriesId.onNext(series?.id)
            })

        let fanPassChanged = input.fanPassChanged
            .do(onNext: { [weak self] fanPass in
                self?.fanPassId.onNext(fanPass?.id)
            })

        let publishDateChanged = input.publishDateChanged
            .do(onNext: { [weak self] date in
                self?.publishedAt.onNext(date)
            })

        let changePostInfo = Driver.combineLatest(postTitleChanged, postContentChanged, coverImageId.asDriver(onErrorDriveWith: .empty()), fanPassId.asDriver(onErrorDriveWith: .empty()), status.asDriver(onErrorDriveWith: .empty()), publishedAt.asDriver(onErrorDriveWith: .empty()), seriesId.asDriver(onErrorDriveWith: .empty())) { (title: $0, content: $1, coverImageId: $2, fanPassId: $3, status: $4, publishedAt: $5, seriesId: $6) }

        let createPostAction = input.saveBtnDidTap
            .withLatestFrom(changePostInfo)
            .filter { _ in postId == 0 }
            .map { PostAPI.create(uri: uri, title: $0.title, content: $0.content, cover: $0.coverImageId, seriesId: $0.seriesId, fanPassId: $0.fanPassId, status: $0.status, publishedAt: $0.publishedAt?.millisecondsSince1970  ?? Date().millisecondsSince1970)
            }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updatePostAction = input.saveBtnDidTap
            .withLatestFrom(changePostInfo)
            .filter { _ in postId != 0 }
            .map { PostAPI.update(uri: uri, postId: postId, title: $0.title, content: $0.content, cover: $0.coverImageId, seriesId: $0.seriesId, fanPassId: $0.fanPassId, status: $0.status, publishedAt: $0.publishedAt?.millisecondsSince1970 ?? Date().millisecondsSince1970)
            }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let savePostAction = Driver.merge(createPostAction, updatePostAction)

        let changePostInfoSuccess = savePostAction.elements
            .map { _ in Void() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let changePostInfoError = savePostAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let openDatePicker = input.publishDatePickerBtnDidTap
            .withLatestFrom(publishedAt.asDriver(onErrorDriveWith: .empty()))
            .map { $0 == nil ? Date() : $0! }

        let openManageSeriesViewController = input.selectSeriesBtnDidTap
            .withLatestFrom(seriesId.asDriver(onErrorDriveWith: .empty()))
            .map { (uri, $0) }

        let activityIndicator = Driver.merge(
            uploadCoverImageAction.isExecuting,
            uploadContentImageAction.isExecuting,
            savePostAction.isExecuting)

        let showToast = Driver.merge(
            uploadCoverImageError,
            uploadContentImageError,
            changePostInfoError)

        let dismissKeyboard = savePostAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            isModify: isModify,
            openManageSeriesViewController: openManageSeriesViewController,
            loadPostInfo: loadPostInfo,
            uploadContentImage: contentImage,
            openCoverImagePicker: input.coverImageBtnDidTap,
            changeCoverImage: coverImage,
            statusChanged: statusChanged,
            seriesChanged: seriesChanged,
            fanPassChanged: fanPassChanged,
            openManageFanPassViewController: openManageFanPassViewController,
            publishNowChanged: publishNowChanged,
            openDatePicker: openDatePicker,
            publishDatePickerValueChanged: input.publishDatePickerValueChanged,
            publishDateChanged: publishDateChanged,
            popViewController: changePostInfoSuccess,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            showToast: showToast
        )
    }
}

extension CreatePostViewModel {
    func changeContent(_ content: String) -> String {
        var content = content.replacingOccurrences(of: "strong>", with: "b>")
        content = content.replacingOccurrences(of: "em>", with: "i>")
        content = content.replacingOccurrences(of: "<i></i>", with: "<i><br></i>")
        content = content.replacingOccurrences(of: "<u></u>", with: "<u><br></u>")
        content = content.replacingOccurrences(of: "<b></b>", with: "<b><br></b>")
        content = content.replacingOccurrences(of: "<p> </p>", with: "<p><br></p>")
        content = content.replacingOccurrences(of: "<p></p>", with: "<p><br></p>")
        return content
    }

    func convertTagIFrameToVideo(_ content: String) -> String {
        let youtubeIds = content.getYoutubeId()

        var htmlString = content

        htmlString = htmlString.replacingOccurrences(of: "<div class=\"video\">  ", with: "<p>")
        htmlString = htmlString.replacingOccurrences(of: " </div> ", with: "</p>")

        if let doc = try? HTML(html: content, encoding: .utf8) {
            for (index, element) in doc.xpath("//iframe").enumerated() {
                if let youtubeId = youtubeIds[safe: index] {
                    htmlString = htmlString.replacingOccurrences(of: element.toHTML ?? "", with: "<video src=\"https://www.youtube.com/watch?v=\(youtubeId)\" poster=\"https://img.youtube.com/vi/\(youtubeId)/maxresdefault.jpg\"></video>")
                }
            }
        }
        return htmlString
    }

    func convertTagVideoToIFrame(_ content: String) -> String {
        let youtubeIds = content.getYoutubeId()

        var htmlString = content

        if let doc = try? HTML(html: content, encoding: .utf8) {
            for (index, element) in doc.xpath("//video").enumerated() {
                if let youtubeId = youtubeIds[safe: index] {
                    htmlString = htmlString.replacingOccurrences(of: element.toHTML ?? "", with: "<iframe frameborder=\"0\" allowfullscreen=\"true\" src=\"https://www.youtube.com/embed/\(youtubeId)\"></iframe>")
                }
            }
        }
        htmlString = htmlString.replacingOccurrences(of: "<p><iframe", with: "<div class=\"video\">  <iframe")
        htmlString = htmlString.replacingOccurrences(of: "</iframe></p>", with: "</iframe> </div> ")

        return htmlString
    }
}