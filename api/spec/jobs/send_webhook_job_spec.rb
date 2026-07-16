# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendWebhookJob do
  subject(:send_webhook_job) { described_class }

  let(:organization) { create(:organization, webhook_url: "http://foo.bar") }
  let(:invoice) { create(:invoice, organization:) }

  describe ".perform_later" do
    context "when no webhook endpoints is present" do
      let(:organization) { create(:organization, webhook_url: nil) }

      it "does not enqueue a job" do
        expect do
          described_class.perform_later("invoice.created", invoice)
        end.not_to have_enqueued_job(described_class)
      end

      context "when webhook_id is nil" do
        it "does not enqueue a job" do
          expect do
            described_class.perform_later("invoice.created", invoice, {}, nil)
          end.not_to have_enqueued_job(described_class)
        end
      end
    end

    context "when webhook_id is present" do
      let(:webhook) { create(:webhook, webhook_endpoint: organization.webhook_endpoints.first) }

      it "enqueues a job to send the webhook" do
        expect do
          described_class.perform_later("invoice.created", invoice, {}, webhook.id)
        end.to have_enqueued_job(described_class).with(
          "invoice.created",
          invoice,
          {},
          webhook.id
        )
      end
    end

    context "when webhook endpoint is present and no webhook_id is present" do
      it "enqueues a job to send the webhook" do
        expect do
          described_class.perform_later("invoice.created", invoice, {key: "value"})
        end.to have_enqueued_job(described_class).with("invoice.created", invoice, {key: "value"})
      end
    end
  end

  describe "#perform" do
    shared_examples "a webhook service" do |webhook_type, service_class, object, options|
      let(:webhook_service) { instance_double(service_class) }

      before do
        allow(service_class).to receive(:new)
          .with(object: object, options: options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(webhook_type, object, options)

        expect(service_class).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_id is present" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::CreatedService) }

      before do
        allow(Webhooks::Invoices::CreatedService).to receive(:new)
        allow(SendHttpWebhookJob).to receive(:perform_later)
      end

      it "calls the webhook invoice service" do
        webhook = create(:webhook, webhook_endpoint: create(:webhook_endpoint, organization:))
        send_webhook_job.perform_now("invoice.created", invoice, {}, webhook.id)

        expect(SendHttpWebhookJob).to have_received(:perform_later).with(webhook)
        expect(Webhooks::Invoices::CreatedService).not_to have_received(:new)
      end
    end

    context "when webhook_type is invoice.created" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::CreatedService) }

      before do
        allow(Webhooks::Invoices::CreatedService).to receive(:new)
          .with(object: invoice, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook invoice service" do
        send_webhook_job.perform_now("invoice.created", invoice)

        expect(Webhooks::Invoices::CreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is invoice.paid_credit_added" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::PaidCreditAddedService) }

      before do
        allow(Webhooks::Invoices::PaidCreditAddedService).to receive(:new)
          .with(object: invoice, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook invoice paid credit added service" do
        send_webhook_job.perform_now("invoice.paid_credit_added", invoice)

        expect(Webhooks::Invoices::PaidCreditAddedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is invoice.resynced" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::ResyncedService) }

      before do
        allow(Webhooks::Invoices::ResyncedService).to receive(:new)
          .with(object: invoice, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook invoice resynced service" do
        send_webhook_job.perform_now("invoice.resynced", invoice)

        expect(Webhooks::Invoices::ResyncedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is event" do
      let(:webhook_service) { instance_double(Webhooks::Events::ErrorService) }
      let(:object) do
        {
          input_params: {
            customer_id: "customer",
            transaction_id: SecureRandom.uuid,
            code: "code"
          },
          error: "Code does not exist",
          organization_id: organization.id
        }
      end

      before do
        allow(Webhooks::Events::ErrorService).to receive(:new)
          .with(object:, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now("event.error", object)

        expect(Webhooks::Events::ErrorService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is events.errors" do
      let(:webhook_service) { instance_double(Webhooks::Events::ValidationErrorsService) }
      let(:object) { organization }
      let(:options) do
        {
          errors: [
            invalid_code: [SecureRandom.uuid],
            missing_aggregation_property: [SecureRandom.uuid],
            missing_group_key: [SecureRandom.uuid]
          ]
        }
      end

      before do
        allow(Webhooks::Events::ValidationErrorsService).to receive(:new)
          .with(object:, options:)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now("events.errors", object, options)

        expect(Webhooks::Events::ValidationErrorsService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is fee.created" do
      let(:webhook_service) { instance_double(Webhooks::Fees::PayInAdvanceCreatedService) }
      let(:fee) { create(:fee) }

      before do
        allow(Webhooks::Fees::PayInAdvanceCreatedService).to receive(:new)
          .with(object: fee, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook fee service" do
        send_webhook_job.perform_now("fee.created", fee)

        expect(Webhooks::Fees::PayInAdvanceCreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is event.error" do
      let(:webhook_service) { instance_double(Webhooks::PaymentProviders::InvoicePaymentFailureService) }

      let(:webhook_options) do
        {
          provider_error: {
            message: "message",
            error_code: "code"
          }
        }
      end

      before do
        allow(Webhooks::PaymentProviders::InvoicePaymentFailureService).to receive(:new)
          .with(object: invoice, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now(
          "invoice.payment_failure",
          invoice,
          webhook_options
        )

        expect(Webhooks::PaymentProviders::InvoicePaymentFailureService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is customer.payment_provider_created" do
      let(:webhook_service) { instance_double(Webhooks::PaymentProviders::CustomerCreatedService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::PaymentProviders::CustomerCreatedService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now(
          "customer.payment_provider_created",
          customer
        )

        expect(Webhooks::PaymentProviders::CustomerCreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is customer.accounting_provider_created" do
      let(:webhook_service) { instance_double(Webhooks::Integrations::AccountingCustomerCreatedService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::Integrations::AccountingCustomerCreatedService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now(
          "customer.accounting_provider_created",
          customer
        )

        expect(Webhooks::Integrations::AccountingCustomerCreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is customer.crm_provider_created" do
      let(:webhook_service) { instance_double(Webhooks::Integrations::CrmCustomerCreatedService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::Integrations::CrmCustomerCreatedService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now(
          "customer.crm_provider_created",
          customer
        )

        expect(Webhooks::Integrations::CrmCustomerCreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is customer.checkout_url_generated" do
      let(:webhook_service) { instance_double(Webhooks::PaymentProviders::CustomerCheckoutService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::PaymentProviders::CustomerCheckoutService).to receive(:new)
          .with(object: customer, options: {checkout_url: "https://example.com"})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "customer.checkout_url_generated",
          customer,
          checkout_url: "https://example.com"
        )

        expect(Webhooks::PaymentProviders::CustomerCheckoutService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is customer.payment_provider_error" do
      let(:webhook_service) { instance_double(Webhooks::PaymentProviders::CustomerErrorService) }
      let(:customer) { create(:customer) }

      let(:webhook_options) do
        {
          provider_error: {
            message: "message",
            error_code: "code"
          }
        }
      end

      before do
        allow(Webhooks::PaymentProviders::CustomerErrorService).to receive(:new)
          .with(object: customer, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook event service" do
        send_webhook_job.perform_now(
          "customer.payment_provider_error",
          customer,
          webhook_options
        )

        expect(Webhooks::PaymentProviders::CustomerErrorService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is credit_note.created" do
      let(:webhook_service) { instance_double(Webhooks::CreditNotes::CreatedService) }
      let(:credit_note) { create(:credit_note) }

      before do
        allow(Webhooks::CreditNotes::CreatedService).to receive(:new)
          .with(object: credit_note, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "credit_note.created",
          credit_note
        )

        expect(Webhooks::CreditNotes::CreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is credit_note.generated" do
      let(:webhook_service) { instance_double(Webhooks::CreditNotes::GeneratedService) }
      let(:credit_note) { create(:credit_note) }

      before do
        allow(Webhooks::CreditNotes::GeneratedService).to receive(:new)
          .with(object: credit_note, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "credit_note.generated",
          credit_note
        )

        expect(Webhooks::CreditNotes::GeneratedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is credit_note.provider_refund_failure" do
      let(:webhook_service) { instance_double(Webhooks::CreditNotes::PaymentProviderRefundFailureService) }
      let(:credit_note) { create(:credit_note) }

      let(:webhook_options) do
        {
          provider_error: {
            message: "message",
            error_code: "code"
          }
        }
      end

      before do
        allow(Webhooks::CreditNotes::PaymentProviderRefundFailureService).to receive(:new)
          .with(object: credit_note, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        described_class.perform_now(
          "credit_note.provider_refund_failure",
          credit_note,
          webhook_options
        )

        expect(Webhooks::CreditNotes::PaymentProviderRefundFailureService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is invoice.drafted" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::DraftedService) }
      let(:invoice) { create(:invoice, organization:) }

      before do
        allow(Webhooks::Invoices::DraftedService).to receive(:new)
          .with(object: invoice, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "invoice.drafted",
          invoice
        )

        expect(Webhooks::Invoices::DraftedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook type is invoice.payment_status_updated" do
      let(:webhook_service) { instance_double(Webhooks::Invoices::PaymentStatusUpdatedService) }
      let(:invoice) { create(:invoice, organization:) }

      before do
        allow(Webhooks::Invoices::PaymentStatusUpdatedService).to receive(:new)
          .with(object: invoice, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "invoice.payment_status_updated",
          invoice
        )

        expect(Webhooks::Invoices::PaymentStatusUpdatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "with not implemented webhook type" do
      it "raises a NotImplementedError" do
        expect { send_webhook_job.perform_now(:subscription, invoice) }
          .to raise_error(NotImplementedError)
      end
    end

    context "with subscription webhooks" do
      let(:object) { create(:subscription) }
      let(:options) { {usage_threshold: create(:usage_threshold)} }

      it_behaves_like "a webhook service",
        "subscription.canceled",
        Webhooks::Subscriptions::CanceledService

      it_behaves_like "a webhook service",
        "subscription.incomplete",
        Webhooks::Subscriptions::IncompleteService

      it_behaves_like "a webhook service",
        "subscription.started",
        Webhooks::Subscriptions::StartedService

      it_behaves_like "a webhook service",
        "subscription.terminated",
        Webhooks::Subscriptions::TerminatedService

      it_behaves_like "a webhook service",
        "subscription.updated",
        Webhooks::Subscriptions::UpdatedService

      it_behaves_like "a webhook service",
        "subscription.termination_alert",
        Webhooks::Subscriptions::TerminationAlertService

      it_behaves_like "a webhook service",
        "subscription.trial_ended",
        Webhooks::Subscriptions::TrialEndedService

      it_behaves_like "a webhook service",
        "subscription.usage_threshold_reached",
        Webhooks::Subscriptions::UsageThresholdsReachedService
    end

    context "when webhook type is customer.vies_check" do
      let(:webhook_service) { instance_double(Webhooks::Customers::ViesCheckService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::Customers::ViesCheckService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "customer.vies_check",
          customer
        )

        expect(Webhooks::Customers::ViesCheckService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook type is customer.created" do
      let(:webhook_service) { instance_double(Webhooks::Customers::CreatedService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::Customers::CreatedService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the created webhook service" do
        send_webhook_job.perform_now("customer.created", customer)

        expect(Webhooks::Customers::CreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook type is customer.updated" do
      let(:webhook_service) { instance_double(Webhooks::Customers::UpdatedService) }
      let(:customer) { create(:customer) }

      before do
        allow(Webhooks::Customers::UpdatedService).to receive(:new)
          .with(object: customer, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the updated webhook service" do
        send_webhook_job.perform_now("customer.updated", customer)

        expect(Webhooks::Customers::UpdatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment_request.created" do
      let(:webhook_service) { instance_double(Webhooks::PaymentRequests::CreatedService) }
      let(:payment_request) { create(:payment_request) }

      before do
        allow(Webhooks::PaymentRequests::CreatedService).to receive(:new)
          .with(object: payment_request, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook payment_request service" do
        send_webhook_job.perform_now("payment_request.created", payment_request)

        expect(Webhooks::PaymentRequests::CreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment_receipt.created" do
      let(:webhook_service) { instance_double(Webhooks::PaymentReceipts::CreatedService) }
      let(:payment_receipt) { create(:payment_receipt) }

      before do
        allow(Webhooks::PaymentReceipts::CreatedService).to receive(:new)
          .with(object: payment_receipt, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook payment_receipt service" do
        send_webhook_job.perform_now("payment_receipt.created", payment_receipt)

        expect(Webhooks::PaymentReceipts::CreatedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment_receipt.generated" do
      let(:webhook_service) { instance_double(Webhooks::PaymentReceipts::GeneratedService) }
      let(:payment_receipt) { create(:payment_receipt) }

      before do
        allow(Webhooks::PaymentReceipts::GeneratedService).to receive(:new)
          .with(object: payment_receipt, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook service" do
        send_webhook_job.perform_now(
          "payment_receipt.generated",
          payment_receipt
        )

        expect(Webhooks::PaymentReceipts::GeneratedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment_request.payment_failure" do
      let(:webhook_service) { instance_double(Webhooks::PaymentProviders::PaymentRequestPaymentFailureService) }
      let(:payment_request) { create(:payment_request) }
      let(:webhook_options) do
        {
          provider_error: {
            message: "message",
            error_code: "code"
          }
        }
      end

      before do
        allow(Webhooks::PaymentProviders::PaymentRequestPaymentFailureService)
          .to receive(:new)
          .with(object: payment_request, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook payment_request_payment_failure service" do
        send_webhook_job.perform_now("payment_request.payment_failure", payment_request, webhook_options)

        expect(Webhooks::PaymentProviders::PaymentRequestPaymentFailureService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment.requires_action" do
      let(:webhook_service) { instance_double(Webhooks::Payments::RequiresActionService) }
      let(:payment) { create(:payment, :requires_action) }
      let(:webhook_options) do
        {
          provider_customer_id: "customer_id"
        }
      end

      before do
        allow(Webhooks::Payments::RequiresActionService)
          .to receive(:new)
          .with(object: payment, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook payment.requires_action" do
        send_webhook_job.perform_now("payment.requires_action", payment, webhook_options)

        expect(Webhooks::Payments::RequiresActionService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "when webhook_type is payment.succeeded" do
      let(:webhook_service) { instance_double(Webhooks::Payments::SucceededService) }
      let(:payment) { create(:payment) }

      before do
        allow(Webhooks::Payments::SucceededService)
          .to receive(:new)
          .with(object: payment, options: {})
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook payment.succeeded" do
        send_webhook_job.perform_now("payment.succeeded", payment)

        expect(Webhooks::Payments::SucceededService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end

    context "with billable metric webhooks" do
      let(:object) { create(:billable_metric, organization:) }

      it_behaves_like "a webhook service",
        "billable_metric.created",
        Webhooks::BillableMetrics::CreatedService

      it_behaves_like "a webhook service",
        "billable_metric.updated",
        Webhooks::BillableMetrics::UpdatedService

      it_behaves_like "a webhook service",
        "billable_metric.deleted",
        Webhooks::BillableMetrics::DeletedService
    end

    context "when webhook_type is dunning_campaign.finished" do
      let(:webhook_service) { instance_double(Webhooks::DunningCampaigns::FinishedService) }
      let(:customer) { create(:customer) }
      let(:webhook_options) do
        {
          dunning_campaign_code: "campaign_code"
        }
      end

      before do
        allow(Webhooks::DunningCampaigns::FinishedService)
          .to receive(:new)
          .with(object: customer, options: webhook_options)
          .and_return(webhook_service)
        allow(webhook_service).to receive(:call)
      end

      it "calls the webhook dunning_campaign.finished" do
        send_webhook_job.perform_now("dunning_campaign.finished", customer, webhook_options)

        expect(Webhooks::DunningCampaigns::FinishedService).to have_received(:new)
        expect(webhook_service).to have_received(:call)
      end
    end
  end
end
