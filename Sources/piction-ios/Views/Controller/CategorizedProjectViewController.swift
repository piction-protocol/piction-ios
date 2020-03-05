//
//  CategorizedProjectViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/08.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import GSKStretchyHeaderView
import PictionSDK

// MARK: - UIViewController
final class CategorizedProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))
    private var stretchyHeader: CategorizedProjectHeaderView?

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            // stretchHeader 생성하고 collectionView에 add
            stretchyHeader = CategorizedProjectHeaderView.getView()
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                collectionView.addSubview(stretchyHeader)
            }
            // ProjectListCollectionViewCell은 공통으로 사용하여 storyboard가 아닌 여기서 등록
            collectionView.registerXib(ProjectListCollectionViewCell.self)
            // collectionView footer 추가
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // emptyView의 height를 보여지는 화면의 height로 설정
        emptyView.frame.size.height = visibleHeight
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CategorizedProjectViewController: ViewModelBindable {
    typealias ViewModel = CategorizedProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = CategorizedProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            viewDidLayoutSubviews: rx.viewDidLayoutSubviews.asDriver(), // subview의 layout이 갱신될 때
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            selectedIndexPath: collectionView.rx.itemSelected.asDriver() // collectionView의 item을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar, infiniteScroll 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.navigationController?.navigationBar.barStyle = .black
                self?.navigationController?.navigationBar.tintColor = .white
                self?.collectionView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // Pad 가로/세로모드 전환 시 Header size
        output
            .viewDidLayoutSubviews
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.stretchyHeader?.frame.size.width = self.view.frame.size.width
            })
            .disposed(by: disposeBag)

        // 화면이 사라지기 전에 navigationBar를 기본값으로 변경
        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.collectionView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 카테고리 정보를 가져와서 stretchy header에 설정
        output
            .categoryInfo
            .drive(onNext: { [weak self] categoryInfo in
                self?.stretchyHeader?.configureCategoryInfo(with: categoryInfo)
            })
            .disposed(by: disposeBag)

        // project의 데이터를 collectionView에 출력
        output
            .projectList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // project의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .projectList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // collectionView의 item을 선택할 때
        output
            .selectedIndexPath
            .map { dataSource[$0].uri }
            .flatMap(Driver.from)
            .map { .project(uri: $0) } // project 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll() // infiniteScroll 로딩 중이면 로딩 해제
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
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension CategorizedProjectViewController: UICollectionViewDelegateFlowLayout {
    // footer size 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if self.emptyView.subviews.count > 0 {
            return CGSize(width: SCREEN_W, height: emptyView.frame.size.height)
        } else {
            return CGSize.zero
        }
    }

    // 각 section의 padding 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.emptyView.subviews.count > 0 {
            return UIEdgeInsets.zero
        } else {
            return UIEdgeInsets(top: 32, left: 20, bottom: 20, right: 20)
        }
    }
}

// MARK: - GSKStretchyHeaderViewStretchDelegate
extension CategorizedProjectViewController: GSKStretchyHeaderViewStretchDelegate {
    // stretchHeader의 크기가 변경 될 때
    func stretchyHeaderView(_ headerView: GSKStretchyHeaderView, didChangeStretchFactor stretchFactor: CGFloat) {
        stretchyHeader?.maskImage.isHidden = false
        if stretchFactor > 0.1 {
            stretchyHeader?.maskImage.blurRadius = 0
        } else {
            stretchyHeader?.maskImage.blurRadius = (1 - min(1, stretchFactor) - 0.9) * 50
        }
    }
}

// MARK: - DataSource
extension CategorizedProjectViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // header, footer 설정
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }
                if (kind == UICollectionView.elementKindSectionFooter) {
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

                    // subview를 모두 제거 하고 emptyView를 add
                    _ = reusableView.subviews.map { $0.removeFromSuperview() }
                    reusableView.addSubview(self.emptyView)
                    return reusableView
                }
                return UICollectionReusableView()
            })
    }
}

// MARK: - Private Method
extension CategorizedProjectViewController {
    // Pad에서 가로/세로모드 변경 시 cell size 변경 (pad 가로모드에서는 한줄에 4개의 cell을 보여주도록 함)
    private func changeLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
        }
    }

    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
        self.collectionView.reloadData()
    }
}
