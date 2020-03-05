//
//  TransactionDetailViewController.swift
//  PictionSDK
//
//  Created by jhseo on 29/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import SafariServices
import PictionSDK

// MARK: - UIViewController
final class TransactionDetailViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension TransactionDetailViewController: ViewModelBindable {
    typealias ViewModel = TransactionDetailViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = TransactionDetailViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            selectedIndexPath: tableView.rx.itemSelected.asDriver() // tableView의 row를 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // navigation title 설정
        output
            .navigationTitle
            .drive(navigationItem.rx.title)
            .disposed(by: disposeBag)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // transaction 정보를 tableView에 출력
        output
            .transactionInfo
            .do(onNext: { [weak self] _ in
                let view = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: SCREEN_H))
                if #available(iOS 13.0, *) {
                    view.backgroundColor = .secondarySystemBackground
                } else {
                    view.backgroundColor = UIColor(r: 250, g: 250, b: 250)
                }
                self?.emptyView.addSubview(view)
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .list(_, _, let link):
                    // 링크가 있는 경우 safariView로 이동
                    self?.openSafariViewController(url: link)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension TransactionDetailViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<TransactionDetailSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<TransactionDetailSection>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .info(let model):
                    let cell: TransactionDetailInfoTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .header(let model):
                    let cell: TransactionDetailHeaderTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .list(let model):
                    let cell: TransactionDetailItemTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: model)
                    return cell
                case .footer:
                    let cell: TransactionDetailFooterTypeTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    return cell
                }
        })
    }
}
