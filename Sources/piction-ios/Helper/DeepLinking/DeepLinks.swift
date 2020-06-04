//
//  DeepLinks.swift
//  piction-ios
//
//  Created by jhseo on 02/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

/**
 *  로그인
 */

// 로그인
// piction://login
struct LoginDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("login")

    init(values: DeepLinkValues) {}
}

/**
*  회원가입
*/

// 회원가입
// piction://signup
struct SignupDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("signup")

    init(values: DeepLinkValues) {}
}

/**
*  홈
*/

// 홈
// piction://home
struct HomeDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("home")

    init(values: DeepLinkValues) {}
}


// 검색
// piction://search
struct SearchDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("search")

    init(values: DeepLinkValues) {}
}

// 태그 상세
// piction://tag
struct TaggingProjectDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("tag")
        .queryStringParameters([
            .requiredString(named: "keyword")
        ])

    init(values: DeepLinkValues) {
        keyword = values.query["keyword"] as? String
    }

    let keyword: String?
}

/**
*  탐색
*/

// 탐색
// piction://home-explore
struct HomeExploreDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("home-explore")

    init(values: DeepLinkValues) {}
}

// 카테고리 상세
// piction://category
struct CategorizedProjectDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("category")
        .queryStringParameters([
            .requiredString(named: "id")
        ])

    init(values: DeepLinkValues) {
        id = values.query["id"] as? Int
    }

    let id: Int?
}


/**
*  프로젝트 상세
*/

// 프로젝트
// piction://project?uri={project-uri}
struct ProjectDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("project")
        .queryStringParameters([
            .requiredString(named: "uri")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
    }

    let uri: String?
}

// (탭) 포스트
// piction://project/posts?uri={project-uri}
struct ProjectPostsDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("project")
        .term("post")
        .queryStringParameters([
            .requiredString(named: "uri")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
    }

    let uri: String?
}

// (탭) 시리즈
// piction://project/series?id={project-id}
struct ProjectSeriesDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("project")
        .term("series")
        .queryStringParameters([
            .requiredString(named: "uri")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
    }

    let uri: String?
}

// 프로젝트 정보
// piction://project/info?id={project-id}
struct ProjectInfoDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("project")
        .term("info")
        .queryStringParameters([
            .requiredString(named: "uri")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
    }

    let uri: String?
}

// 시리즈 상세
// piction://series?uri={project-uri}&seriesId={series-id}
struct SeriesDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("series")
        .queryStringParameters([
            .requiredString(named: "uri"),
            .requiredInt(named: "seriesId")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
        seriesId = values.query["seriesId"] as? Int
    }

    let uri: String?
    let seriesId: Int?
}

// 포스트 뷰어
// piction://viewer?uri={project-uri}&postId={post-id}
struct ViewerDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("viewer")
        .queryStringParameters([
            .requiredString(named: "uri"),
            .requiredInt(named: "postId")
        ])

    init(values: DeepLinkValues) {
        uri = values.query["uri"] as? String
        postId = values.query["postId"] as? Int
    }

    let uri: String?
    let postId: Int?
}

/**
*  구독
*/

// 구독
// piction://my-subscription
struct MySubscriptionDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("my-subscription")

    init(values: DeepLinkValues) {}
}

/**
*  마이페이지
*/

// 마이페이지
// piction://mypage
struct MypageDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("mypage")

    init(values: DeepLinkValues) {}
}

// 거래내역
// piction://transaction
struct TransactionDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("transaction")

    init(values: DeepLinkValues) {}
}

// 픽션 지갑으로 입금
// piction://wallet
struct WalletDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("wallet")

    init(values: DeepLinkValues) {}
}

// 기본정보 변경
// piction://myinfo
struct MyinfoDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("myinfo")

    init(values: DeepLinkValues) {}
}

// 비밀번호 변경
// piction://password
struct PasswordDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("password")

    init(values: DeepLinkValues) {}
}

// 이용약관
// piction://terms
struct TermsDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("terms")

    init(values: DeepLinkValues) {}
}

// 비밀번호 변경
// piction://privacy
struct PrivacyDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
        .term("privacy")

    init(values: DeepLinkValues) {}
}

// 후원 목록 Dynamic Links
// https://staging.piction.network/project/{project-uri}/memberships
// https://piction.network/project/{project-uri}/memberships
struct MembershipListDeepLink: DeepLink {
    static let template = DeepLinkTemplate()
    .term(AppInfo.urlDomain)
    .term("project")
    .string(named: "uri")
    .term("memberships")
    
    init(values: DeepLinkValues) {
        uri = values.path["uri"] as? String
    }
    
    let uri: String?
}
