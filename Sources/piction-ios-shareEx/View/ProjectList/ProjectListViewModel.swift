//
//  ProjectListViewModel.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/11.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class ProjectListViewModel: ViewModel {

    let projects: [ProjectModel]

    init(projects: [ProjectModel]) {
        self.projects = projects
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let selectedIndexPath: Driver<IndexPath>
        let closeBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let projectList: Driver<[ProjectModel]>
        let selectedIndexPath: Driver<IndexPath>
        let dismissViewController: Driver<Void>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let projectList = viewWillAppear
            .flatMap { [weak self] response -> Driver<[ProjectModel]> in
                return Driver.just(self?.projects ?? [])
            }

        return Output(
            viewWillAppear: input.viewWillAppear,
            projectList: projectList,
            selectedIndexPath: input.selectedIndexPath,
            dismissViewController: input.closeBtnDidTap
        )
    }
}
