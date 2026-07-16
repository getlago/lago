# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :login_user, mutation: Mutations::LoginUser
    field :register_user, mutation: Mutations::RegisterUser

    field :update_organization, mutation: Mutations::Organizations::Update

    field :create_billable_metric, mutation: Mutations::BillableMetrics::Create
    field :destroy_billable_metric, mutation: Mutations::BillableMetrics::Destroy
    field :update_billable_metric, mutation: Mutations::BillableMetrics::Update

    field :billing_entity_apply_taxes, mutation: Mutations::BillingEntities::ApplyTaxes
    field :billing_entity_remove_taxes, mutation: Mutations::BillingEntities::RemoveTaxes
    field :billing_entity_update_applied_dunning_campaign, mutation: Mutations::BillingEntities::UpdateAppliedDunningCampaign
    field :create_billing_entity, mutation: Mutations::BillingEntities::Create
    field :destroy_billing_entity, mutation: Mutations::BillingEntities::Destroy
    field :update_billing_entity, mutation: Mutations::BillingEntities::Update

    field :create_adjusted_fee, mutation: Mutations::AdjustedFees::Create
    field :destroy_adjusted_fee, mutation: Mutations::AdjustedFees::Destroy
    field :preview_adjusted_fee, mutation: Mutations::AdjustedFees::Preview

    field :create_plan, mutation: Mutations::Plans::Create
    field :destroy_plan, mutation: Mutations::Plans::Destroy
    field :update_plan, mutation: Mutations::Plans::Update

    field :create_charge, mutation: Mutations::Charges::Create
    field :destroy_charge, mutation: Mutations::Charges::Destroy
    field :update_charge, mutation: Mutations::Charges::Update

    field :create_charge_filter, mutation: Mutations::ChargeFilters::Create
    field :destroy_charge_filter, mutation: Mutations::ChargeFilters::Destroy
    field :update_charge_filter, mutation: Mutations::ChargeFilters::Update

    field :create_fixed_charge, mutation: Mutations::FixedCharges::Create
    field :destroy_fixed_charge, mutation: Mutations::FixedCharges::Destroy
    field :update_fixed_charge, mutation: Mutations::FixedCharges::Update

    field :create_customer, mutation: Mutations::Customers::Create
    field :destroy_customer, mutation: Mutations::Customers::Destroy
    field :update_customer, mutation: Mutations::Customers::Update
    field :update_customer_invoice_grace_period, mutation: Mutations::Customers::UpdateInvoiceGracePeriod

    field :create_customer_portal_wallet_transaction, mutation: Mutations::CustomerPortal::WalletTransactions::Create
    field :download_customer_portal_invoice, mutation: Mutations::CustomerPortal::DownloadInvoice
    field :generate_customer_portal_url, mutation: Mutations::CustomerPortal::GenerateUrl
    field :update_customer_portal_customer, mutation: Mutations::CustomerPortal::UpdateCustomer

    field :create_credit_notes_data_export, mutation: Mutations::DataExports::CreditNotes::Create
    field :create_invoices_data_export, mutation: Mutations::DataExports::Invoices::Create

    field :create_subscription, mutation: Mutations::Subscriptions::Create
    field :terminate_subscription, mutation: Mutations::Subscriptions::Terminate
    field :update_subscription, mutation: Mutations::Subscriptions::Update
    field :update_subscription_charge, mutation: Mutations::Subscriptions::UpdateCharge
    field :update_subscription_fixed_charge, mutation: Mutations::Subscriptions::UpdateFixedCharge

    field :create_subscription_charge_filter, mutation: Mutations::Subscriptions::CreateChargeFilter
    field :destroy_subscription_charge_filter, mutation: Mutations::Subscriptions::DestroyChargeFilter
    field :update_subscription_charge_filter, mutation: Mutations::Subscriptions::UpdateChargeFilter

    field :create_coupon, mutation: Mutations::Coupons::Create
    field :destroy_coupon, mutation: Mutations::Coupons::Destroy
    field :terminate_coupon, mutation: Mutations::Coupons::Terminate
    field :update_coupon, mutation: Mutations::Coupons::Update

    field :mark_order_form_as_signed, mutation: Mutations::OrderForms::MarkAsSigned

    field :create_add_on, mutation: Mutations::AddOns::Create
    field :create_applied_coupon, mutation: Mutations::AppliedCoupons::Create
    field :destroy_add_on, mutation: Mutations::AddOns::Destroy
    field :terminate_applied_coupon, mutation: Mutations::AppliedCoupons::Terminate
    field :update_add_on, mutation: Mutations::AddOns::Update

    field :add_adyen_payment_provider, mutation: Mutations::PaymentProviders::Adyen::Create
    field :add_cashfree_payment_provider, mutation: Mutations::PaymentProviders::Cashfree::Create
    field :add_flutterwave_payment_provider, mutation: Mutations::PaymentProviders::Flutterwave::Create
    field :add_gocardless_payment_provider, mutation: Mutations::PaymentProviders::Gocardless::Create
    field :add_moneyhash_payment_provider, mutation: Mutations::PaymentProviders::Moneyhash::Create
    field :add_stripe_payment_provider, mutation: Mutations::PaymentProviders::Stripe::Create

    field :update_adyen_payment_provider, mutation: Mutations::PaymentProviders::Adyen::Update
    field :update_cashfree_payment_provider, mutation: Mutations::PaymentProviders::Cashfree::Update
    field :update_flutterwave_payment_provider, mutation: Mutations::PaymentProviders::Flutterwave::Update
    field :update_gocardless_payment_provider, mutation: Mutations::PaymentProviders::Gocardless::Update
    field :update_moneyhash_payment_provider, mutation: Mutations::PaymentProviders::Moneyhash::Update
    field :update_stripe_payment_provider, mutation: Mutations::PaymentProviders::Stripe::Update

    field :destroy_payment_provider, mutation: Mutations::PaymentProviders::Destroy

    field :destroy_payment_method, mutation: Mutations::PaymentMethods::Destroy
    field :generate_checkout_url, mutation: Mutations::PaymentMethods::GenerateCheckoutUrl
    field :set_payment_method_as_default, mutation: Mutations::PaymentMethods::SetAsDefault

    field :create_netsuite_integration, mutation: Mutations::Integrations::Netsuite::Create
    field :destroy_integration, mutation: Mutations::Integrations::Destroy
    field :update_netsuite_integration, mutation: Mutations::Integrations::Netsuite::Update

    field :create_integration_mapping, mutation: Mutations::IntegrationMappings::Create
    field :update_integration_mapping, mutation: Mutations::IntegrationMappings::Update

    field :create_integration_collection_mapping, mutation: Mutations::IntegrationCollectionMappings::Create
    field :update_integration_collection_mapping, mutation: Mutations::IntegrationCollectionMappings::Update

    field :destroy_integration_collection_mapping, mutation: Mutations::IntegrationCollectionMappings::Destroy
    field :destroy_integration_mapping, mutation: Mutations::IntegrationMappings::Destroy

    field :fetch_integration_accounts, mutation: Mutations::IntegrationItems::FetchAccounts
    field :fetch_integration_items, mutation: Mutations::IntegrationItems::FetchItems

    field :sync_hubspot_integration_invoice, mutation: Mutations::Integrations::Hubspot::SyncInvoice
    field :sync_integration_credit_note, mutation: Mutations::Integrations::SyncCreditNote
    field :sync_integration_invoice, mutation: Mutations::Integrations::SyncInvoice
    field :sync_salesforce_invoice, mutation: Mutations::Integrations::Salesforce::SyncInvoice

    field :create_credit_note, mutation: Mutations::CreditNotes::Create
    field :download_credit_note, mutation: Mutations::CreditNotes::Download
    field :download_xml_credit_note, mutation: Mutations::CreditNotes::DownloadXml
    field :resend_credit_note_email, mutation: Mutations::CreditNotes::ResendEmail
    field :retry_tax_reporting, mutation: Mutations::CreditNotes::RetryTaxReporting
    field :update_credit_note, mutation: Mutations::CreditNotes::Update
    field :void_credit_note, mutation: Mutations::CreditNotes::Void

    field :create_invoice, mutation: Mutations::Invoices::Create
    field :download_invoice, mutation: Mutations::Invoices::Download
    field :download_invoice_xml, mutation: Mutations::Invoices::DownloadXml
    field :finalize_all_invoices, mutation: Mutations::Invoices::FinalizeAll
    field :finalize_invoice, mutation: Mutations::Invoices::Finalize
    field :generate_payment_url, mutation: Mutations::Invoices::GeneratePaymentUrl
    field :lose_invoice_dispute, mutation: Mutations::Invoices::LoseDispute
    field :refresh_invoice, mutation: Mutations::Invoices::Refresh
    field :regenerate_from_voided, mutation: Mutations::Invoices::RegenerateFromVoided
    field :resend_invoice_email, mutation: Mutations::Invoices::ResendEmail
    field :retry_all_invoice_payments, mutation: Mutations::Invoices::RetryAllPayments
    field :retry_all_invoices, mutation: Mutations::Invoices::RetryAll
    field :retry_invoice, mutation: Mutations::Invoices::Retry
    field :retry_invoice_payment, mutation: Mutations::Invoices::RetryPayment
    field :retry_tax_provider_voiding, mutation: Mutations::Invoices::RetryTaxProviderVoiding
    field :update_invoice, mutation: Mutations::Invoices::Update
    field :void_invoice, mutation: Mutations::Invoices::Void

    field :add_quote_image, mutation: Mutations::Quotes::AddImage
    field :create_quote, mutation: Mutations::Quotes::Create
    field :update_quote, mutation: Mutations::Quotes::Update

    field :approve_quote_version, mutation: Mutations::QuoteVersions::Approve
    field :clone_quote_version, mutation: Mutations::QuoteVersions::Clone
    field :update_quote_version, mutation: Mutations::QuoteVersions::Update
    field :void_quote_version, mutation: Mutations::QuoteVersions::Void

    field :void_order_form, mutation: Mutations::OrderForms::Void

    field :update_order, mutation: Mutations::Orders::Update

    field :download_payment_receipt, mutation: Mutations::PaymentReceipts::Download
    field :download_xml_payment_receipt, mutation: Mutations::PaymentReceipts::DownloadXml
    field :resend_payment_receipt_email, mutation: Mutations::PaymentReceipts::ResendEmail

    field :create_customer_wallet, mutation: Mutations::Wallets::Create
    field :terminate_customer_wallet, mutation: Mutations::Wallets::Terminate
    field :update_customer_wallet, mutation: Mutations::Wallets::Update

    field :create_customer_wallet_transaction, mutation: Mutations::WalletTransactions::Create

    field :create_customer_wallet_alert, mutation: Mutations::Wallets::Alerts::Create
    field :destroy_customer_wallet_alert, mutation: Mutations::Wallets::Alerts::Destroy
    field :update_customer_wallet_alert, mutation: Mutations::Wallets::Alerts::Update

    field :accept_invite, mutation: Mutations::Invites::Accept
    field :create_invite, mutation: Mutations::Invites::Create
    field :revoke_invite, mutation: Mutations::Invites::Revoke
    field :update_invite, mutation: Mutations::Invites::Update

    field :revoke_membership, mutation: Mutations::Memberships::Revoke
    field :update_membership, mutation: Mutations::Memberships::Update

    field :create_payment, mutation: Mutations::Payments::Create

    field :create_payment_request, mutation: Mutations::PaymentRequests::Create

    field :create_password_reset, mutation: Mutations::PasswordResets::Create
    field :reset_password, mutation: Mutations::PasswordResets::Reset

    field :create_tax, mutation: Mutations::Taxes::Create
    field :destroy_tax, mutation: Mutations::Taxes::Destroy
    field :update_tax, mutation: Mutations::Taxes::Update

    field :retry_webhook, mutation: Mutations::Webhooks::Retry

    field :create_webhook_endpoint, mutation: Mutations::WebhookEndpoints::Create
    field :destroy_webhook_endpoint, mutation: Mutations::WebhookEndpoints::Destroy
    field :update_webhook_endpoint, mutation: Mutations::WebhookEndpoints::Update

    field :google_accept_invite, mutation: Mutations::Auth::Google::AcceptInvite
    field :google_login_user, mutation: Mutations::Auth::Google::LoginUser
    field :google_register_user, mutation: Mutations::Auth::Google::RegisterUser

    field :create_okta_integration, mutation: Mutations::Integrations::Okta::Create
    field :update_okta_integration, mutation: Mutations::Integrations::Okta::Update

    field :create_anrok_integration, mutation: Mutations::Integrations::Anrok::Create
    field :update_anrok_integration, mutation: Mutations::Integrations::Anrok::Update

    field :create_avalara_integration, mutation: Mutations::Integrations::Avalara::Create
    field :update_avalara_integration, mutation: Mutations::Integrations::Avalara::Update

    field :fetch_draft_invoice_taxes, mutation: Mutations::Integrations::FetchDraftInvoiceTaxes

    field :create_xero_integration, mutation: Mutations::Integrations::Xero::Create
    field :update_xero_integration, mutation: Mutations::Integrations::Xero::Update

    field :create_hubspot_integration, mutation: Mutations::Integrations::Hubspot::Create
    field :update_hubspot_integration, mutation: Mutations::Integrations::Hubspot::Update

    field :create_salesforce_integration, mutation: Mutations::Integrations::Salesforce::Create
    field :update_salesforce_integration, mutation: Mutations::Integrations::Salesforce::Update

    field :okta_accept_invite, mutation: Mutations::Auth::Okta::AcceptInvite
    field :okta_authorize, mutation: Mutations::Auth::Okta::Authorize
    field :okta_login, mutation: Mutations::Auth::Okta::Login

    field :create_dunning_campaign, mutation: Mutations::DunningCampaigns::Create
    field :destroy_dunning_campaign, mutation: Mutations::DunningCampaigns::Destroy
    field :update_dunning_campaign, mutation: Mutations::DunningCampaigns::Update

    field :create_api_key, mutation: Mutations::ApiKeys::Create
    field :destroy_api_key, mutation: Mutations::ApiKeys::Destroy
    field :rotate_api_key, mutation: Mutations::ApiKeys::Rotate
    field :update_api_key, mutation: Mutations::ApiKeys::Update

    field :create_pricing_unit, mutation: Mutations::PricingUnits::Create
    field :update_pricing_unit, mutation: Mutations::PricingUnits::Update

    field :create_role, mutation: Mutations::Roles::Create
    field :destroy_role, mutation: Mutations::Roles::Destroy
    field :update_role, mutation: Mutations::Roles::Update

    field :create_invoice_custom_section, mutation: Mutations::InvoiceCustomSections::Create
    field :destroy_invoice_custom_section, mutation: Mutations::InvoiceCustomSections::Destroy
    field :update_invoice_custom_section, mutation: Mutations::InvoiceCustomSections::Update

    field :create_subscription_alert, mutation: Mutations::Subscriptions::Alerts::Create
    field :destroy_subscription_alert, mutation: Mutations::Subscriptions::Alerts::Destroy
    field :update_subscription_alert, mutation: Mutations::Subscriptions::Alerts::Update

    field :create_feature, mutation: Mutations::Entitlement::CreateFeature
    field :destroy_feature, mutation: Mutations::Entitlement::DestroyFeature
    field :update_feature, mutation: Mutations::Entitlement::UpdateFeature

    field :create_or_update_subscription_entitlement, mutation: Mutations::Entitlement::CreateOrUpdateSubscriptionEntitlement
    field :remove_subscription_entitlement, mutation: Mutations::Entitlement::RemoveSubscriptionEntitlement

    field :create_ai_conversation, mutation: Mutations::AiConversations::Create
  end
end
