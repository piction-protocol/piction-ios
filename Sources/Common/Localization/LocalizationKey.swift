//
//  LocalizationKey.swift
//  piction-ios
//
//  Created by jhseo on 27/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

enum LocalizationKey {
    case confirm
    case pass
    case cancel
    case login
    case sign_up
    case close
    case create
    case continue_go
    case retry
    case edit
    case register
    case authenticates
    case more
    case delete

    // menu
    case menu_project_info
    case menu_my_info
    case menu_tags
    case menu_category
    case menu_my_project

    case tab_home
    case tab_explore
    case tab_sponsorship
    case tab_subscription
    case tab_posts
    case tab_series

    // Popup Title
    case popup_title_network_error
    case popup_title_pincode_sign_out
    case popup_title_pincode_create
    case popup_title_pincode_confirm
    case popup_title_notsupport_multiwindow
    case popup_title_delete_post
    case popup_title_delete_membership

    // Popup & Toast
    case msg_api_internal_server_error
    case msg_pincode_error
    case msg_pincode_confirm_error
    case msg_pincode_error_end
    case msg_pincode_reg_warning
    case msg_already_sign_in
    case msg_delete_post_success
    case msg_delete_membership_success

    case msg_creator_not_found
    case msg_not_piction_cp

    case msg_title_confirm
    case msg_title_confirm_password

    case msg_want_to_unsubscribe
    case msg_no_cancellation_subscription

    // hint
    case hint_input_id_guide
    case hint_input_nick_name
    case hint_current_pw
    case hint_need_six_pw
    case hint_pw_check
    case hint_project_and_tag_search
    case hint_project_search
    case hint_tag_search
    case hint_creator_search

    // Button
    case btn_new_post
    case btn_subs_membership
    case btn_subs_free
    case btn_user_sponsorship
    case btn_user_sponsorship_history
    case btn_save_changed
    case btn_qrcode

    // label
    case str_signup_done

    case str_empty_sponsorship

    case str_recently_sponsor
    case str_sponsorship_for

    case str_input_new_pincode
    case str_input_pincode
    case str_input_re_pincode
    case str_pin_warning

    case str_id
    case str_email
    case str_pw
    case str_current_pw
    case str_new_pw
    case str_pw_check
    case str_nick_name
    case str_agreement_text
    case str_terms
    case str_privacy

    case str_recommend_project
    case str_recommend_info
    case str_trending
    case str_trending_info
    case str_subscription_project
    case str_popular_tag
    case str_project_count
    case str_subs_count_plural
    case str_subs_only_with_membership_name
    case str_subs_only_with_membership
    case str_subs_only
    case str_series_subs_only
    case str_series_membership_subs_only
    case str_sort_with_direction
    case str_private_only

    case str_banner_header
    case str_banner_header_info

    case str_project_subscribing
    case str_project_membership
    case str_project_subscrition_complete
    case str_project_cancel_subscrition
    case str_series_posts_count
    case str_projects_count

    case str_date_format
    case str_reservation_datetime_format

    case str_creator
    case str_project_synopsis

    case str_input_sponsorship_amount
    case str_for_user
    case str_sponsorship_amount
    case str_fee_free

    case str_id_with_at
    case str_creator_sponsorship
    case str_delay_time

    case str_project_search_info
    case str_creator_search_info
    case str_tag_search_info

    case str_search_empty
    case str_subscription_empty
    case str_transaction_empty
    case str_post_empty
    case str_series_empty
    case str_project_empty
    case str_subscribing_project_empty
    case str_membership_empty

    case str_qrcode_scan
    case str_qrcode_help

    case str_pre_post
    case str_next_post
    case str_need_subs
    case str_post_date_format
    case str_series_date_format
    case str_need_login

    case str_completed
    case str_copy_address
    case str_copy_address_complete
    case str_attention
    case str_piction_address_management
    case str_transactions
    case str_security
    case str_change_pin
    case str_create_pin
    case str_user_profile
    case str_change_basic_info
    case str_change_pw
    case str_sign_out
    case str_service_center
    case str_year
    case str_deposit
    case str_wallet_address
    case str_deposit_pxl_guide
    case str_deposit_guide_1
    case str_deposit_guide_2
    case str_deposit_guide_3
    case str_deposit_guide_4_piction
    case str_have_pxl_amount
    case str_deposit_format
    case str_withdraw_format
    case str_membership_revenue
    case str_project_no_post
    case str_project_update_n_now
    case str_project_update_n_minute
    case str_project_update_n_hour
    case str_project_update_n_day
    case str_project_update_n_month
    case str_project_update_n_year
    case str_post_update_n_now
    case str_post_update_n_minute
    case str_post_update_n_hour
    case str_post_update_n_day
    case str_post_update_n_month
    case str_post_update_n_year
    case menu_deposit_detail
    case menu_withdraw_detail
    case str_transaction_info
    case str_sponsorship_info
    case str_sponsoredship_to
    case str_sponsorship_user
    case str_order_id
    case str_project
    case str_membership
    case str_membership_purchase
    case str_membership_sell_info
    case str_membership_buy_info
    case str_membership_seller
    case str_membership_buyer

    case str_membership_description
    case str_membership_limit
    case str_membership_postcount
    case str_membership_remain
    case str_membership_expire
    case str_membership_not_avaliable
    case str_membership_free_tier
    case str_membership_current_tier
    case str_membership_sponsorship_button
    case str_membership_warning_current_membership
    case str_membership_warning_description
    case str_membership_current_post_description

    case str_membership_select_membership
    case str_membership_show_description
    case str_membership_hide_description
    case str_membership_payment
    case str_membership_payment_piction
    case str_membership_purchase_amount
    case str_membership_expire_title
    case str_membership_expire_description
    case str_membership_agree
    case str_purchase
    case str_membership_transfer_info
    case str_membership_transfer_info_fees
    case str_membership_purchase_guide
    case str_membership_show_all
    case str_membership_cancel
    case str_membership_purchase_complete

    case str_authenticate_by_face_id
    case str_authenticate_by_touch_id
    case str_authenticate_type

    case str_sign_out_success

    case str_image_size_exceeded

    case str_delete_profile_image
    case str_change_profile_image

    case str_post_status_public
    case str_post_status_membership
    case str_post_status_private
    case str_post_status_deprecated
    case str_cancel_creation_post
    case str_select_project
    case str_select_series

    case str_create_post
    case str_post_title
    case str_post_content

    case str_login_first
    case str_create_project_first
    case str_select_project_first
    case str_saving_post
    case str_save_post_complete

    case str_modify
    case str_delete_series
    case str_deleted_series

    case str_add_series
    case str_modify_series
    case str_sort

    case str_series_management

    case str_create_project
    case str_modify_project
    case str_project_title
    case str_project_id
    case str_create_project_id_placeholder
    case str_create_project_uri
    case str_create_project_thumbnail_image
    case str_create_project_widethumbnail_guide
    case str_create_project_thumbnail_guide
    case str_create_project_synopsis_guide
    case str_create_tag_placeholder
    case str_create_project_hidden
    case str_create_project_hidden_description

    case str_modify_post

    case str_select_image_position
    case str_cover_image
    case str_create_post_cover_image_guide
    case str_post_content_image
    case str_setting_post_status

    case str_post_publish_date
    case str_post_publish_now
    case str_post_publish_guide

    case str_subscription_user_list

    case str_home_header_not_subscribing_subtitle
    case str_home_header_no_post_subtitle
}

extension LocalizationKey {
    public func localized(with args: CVarArg...) -> String {
        return String(format: String(describing: self).localized, arguments: args)
    }
}
