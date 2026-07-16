import { gql } from '@apollo/client'

export const typeDefs = gql`
  enum LagoApiError {
    internal_error
    unauthorized
    forbidden
    feature_unavailable
    not_found
    unprocessable_entity

    # Authentication & authentication errors
    token_encoding_error
    expired_jwt_token
    incorrect_login_or_password
    not_organization_member
    login_method_not_authorized

    # Validation errors
    coupon_is_not_reusable
    is_succeeded
    currencies_does_not_match
    does_not_match_item_amounts
    email_already_used
    invite_already_exists
    invite_email_mistmatch
    invite_not_found
    invoices_have_different_billing_entities
    invoices_have_different_currencies
    invoices_not_overdue
    invoices_not_ready_for_payment_processing
    no_active_subscription
    payment_processor_is_currently_handling_payment
    plan_overlapping
    url_is_invalid
    user_already_exists
    user_does_not_exist
    value_already_exist
    value_is_duplicated
    value_is_invalid
    value_is_out_of_range
    last_admin

    # Object not found
    missing_payment_provider_customer
    plan_not_found

    # SSO errors
    invalid_google_code
    invalid_google_token
    google_auth_missing_setup
    google_login_method_not_authorized
    domain_not_configured
    okta_login_method_not_authorized
    okta_userinfo_error

    # Anrok errors
    currencyCodeNotSupported
    customerAddressCountryNotSupported
    customerAddressCouldNotResolve
    productExternalIdUnknown

    # Avalara errors
    InvalidEnumValue
    MissingAddress
    NotEnoughAddressesInfo
    InvalidAddress
    InvalidPostalCode
    AddressLocationNotFound
    TaxCodeAssociatedWithItemCodeNotFound
    EntityNotFoundError
  }

  enum ApiKeysPermissionsEnum {
    activity_log
    add_on
    alert
    analytic
    applied_coupon
    billable_metric
    billing_entity
    coupon
    credit_note
    customer
    customer_usage
    event
    feature
    fee
    invoice
    invoice_custom_section
    lifetime_usage
    organization
    payment
    payment_receipt
    payment_request
    payment_method
    plan
    security_log
    subscription
    tax
    wallet
    wallet_transaction
    webhook_endpoint
    webhook_jwt_public_key
  }
`

export const resolvers = {}
