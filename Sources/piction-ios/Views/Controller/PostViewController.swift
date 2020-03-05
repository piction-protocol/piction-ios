//
//  PostViewController.swift
//  PictionView
//
//  Created by jhseo on 01/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import Swinject
import WebKit
import SafariServices
import PictionSDK
import RxGesture

// MARK: - UIViewController
final class PostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var subscriptionView: UIView!
    @IBOutlet weak var subscriptionDescriptionLabel: UILabel!
    @IBOutlet weak var subscriptionButton: UIButton!
    @IBOutlet weak var postWebView: WKWebView! {
        didSet {
            postWebView.navigationDelegate = self
            postWebView.scrollView.delegate = self
            postWebView.isOpaque = false
            postWebView.scrollView.contentInsetAdjustmentBehavior = .never
            postWebView.isHidden = true
        }
    }
    @IBOutlet weak var prevPostButton: UIButton!
    @IBOutlet weak var nextPostButton: UIButton!
    @IBOutlet weak var shareBarButton: UIBarButtonItem!
    @IBOutlet weak var readmodeBarButton: UIBarButtonItem! {
        didSet {
            readmodeBarButton.tintColor = .pictionGray
        }
    }
    @IBOutlet weak var subscriptionNameStackView: UIStackView!
    @IBOutlet weak var subscriptionNameLabel: UILabel!

    private let loadPost = PublishSubject<Int>()

    var headerViewController: PostHeaderViewController?
    var footerViewController: PostFooterViewController?

    // statusBar 상태가 변경 될 때의 애니메이션
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }

    // navigationBar가 hidden일 때 statusBar도 hidden 처리
    override var prefersStatusBarHidden: Bool {
        return self.navigationController?.isNavigationBarHidden ?? false
    }

    deinit {
        // webView 캐시 제거
        cacheWebview()
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension PostViewController: ViewModelBindable {
    typealias ViewModel = PostViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = PostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewDidAppear: rx.viewDidAppear.asDriver(), // 화면이 보여질 때
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            loadPost: loadPost.asDriver(onErrorDriveWith: .empty()),
            prevPostBtnDidTap: prevPostButton.rx.tap.asDriver().throttle(1, latest: true), // 툴바의 이전 포스트 눌렀을 때
            nextPostBtnDidTap: nextPostButton.rx.tap.asDriver().throttle(1, latest: true), // 툴바의 다음 포스트 눌렀을 때
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(), // 구독 또는 후원하기 버튼 눌렀을 때
            shareBarBtnDidTap: shareBarButton.rx.tap.asDriver(), // 공유 버튼 눌렀을 때
            contentOffset: postWebView.scrollView.rx.contentOffset.asDriver(), // webView scrollView contentOffset이 변경 될 때
            willBeginDecelerating: postWebView.scrollView.rx.willBeginDecelerating.asDriver(), // webView scrollView의 decelerating 상태 일 때
            readmodeBarButton: readmodeBarButton.rx.tap.asDriver() // 읽기모드 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self.postWebView.scrollView.contentInset = UIEdgeInsets(
                    top: self.statusHeight + DEFAULT_NAVIGATION_HEIGHT,
                    left: 0,
                    bottom: self.toolbarHeight,
                    right: 0)
            })
            .disposed(by: disposeBag)

        // 화면이 보여질 때
        output
            .viewDidAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.toolbar.isHidden = false
            })
            .disposed(by: disposeBag)

        // 화면이 사라지기 전에 navigation과 toolbar를 숨김 해제
        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationController?.toolbar.isHidden = true
                self?.navigationController?.setToolbarHidden(true, animated: false)
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.setWebviewFontColor()
                self?.setWebviewBackgroundColor()
            })
            .disposed(by: disposeBag)

        // header 정보를 불러와서 Header를 생성
        output
            .headerInfo
            .drive(onNext: { [weak self] (postItem, userInfo) in
                self?.embedPostHeaderViewController(postItem: postItem, userInfo: userInfo)
                self?.navigationItem.title = postItem.title
            })
            .disposed(by: disposeBag)

        // footer 정보를 불러와서 PostFooter를 생성
        output
            .footerInfo
            .drive(onNext: { [weak self] in
                self?.makePostFooterViewController(uri: $0, postItem: $1)
            })
            .disposed(by: disposeBag)

        // 이전/다음 포스트 설정
        output
            .prevNextLink
            .drive(onNext: { [weak self] postLinkItem in
                self?.setLinkButton(button: self?.prevPostButton, postItem: postLinkItem.previousPost)
                self?.setLinkButton(button: self?.nextPostButton, postItem: postLinkItem.nextPost)
            })
            .disposed(by: disposeBag)

        // post 내용인 html을 webview에 출력
        output
            .showPostContent
            .drive(onNext: { [weak self] in
                self?.postWebView.loadHTMLString($0, baseURL: nil)
            })
            .disposed(by: disposeBag)

        // 이전/다음 포스트, 시리즈의 포스트 등 postId가 변경될 때
        output
            .reloadPost
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.postWebView.isHidden = true
                self.subscriptionView.isHidden = true
                self.postWebView.scrollView.isScrollEnabled = true
                self.removeHeaderFooter()
                self.postWebView.loadHTMLString("", baseURL: nil)
                self.showFullScreen(false)
            })
            .disposed(by: disposeBag)

        // 구독 또는 후원이 필요할 때
        output
            .showNeedSubscription
            .drive(onNext: { [weak self] (userInfo, postInfo, _) in
                guard let `self` = self else { return }
                self.readmodeBarButtonIsHidden(status: true)
                self.postWebView.isHidden = false

                // 버튼 title 설정
                var buttonTitle: String {
                    if userInfo.loginId == nil {
                        return LocalizationKey.login.localized() // 로그인
                    } else if (postInfo.membership?.level ?? 0) == 0 {
                        return LocalizationKey.btn_subs_free.localized() // 구독하기
                    } else {
                        return LocalizationKey.btn_subs_membership.localized() // 후원하기
                    }
                }

                // 설명
                var description: String {
                    if (postInfo.membership?.level ?? 0) == 0 {
                         return LocalizationKey.str_subs_only.localized() // 구독자 전용
                    } else {
                        return LocalizationKey.str_subs_only_with_membership.localized(with: postInfo.membership?.name ?? "") // 멤버십명 전용
                    }
                }
                self.subscriptionNameLabel.text = postInfo.membership?.name
                self.subscriptionNameStackView.isHidden = !((postInfo.membership?.level ?? 0) > 0)
                self.subscriptionButton.setTitle(buttonTitle, for: .normal)
                self.subscriptionDescriptionLabel.text = description
                self.subscriptionView.isHidden = false
                self.postWebView.scrollView.isScrollEnabled = false

                for subview in self.postWebView.scrollView.subviews {
                    if subview.tag == 1001 {
                        subview.isHidden = true
                    }
                }
            })
            .disposed(by: disposeBag)

        // 후원이 필요하지만 activeMembership이 false일 때
        output
            .hideMembershipButton
            .drive(subscriptionButton.rx.isHidden)
            .disposed(by: disposeBag)

        // 구독 또는 후원이 필요하지 않을 때
        output
            .hideNeedSubscription
            .drive(onNext: { [weak self] in
                self?.readmodeBarButtonIsHidden(status: false)
                self?.subscriptionView.isHidden = true
                self?.postWebView.scrollView.isScrollEnabled = true
            })
            .disposed(by: disposeBag)

        // 읽기모드 변경 시
        output
            .changeReadmode
            .drive(onNext: { [weak self] in
                let status = self?.isReadmode() ?? true
                self?.changeReadmode(status: !status)
                self?.setReadmode(status: !status)
            })
            .disposed(by: disposeBag)

        // 로그인 화면 출력
        output
            .openSignInViewController
            .map { .signIn }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .swipePresent)
            })
            .disposed(by: disposeBag)

        // 멤버십 리스트 화면 출력
        output
            .openMembershipListViewController
            .map { .membershipList(uri: $0, postId: $1) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .present)
            })
            .disposed(by: disposeBag)

        // 공유 기능
        output
            .sharePost
            .drive(onNext: { [weak self] url in
                guard let `self` = self else { return }
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [])

                activityViewController.excludedActivityTypes = [
                    UIActivity.ActivityType.print,
                    UIActivity.ActivityType.assignToContact,
                    UIActivity.ActivityType.saveToCameraRoll,
                    UIActivity.ActivityType.addToReadingList,
                    UIActivity.ActivityType.postToFlickr,
                    UIActivity.ActivityType.postToVimeo,
                    UIActivity.ActivityType.openInIBooks
                ]

                if let topController = UIApplication.topViewController() {
                    if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                        activityViewController.modalPresentationStyle = .popover
                        if let popover = activityViewController.popoverPresentationController {
                            popover.permittedArrowDirections = .up
                            popover.sourceView = topController.view
                            popover.sourceRect = CGRect(x: self.view.frame.size.width, y: 64, width: 0, height: 0)
                        }
                    }
                    topController.present(activityViewController, animated: true, completion: nil)
                }
            })
            .disposed(by: disposeBag)

        // 스크롤 시(decelerating)
        output
            .willBeginDecelerating
            .drive(onNext: { [weak self] in
                self?.showFullScreen()
            })
            .disposed(by: disposeBag)

        // 스크롤 시(contentOffset 변경 시)
        output
            .contentOffset
            .distinctUntilChanged()
            .drive(onNext: { [weak self] offset in
                guard let `self` = self else { return }
                let isScrollTop = offset.y <= -44
                let isScrollBottom = (offset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
                if isScrollTop || isScrollBottom {
                    self.showFullScreen(false)
                }
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)

        view.rx.tapGesture(configuration: { gestureRecognizer, delegate in
                gestureRecognizer.delegate = self
                gestureRecognizer.cancelsTouchesInView = false
            })
            .when(.recognized)
            .subscribe(onNext: { [weak self] _ in
                self?.showFullScreen(!(self?.navigationController?.isNavigationBarHidden ?? false))
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - WKNavigationDelegate
extension PostViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let status = self.isReadmode()
        self.changeReadmode(status: status)
        if #available(iOS 13.0, *) {
            setWebviewFontColor()
        }
        webView.evaluateJavaScript("document.readyState") { (complete, error) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
                    guard
                        self.subscriptionView.isHidden,
                        let height = height as? CGFloat
                    else { return }
                    self.embedPostFooterViewController(height: height)
                    self.setWebviewBackgroundColor()
                    self.postWebView.isHidden = false
                })
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated  {
            guard
                let requestUrlString = navigationAction.request.url?.absoluteString,
                let url = URL(string: requestUrlString)
            else {
                decisionHandler(.allow)
                return
            }
            if requestUrlString.contains("http://") || requestUrlString.contains("https://") {
                let safariViewController = SFSafariViewController(url: url)
                present(safariViewController, animated: true, completion: nil)
            } else {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension PostViewController: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

// MARK: - PostFooterViewDelegate
extension PostViewController: PostFooterViewDelegate {
    func loadComplete() {
        guard
            let footerViewController = self.footerViewController,
            let contentHeight = footerViewController.tableView?.contentSize.height
        else { return }
        postWebView.evaluateJavaScript("document.body.style.marginBottom =\"\(contentHeight)px\"")
    }
    func reloadPost(postId: Int) {
        loadPost.onNext(postId)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PostViewController: UIGestureRecognizerDelegate {
    // UIControl위에서 제스쳐 동작하지 않도록 함
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isKind(of: UIControl.self) ?? false) {
            return false
        }
        return true
    }

    // UITapGestureRecognizer, UIPanGestureRecognizer는 하나만 인식할 수 있도록 함
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UITapGestureRecognizer.self)
            && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            return false
        }
        return true
    }
}

// MARK: - Private Method
extension PostViewController {
    // Pad에서 가로/세로모드 변경 시 header, footer size 변경
    private func changeLayoutSubviews() {
        guard
            let headerView = headerViewController,
            let footerView = footerViewController
        else { return }

        headerView.view.frame.size.width = view.frame.size.width
        footerView.view.frame.size.width = view.frame.size.width
        resizeFooter()
    }

    // 이전, 다음 포스트 버튼 설정
    private func setLinkButton(button: UIButton?, postItem: PostModel?) {
        let isEnabled = postItem?.id != nil
        button?.isEnabled = isEnabled
        var buttonColor: UIColor {
            if #available(iOS 13.0, *) {
                return isEnabled ? .pictionDarkGrayDM : UIColor(r: 151, g: 151, b: 151)
            } else {
                return isEnabled ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151)
            }
        }
        button?.setTitleColor(buttonColor, for: .normal)
    }

    // post header embed
    private func embedPostHeaderViewController(postItem: PostModel, userInfo: UserModel) {
        if let headerView = headerViewController {
            remove(headerView)
        }
        headerViewController = PostHeaderViewController.make(postItem: postItem, userInfo: userInfo)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 220))
        containerView.tag = 1000
        embed(headerViewController!, to: containerView)
        self.postWebView.scrollView.addSubview(containerView)
    }

    // post footer를 embed
    private func embedPostFooterViewController(height: CGFloat) {
        if let footerView = self.footerViewController {
            remove(footerView)

            let posY = height - 747
            let containerView = UIView(frame: CGRect(x: 0, y: posY, width: view.frame.size.width, height: 747))
            containerView.tag = 1001
            embed(footerView, to: containerView)
            self.postWebView.scrollView.addSubview(containerView)
        }
    }

    // post footer 생성
    private func makePostFooterViewController(uri: String, postItem: PostModel) {
        if let footerView = footerViewController {
            remove(footerView)
        }
        footerViewController = PostFooterViewController.make(uri: uri, postItem: postItem)
        footerViewController?.delegate = self
    }

    // header, footer 제거
    private func removeHeaderFooter() {
        for subview in postWebView.scrollView.subviews {
            if subview.tag == 1000 || subview.tag == 1001 {
                subview.removeFromSuperview()
            }
        }
        guard
            let header = headerViewController,
            let footer = footerViewController
        else { return }
        remove(header)
        remove(footer)
    }

    // footer size 조정
    private func resizeFooter() {
        guard
            !postWebView.isLoading,
            subscriptionView.isHidden
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.postWebView.evaluateJavaScript("document.body.style.marginBottom =\"747px\"", completionHandler: { (complete, error) in
                self.postWebView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
                    if let height = height as? CGFloat {
                        self.embedPostFooterViewController(height: height)
                        self.loadComplete()
                    }
                })
            })
        }
    }

    // webview 캐시 정리
    private func cacheWebview() {
        postWebView?.stopLoading()
        postWebView?.loadHTMLString("", baseURL: nil)
        URLCache.shared.removeAllCachedResponses()
    }

    // full screen toggle
    private func showFullScreen(_ status: Bool = true, animated: Bool = true) {
        let isScrollTop = postWebView.scrollView.contentOffset.y <= -44
        let isScrollBottom = (postWebView.scrollView.contentOffset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
        let fullScreen = (isScrollTop || isScrollBottom) ? false : status
        self.navigationController?.setNavigationBarHidden(fullScreen, animated: animated)
        self.navigationController?.setToolbarHidden(fullScreen, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    // webview의 font 색 변경
    private func setWebviewFontColor() {
        if #available(iOS 13.0, *) {
            let fontColor = UIColor.pictionDarkGrayDM.hexString
            postWebView.evaluateJavaScript("document.getElementsByTagName('body')[0].style.color =\"\(fontColor ?? "#333333")\"")
        }
    }

    // 다크모드, 읽기모드 등에 따른 Webview의 배경색 변경
    private func setWebviewBackgroundColor() {
        // 잠겨있을 때는 readmode 설정에 따르지 않음
        guard readmodeBarButton.isEnabled else {
            if #available(iOS 13.0, *) {
                postWebView.backgroundColor = .systemBackground
            } else {
                postWebView.backgroundColor = .white
            }
            return
        }

        // 잠겨있지 않을 때 readmode가 활성화 되어 있지 않으면 기본 색
        if readmodeBarButton.tintColor == .pictionGray {
            if #available(iOS 13.0, *) {
                postWebView.backgroundColor = .systemBackground
            } else {
                postWebView.backgroundColor = .white
            }
        } else { // 잠겨있지 않을 때 readmode가 활성화 되어 있으면 읽기모드 배경색
            if #available(iOS 13.0, *) {
                postWebView.backgroundColor = .PictionReaderGrayDM
            } else {
                postWebView.backgroundColor = UIColor(r: 232, g: 239, b: 244)
            }
        }
        // footer의 배경 색도 변경
        if let backgroundColor = self.postWebView.backgroundColor {
            self.footerViewController?.changeBackgroundColor(color: backgroundColor)
        }
    }

    // readmode인지 확인
    private func isReadmode() -> Bool {
        guard
            let viewModel = self.viewModel,
            let userDefault = UserDefaults(suiteName: "group.\(BUNDLEID)")
        else { return false }
        return userDefault.bool(forKey: "readmode_\(viewModel.uri)")
    }

    // readmode 설정
    private func setReadmode(status: Bool) {
        guard
            let viewModel = self.viewModel,
            let userDefault = UserDefaults(suiteName: "group.\(BUNDLEID)")
        else { return }
        return userDefault.set(status, forKey: "readmode_\(viewModel.uri)")
    }

    // readmode 변경 시
    private func changeReadmode(status: Bool) {
        if status {
            let style = [
                "document.getElementsByTagName('body')[0].style.fontFamily =\"RIDIBatang\"",
                "document.getElementsByTagName('body')[0].style.lineHeight =\"35px\"",
                "document.getElementsByTagName('body')[0].style.fontSize =\"18px\"",
                "document.body.style.marginLeft =\"\(SCREEN_W / 8)px\"",
                "document.body.style.marginRight =\"\(SCREEN_W / 8)px\""
            ]
            style.forEach { postWebView.evaluateJavaScript($0) }
            readmodeBarButton.tintColor = UIView().tintColor
        } else {
            let style = [
                "document.getElementsByTagName('body')[0].style.fontFamily =\"Helvetica\"",
                "document.getElementsByTagName('body')[0].style.lineHeight =\"28px\"",
                "document.getElementsByTagName('body')[0].style.fontSize =\"16px\"",
                "document.body.style.marginLeft =\"20px\"",
                "document.body.style.marginRight =\"20px\""
            ]
            style.forEach { postWebView.evaluateJavaScript($0) }
            readmodeBarButton.tintColor = .pictionGray
        }
        setWebviewBackgroundColor()
        resizeFooter()
    }

    // readmode 버튼 숨김/해제
    private func readmodeBarButtonIsHidden(status: Bool) {
        readmodeBarButton.isEnabled = !status
        readmodeBarButton.image = status ? nil : #imageLiteral(resourceName: "ic-read")
    }
}
