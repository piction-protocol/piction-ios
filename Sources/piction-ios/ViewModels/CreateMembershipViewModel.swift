//
//  CreateMembershipViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreateMembershipViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        MembershipModel?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String
    private let membership: MembershipModel?

    private let name = PublishSubject<String>()
    private let price = PublishSubject<String?>()
    private let description = PublishSubject<String?>()
    private let limit = PublishSubject<String?>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, membership) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let membershipName: Driver<String>
        let membershipPrice: Driver<String?>
        let membershipDescription: Driver<String?>
        let membershipLimit: Driver<String?>
        let limitBtnDidTap: Driver<Void>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let loadMembership: Driver<MembershipModel>
        let limitBtnDidTap: Driver<Void>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, membership) = (self.firebaseManager, self.updater, self.uri, self.membership)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("Membership생성")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadMembership = initialLoad
            .map { membership }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] membership in
                self?.name.onNext(membership.name ?? "")
                self?.price.onNext(String(membership.price ?? 0))
                self?.description.onNext(membership.description ?? "")
                if membership.sponsorLimit == nil {
                    self?.limit.onNext(nil)
                } else {
                    self?.limit.onNext(String(membership.sponsorLimit ?? 0))
                }
            })

        let nameChanged = Driver.merge(input.membershipName, name.asDriver(onErrorDriveWith: .empty()))

        let priceChanged = Driver.merge(input.membershipPrice,
            price.asDriver(onErrorDriveWith: .empty()))

        let descriptionChanged = Driver.merge(input.membershipDescription,
            description.asDriver(onErrorDriveWith: .empty()))

        let noLimit = input.limitBtnDidTap
            .map { String?(nil) }
            .do(onNext: { [weak self] _ in
                self?.limit.onNext(nil)
            })

        let inputLimit = input.membershipLimit
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let limitChanged = Driver.merge(inputLimit, noLimit)
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let membershipInfo = Driver.combineLatest(
            nameChanged,
            priceChanged,
            descriptionChanged,
            limitChanged) { (name: $0, price: $1, description: $2, limit: $3) }

        let createMembershipAction = input.saveBtnDidTap
            .filter { membership == nil }
            .withLatestFrom(membershipInfo)
            .map { MembershipAPI.create(uri: uri, name: $0.name, description: $0.description, thumbnail: nil, sponsorLimit: Int($0.limit ?? "") ?? nil, price: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updateMembershipAction = input.saveBtnDidTap
            .filter { membership != nil }
            .withLatestFrom(membershipInfo)
            .map { MembershipAPI.update(uri: uri, membershipId: membership?.id ?? 0, name: $0.name, description: $0.description, thumbnail: nil, sponsorLimit: Int($0.limit ?? "") ?? nil, price: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let saveMembershipAction = Driver.merge(createMembershipAction, updateMembershipAction)

        let dismissKeyboard = Driver.merge(input.saveBtnDidTap, input.limitBtnDidTap)

        let popViewController = saveMembershipAction.elements
            .map { _ in Void() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let toastMessage = saveMembershipAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let activityIndicator = saveMembershipAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            loadMembership: loadMembership,
            limitBtnDidTap: input.limitBtnDidTap,
            popViewController: popViewController,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            toastMessage: toastMessage
        )
    }
}
