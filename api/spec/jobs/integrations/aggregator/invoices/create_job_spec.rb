# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::CreateJob do
  subject(:create_job) { described_class }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:result) { BaseService::Result.new }
  let(:reconcile_result) { BaseService::Result.new }

  before do
    allow(Integrations::Aggregator::Invoices::CreateService).to receive(:call).and_return(result)
    allow(Integrations::Aggregator::Invoices::ReconcileService).to receive(:call).and_return(reconcile_result)
  end

  context "when find_first: true" do
    context "when ReconcileService does not find the invoice upstream" do
      it "calls ReconcileService and then CreateService" do
        described_class.perform_now(invoice:, find_first: true)

        expect(Integrations::Aggregator::Invoices::ReconcileService).to have_received(:call).with(invoice:)
        expect(Integrations::Aggregator::Invoices::CreateService).to have_received(:call).with(invoice:)
      end
    end

    context "when ReconcileService finds the invoice upstream" do
      before { reconcile_result.external_id = "12345" }

      it "skips CreateService" do
        described_class.perform_now(invoice:, find_first: true)

        expect(Integrations::Aggregator::Invoices::ReconcileService).to have_received(:call).with(invoice:)
        expect(Integrations::Aggregator::Invoices::CreateService).not_to have_received(:call)
      end
    end
  end

  context "when find_first: false" do
    context "when it is the first execution" do
      it "calls CreateService without calling ReconcileService" do
        described_class.perform_now(invoice:)

        expect(Integrations::Aggregator::Invoices::ReconcileService).not_to have_received(:call)
        expect(Integrations::Aggregator::Invoices::CreateService).to have_received(:call).with(invoice:)
      end
    end

    context "when it is a retry execution" do
      subject(:create_job) { described_class.new(invoice:) }

      before { create_job.executions = 1 }

      context "when ReconcileService does not find the invoice upstream" do
        it "calls ReconcileService and then CreateService" do
          create_job.perform_now

          expect(Integrations::Aggregator::Invoices::ReconcileService).to have_received(:call).with(invoice:)
          expect(Integrations::Aggregator::Invoices::CreateService).to have_received(:call).with(invoice:)
        end
      end

      context "when ReconcileService finds the invoice upstream" do
        before { reconcile_result.external_id = "12345" }

        it "skips CreateService" do
          create_job.perform_now

          expect(Integrations::Aggregator::Invoices::ReconcileService).to have_received(:call).with(invoice:)
          expect(Integrations::Aggregator::Invoices::CreateService).not_to have_received(:call)
        end
      end

      context "when ReconcileService fails with a retryable HTTP error" do
        let(:http_error) { LagoHttpClient::HttpError.new(500, "{}", nil) }

        before do
          allow(reconcile_result).to receive(:raise_if_error!).and_raise(http_error)
        end

        it "re-enqueues the job and does not call CreateService" do
          expect { create_job.perform_now }
            .to have_enqueued_job(described_class)
          expect(Integrations::Aggregator::Invoices::CreateService).not_to have_received(:call)
        end
      end

      context "when ReconcileService fails with a non-retryable failure" do
        before { reconcile_result.non_retryable_failure!(code: "client_error", message: "bad request") }

        it "discards the job and does not call CreateService" do
          expect { create_job.perform_now }.not_to raise_error
          expect(Integrations::Aggregator::Invoices::CreateService).not_to have_received(:call)
        end
      end
    end
  end

  describe "Net::ReadTimeout retry" do
    before do
      allow(Integrations::Aggregator::Invoices::CreateService).to receive(:call).and_raise(Net::ReadTimeout.new)
    end

    context "when the invoice is for a NetSuite integration" do
      let(:integration) { create(:netsuite_integration, organization:) }

      before { create(:netsuite_customer, integration:, customer:) }

      it "schedules the next attempt at least 6 minutes later" do
        freeze_time do
          described_class.perform_now(invoice:)

          retry_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]
          # NOTE: ActiveJob applies up to 15% positive jitter on top of the configured wait,
          # so the retry lands in [6 minutes, 6 minutes + 15%] from now.
          expect(retry_at).to be_between(6.minutes.from_now.to_f, 7.minutes.from_now.to_f)
        end
      end
    end

    context "when the invoice is for a non-NetSuite integration" do
      let(:integration) { create(:xero_integration, organization:) }

      before { create(:xero_customer, integration:, customer:) }

      it "schedules the next attempt with polynomial backoff" do
        freeze_time do
          described_class.perform_now(invoice:)

          retry_at = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:at]
          # NOTE: First polynomial retry is ~3s (1**4 + 2) plus up to 15% jitter; well under a minute.
          expect(retry_at).to be < 1.minute.from_now.to_f
        end
      end
    end
  end
end
