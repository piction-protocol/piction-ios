//
//  ProjectListViewController.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/11.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

protocol ProjectListDelegate: class {
    func selectProject(with project: ProjectModel?)
}

final class ProjectListViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var closeButton: UIBarButtonItem!

    weak var delegate: ProjectListDelegate?

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: ProjectListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

extension ProjectListViewController: ViewModelBindable {
    typealias ViewModel = ProjectListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // UITableViewController의 경우 UITableViewDelegate, UITableViewDataSource가 자동으로 적용되므로 사용하지 않으면 제거
        tableView.dataSource = nil
        tableView.delegate = nil

        let input = ProjectListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.allowsSelection = self?.delegate != nil
                FirebaseManager.screenName("공유_프로젝트선택")
            })
            .disposed(by: disposeBag)

        output
            .projectList
            .drive { $0 }
            .map { [SectionModel(model: "project", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let project = dataSource[indexPath]
                delegate.selectProject(with: project)
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] _ in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}
