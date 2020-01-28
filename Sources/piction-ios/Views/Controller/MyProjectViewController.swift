//
//  MyProjectViewController.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

final class MyProjectViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var createProjectButton: UIBarButtonItem!

    private let contextualAction = PublishSubject<IndexPath>()

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { (_, tv, ip, model) in
                let cell: MyProjectTableViewCell = tv.dequeueReusableCell(forIndexPath: ip)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return FEATURE_EDITOR
        })
    }
}

extension MyProjectViewController: ViewModelBindable {

    typealias ViewModel = MyProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.dataSource = nil
        tableView.delegate = nil

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = MyProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            createProjectBtnDidTap: createProjectButton.rx.tap.asDriver(),
            selectedIndexPath:
            tableView.rx.itemSelected.asDriver(),
            contextualAction: contextualAction.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.createProjectButton.isEnabled = FEATURE_EDITOR
                self?.createProjectButton.title = FEATURE_EDITOR ? LocalizationKey.create.localized() : ""
            })
            .disposed(by: disposeBag)
        
        output
            .projectList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .openCreateProjectViewController
            .drive(onNext: { [weak self] indexPath in
                var uri: String {
                    if let indexPath = indexPath {
                        return dataSource[indexPath].uri ?? ""
                    } else {
                        return ""
                    }
                }
                self?.openCreateProjectViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .openProjectViewController
            .drive(onNext: { [weak self] indexPath in
                let project = dataSource[indexPath]
                guard (project.status ?? "PUBLIC") != "DEPRECATED" else { return }
                let uri = project.uri ?? ""
                self?.openProjectViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: LocalizationKey.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)
    }
}

extension MyProjectViewController {
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext(indexPath)
            completionHandler(true)
        })
        return UISwipeActionsConfiguration(actions: [editAction])
    }
}
