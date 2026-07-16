# frozen_string_literal: true

require Rails.root.join("lib/lago_http_client/lago_http_client")

class SendWebhookJob < ApplicationJob
  queue_as do
    if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_WEBHOOK"])
      :webhook_worker
    else
      :webhook
    end
  end

  retry_on ActiveJob::DeserializationError, wait: :polynomially_longer, attempts: 6

  # Retry when S3 throttles queries.
  retry_on "Aws::S3::Errors::SlowDown", wait: :polynomially_longer, attempts: 6

  WEBHOOK_SERVICES = {
    "alert.triggered" => Webhooks::UsageMonitoring::AlertTriggeredService,
    "billable_metric.created" => Webhooks::BillableMetrics::CreatedService,
    "billable_metric.updated" => Webhooks::BillableMetrics::UpdatedService,
    "billable_metric.deleted" => Webhooks::BillableMetrics::DeletedService,
    "dunning_campaign.finished" => Webhooks::DunningCampaigns::FinishedService,
    "invoice.created" => Webhooks::Invoices::CreatedService,
    "invoice.one_off_created" => Webhooks::Invoices::OneOffCreatedService,
    "invoice.paid_credit_added" => Webhooks::Invoices::PaidCreditAddedService,
    "invoice.generated" => Webhooks::Invoices::GeneratedService,
    "invoice.drafted" => Webhooks::Invoices::DraftedService,
    "invoice.ready_to_finalize" => Webhooks::Invoices::ReadyToFinalizeService,
    "invoice.voided" => Webhooks::Invoices::VoidedService,
    "invoice.payment_dispute_lost" => Webhooks::Invoices::PaymentDisputeLostService,
    "invoice.payment_status_updated" => Webhooks::Invoices::PaymentStatusUpdatedService,
    "invoice.payment_overdue" => Webhooks::Invoices::PaymentOverdueService,
    "invoice.payment_failure" => Webhooks::PaymentProviders::InvoicePaymentFailureService,
    "invoice.resynced" => Webhooks::Invoices::ResyncedService,
    "event.error" => Webhooks::Events::ErrorService,
    "events.errors" => Webhooks::Events::ValidationErrorsService,
    "fee.created" => Webhooks::Fees::PayInAdvanceCreatedService,
    "fee.tax_provider_error" => Webhooks::Integrations::Taxes::FeeErrorService,
    "customer.created" => Webhooks::Customers::CreatedService,
    "customer.updated" => Webhooks::Customers::UpdatedService,
    "customer.accounting_provider_created" => Webhooks::Integrations::AccountingCustomerCreatedService,
    "customer.accounting_provider_error" => Webhooks::Integrations::AccountingCustomerErrorService,
    "customer.crm_provider_created" => Webhooks::Integrations::CrmCustomerCreatedService,
    "customer.crm_provider_error" => Webhooks::Integrations::CrmCustomerErrorService,
    "customer.payment_provider_created" => Webhooks::PaymentProviders::CustomerCreatedService,
    "customer.payment_provider_error" => Webhooks::PaymentProviders::CustomerErrorService,
    "customer.checkout_url_generated" => Webhooks::PaymentProviders::CustomerCheckoutService,
    "customer.tax_provider_error" => Webhooks::Integrations::Taxes::ErrorService,
    "customer.vies_check" => Webhooks::Customers::ViesCheckService,
    "credit_note.created" => Webhooks::CreditNotes::CreatedService,
    "credit_note.generated" => Webhooks::CreditNotes::GeneratedService,
    "credit_note.provider_refund_failure" => Webhooks::CreditNotes::PaymentProviderRefundFailureService,
    "integration.provider_error" => Webhooks::Integrations::ProviderErrorService,
    "payment.requires_action" => Webhooks::Payments::RequiresActionService,
    "payment.succeeded" => Webhooks::Payments::SucceededService,
    "payment_provider.error" => Webhooks::PaymentProviders::ErrorService,
    "payment_receipt.created" => Webhooks::PaymentReceipts::CreatedService,
    "payment_receipt.generated" => Webhooks::PaymentReceipts::GeneratedService,
    "payment_request.created" => Webhooks::PaymentRequests::CreatedService,
    "payment_request.payment_failure" => Webhooks::PaymentProviders::PaymentRequestPaymentFailureService,
    "payment_request.payment_status_updated" => Webhooks::PaymentRequests::PaymentStatusUpdatedService,
    "plan.created" => Webhooks::Plans::CreatedService,
    "plan.deleted" => Webhooks::Plans::DeletedService,
    "plan.updated" => Webhooks::Plans::UpdatedService,
    "feature.created" => Webhooks::Features::CreatedService,
    "feature.updated" => Webhooks::Features::UpdatedService,
    "feature.deleted" => Webhooks::Features::DeletedService,
    "subscription.canceled" => Webhooks::Subscriptions::CanceledService,
    "subscription.incomplete" => Webhooks::Subscriptions::IncompleteService,
    "subscription.terminated" => Webhooks::Subscriptions::TerminatedService,
    "subscription.started" => Webhooks::Subscriptions::StartedService,
    "subscription.termination_alert" => Webhooks::Subscriptions::TerminationAlertService,
    "subscription.trial_ended" => Webhooks::Subscriptions::TrialEndedService,
    "subscription.updated" => Webhooks::Subscriptions::UpdatedService,
    "subscription.usage_threshold_reached" => Webhooks::Subscriptions::UsageThresholdsReachedService,
    "wallet.created" => Webhooks::Wallets::CreatedService,
    "wallet.updated" => Webhooks::Wallets::UpdatedService,
    "wallet.terminated" => Webhooks::Wallets::TerminatedService,
    "wallet.depleted_ongoing_balance" => Webhooks::Wallets::DepletedOngoingBalanceService,
    "wallet_transaction.created" => Webhooks::WalletTransactions::CreatedService,
    "wallet_transaction.updated" => Webhooks::WalletTransactions::UpdatedService,
    "wallet_transaction.payment_failure" => Webhooks::PaymentProviders::WalletTransactionPaymentFailureService
  }.freeze

  # This is a placeholder object to know which arguments were provided.
  UNDEFINED = Object.new.freeze
  private_constant :UNDEFINED

  # Override the default perform_later to avoid creating webhooks if no webhook endpoints are present.
  #
  # This will prevent enqueueing jobs only to return early from the jobs.
  def self.perform_later(webhook_type, object, options = UNDEFINED, webhook_id = UNDEFINED)
    return if (webhook_id.nil? || webhook_id == UNDEFINED) && object.organization.webhook_endpoints.none?

    args = [webhook_type, object, options, webhook_id].filter { |arg| arg != UNDEFINED }
    super(*args)
  end

  def perform(webhook_type, object, options = {}, webhook_id = nil)
    raise(NotImplementedError) unless WEBHOOK_SERVICES.include?(webhook_type)

    # NOTE: This condition is only temporary to handle enqueued jobs
    # TODO: Remove this condition after queued jobs are processed
    if webhook_id
      SendHttpWebhookJob.perform_later(Webhook.find(webhook_id))
      return
    end

    WEBHOOK_SERVICES.fetch(webhook_type).new(object:, options:).call
  end
end
