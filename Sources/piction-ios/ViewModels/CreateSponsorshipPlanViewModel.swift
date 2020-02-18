//
//  CreateSponsorshipPlanViewModel.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/22.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class CreateSponsorshipPlanViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol,
        UpdaterProtocol,
        String,
        PlanModel?
    )

    private let firebaseManager: FirebaseManagerProtocol
    private let updater: UpdaterProtocol
    private let uri: String
    private let sponsorshipPlan: PlanModel?

    private let name = PublishSubject<String>()
    private let price = PublishSubject<String?>()
    private let description = PublishSubject<String?>()
    private let limit = PublishSubject<String?>()

    init(dependency: Dependency) {
        (firebaseManager, updater, uri, sponsorshipPlan) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let sponsorshipPlanName: Driver<String>
        let sponsorshipPlanPrice: Driver<String?>
        let sponsorshipPlanDescription: Driver<String?>
        let sponsorshipPlanLimit: Driver<String?>
        let limitBtnDidTap: Driver<Void>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let loadSponsorshipPlan: Driver<PlanModel>
        let limitBtnDidTap: Driver<Void>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Void>
        let toastMessage: Driver<String>
    }

    func build(input: Input) -> Output {
        let (firebaseManager, updater, uri, sponsorshipPlan) = (self.firebaseManager, self.updater, self.uri, self.sponsorshipPlan)

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("SponsorshipPlan생성")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let loadSponsorshipPlan = initialLoad
            .map { sponsorshipPlan }
            .flatMap(Driver.from)
            .do(onNext: { [weak self] sponsorshipPlan in
                self?.name.onNext(sponsorshipPlan.name ?? "")
                self?.price.onNext(String(sponsorshipPlan.sponsorshipPrice ?? 0))
                self?.description.onNext(sponsorshipPlan.description ?? "")
                if sponsorshipPlan.sponsorshipLimit == nil {
                    self?.limit.onNext(nil)
                } else {
                    self?.limit.onNext(String(sponsorshipPlan.sponsorshipLimit ?? 0))
                }
            })

        let nameChanged = Driver.merge(input.sponsorshipPlanName, name.asDriver(onErrorDriveWith: .empty()))

        let priceChanged = Driver.merge(input.sponsorshipPlanPrice,
            price.asDriver(onErrorDriveWith: .empty()))

        let descriptionChanged = Driver.merge(input.sponsorshipPlanDescription,
            description.asDriver(onErrorDriveWith: .empty()))

        let noLimit = input.limitBtnDidTap
            .map { String?(nil) }
            .do(onNext: { [weak self] _ in
                self?.limit.onNext(nil)
            })

        let inputLimit = input.sponsorshipPlanLimit
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let limitChanged = Driver.merge(inputLimit, noLimit)
            .do(onNext: { [weak self] limit in
                self?.limit.onNext(limit)
            })

        let sponsorshipPlanInfo = Driver.combineLatest(
            nameChanged,
            priceChanged,
            descriptionChanged,
            limitChanged) { (name: $0, price: $1, description: $2, limit: $3) }

        let createSponsorshipPlanAction = input.saveBtnDidTap
            .filter { sponsorshipPlan == nil }
            .withLatestFrom(sponsorshipPlanInfo)
            .map { SponsorshipPlanAPI.create(uri: uri, name: $0.name, description: $0.description, thumbnail: nil, sponsorshipLimit: Int($0.limit ?? "") ?? nil, sponsorshipPrice: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let updateSponsorshipPlanAction = input.saveBtnDidTap
            .filter { sponsorshipPlan != nil }
            .withLatestFrom(sponsorshipPlanInfo)
            .map { SponsorshipPlanAPI.update(uri: uri, planId: sponsorshipPlan?.id ?? 0, name: $0.name, description: $0.description, thumbnail: nil, sponsorshipLimit: Int($0.limit ?? "") ?? nil, sponsorshipPrice: Int($0.price ?? "") ?? nil) }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let saveSponsorshipPlanAction = Driver.merge(createSponsorshipPlanAction, updateSponsorshipPlanAction)

        let dismissKeyboard = Driver.merge(input.saveBtnDidTap, input.limitBtnDidTap)

        let popViewController = saveSponsorshipPlanAction.elements
            .map { _ in Void() }
            .do(onNext: { _ in
                updater.refreshContent.onNext(())
            })

        let toastMessage = saveSponsorshipPlanAction.error
            .map { $0 as? ErrorType }
            .map { $0?.message }
            .flatMap(Driver.from)

        let activityIndicator = saveSponsorshipPlanAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            loadSponsorshipPlan: loadSponsorshipPlan,
            limitBtnDidTap: input.limitBtnDidTap,
            popViewController: popViewController,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            toastMessage: toastMessage
        )
    }
}
