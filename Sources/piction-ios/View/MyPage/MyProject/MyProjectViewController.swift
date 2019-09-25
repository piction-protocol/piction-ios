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

//    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var createProjectButton: UIBarButtonItem!

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = getVisibleHeight()
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openCreateProjectViewController(uri: String) {
        let vc = CreateProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { (_, tv, ip, model) in
                let cell: MyProjectTableViewCell = tv.dequeueReusableCell(forIndexPath: ip)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return true
        })
    }
}

extension MyProjectViewController: ViewModelBindable {

    typealias ViewModel = MyProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = MyProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            createProjectBtnDidTap: createProjectButton.rx.tap.asDriver(),
            selectedIndexPath:
            tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.navigationBar.prefersLargeTitles = false
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
            .drive(onNext: { [weak self] _ in
                self?.openCreateProjectViewController(uri: "")
            })
            .disposed(by: disposeBag)

        output
            .openProjectViewController
            .drive(onNext: { [weak self] indexPath in
                let uri = dataSource[indexPath].uri ?? ""
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
    }
}

extension MyProjectViewController {
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "편집", handler: { [weak self] (action, view, completionHandler) in
                print("success")
                if let item = self?.viewModel?.projectList[indexPath.row] {
                    self?.openCreateProjectViewController(uri: item.uri ?? "")
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            })
        return UISwipeActionsConfiguration(actions: [editAction])
    }
}
