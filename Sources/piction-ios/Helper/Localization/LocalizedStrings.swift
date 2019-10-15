//
//  LocalizedStrings.swift
//  piction-ios
//
//  Created by jhseo on 27/09/2019.
//

import Foundation

enum LocalizedStrings {
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

    // menu
    case menu_project_info
    case menu_my_info
    case menu_project
    case menu_my_project

    case tab_explore
    case tab_sponsorship
    case tab_subscription

    // Popup Title
    case popup_title_network_error
    case popup_title_pincode_sign_out
    case popup_title_pincode_create
    case popup_title_pincode_confirm
    case popup_title_notsupport_multiwindow

    // Popup & Toast
    case msg_api_internal_server_error
    case msg_pincode_error
    case msg_pincode_confirm_error
    case msg_pincode_error_end
    case msg_pincode_reg_warning

    case msg_creator_not_found
    case msg_not_piction_cp

    case msg_title_confirm
    case msg_title_confirm_password

    case msg_want_to_unsubscribe

    // hint
    case hint_input_id_guide
    case hint_input_nick_name
    case hint_current_pw
    case hint_need_six_pw
    case hint_pw_check
    case hint_project_search
    case hint_creator_search

    // Button
    case btn_new_post
    case btn_subs
    case btn_user_sponsorship
    case btn_user_sponsorship_history
    case btn_save_changed
    case btn_qrcode
    case btn_post
    case btn_series

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
    case str_subs_count_plural
    case str_subs_only
    case str_series_subs_only
    case str_series_fanpass_subs_only
    case str_sort_with_direction

    case str_banner_header
    case str_banner_header_info

    case str_project_subscribing
    case str_project_subscrition_complete
    case str_project_cancel_subscrition
    case str_series_posts_count

    case str_date_format

    case str_creator
    case str_project_synopsis

    case str_deposit_guide_1
    case str_deposit_guide_2

    case str_input_sponsorship_amount
    case str_for_user
    case str_sponsorship_amount
    case str_fee_free

    case str_id_with_at
    case str_creator_sponsorship
    case str_delay_time

    case str_project_search_info
    case str_creator_search_info

    case str_search_empty
    case str_subscription_empty
    case str_transaction_empty
    case str_post_empty
    case str_series_empty
    case str_project_empty

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
    case str_transitions
    case str_security
    case str_change_pin
    case str_create_pin
    case str_user_profile
    case str_change_basic_info
    case str_change_pw
    case str_sign_out
    case str_service_center
    case str_year
    case str_deposit_format
    case str_withdraw_format
    case str_deposit_format_detail
    case str_withdraw_format_detail
    case str_sponsor_info
    case str_sponsor
    case str_sponsored_by
    case str_fanpass_sales_info
    case str_fanpass_purchase_info
    case str_order_no
    case str_seller
    case str_buyer
    case str_transaction_info

    case str_project_no_post
    case str_project_update_n_now
    case str_project_update_n_minute
    case str_project_update_n_hour
    case str_project_update_n_day
    case str_project_update_n_month
    case str_project_update_n_year

    case str_deposit
    case str_wallet_address
    case str_have_pxl_amount
    case str_deposit_pxl_guide
    case str_deposit_piction_guide_1
    case str_deposit_piction_guide_2

    case str_authenticate_by_face_id
    case str_authenticate_by_touch_id
    case str_authenticate_type

    case str_sign_out_success

    case str_image_size_exceeded

    case str_delete_profile_image
    case str_change_profile_image
}

extension LocalizedStrings {
    public func localized(with argument: CVarArg = []) -> String {
        return String.localizedStringWithFormat(String(describing: self).localized, argument)
    }
}
