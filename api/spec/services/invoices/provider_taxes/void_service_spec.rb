# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ProviderTaxes::VoidService do
  subject(:void_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    let(:invoice) do
      create(
        :invoice,
        :voided,
        :with_tax_voiding_error,
        :with_subscriptions,
        customer:,
        organization:,
        subscriptions: [subscription],
        currency: "EUR",
        issuing_date: Time.zone.at(timestamp).to_date
      )
    end

    let(:subscription) do
      create(
        :subscription,
        plan:,
        subscription_at: started_at,
        started_at:,
        created_at: started_at
      )
    end

    let(:timestamp) { Time.zone.now - 1.year }
    let(:started_at) { Time.zone.now - 2.years }
    let(:plan) { create(:plan, organization:, interval: "monthly") }
    let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
    let(:charge) { create(:standard_charge, plan: subscription.plan, charge_model: "standard", billable_metric:) }

    let(:fee_subscription) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 2_000
      )
    end
    let(:fee_charge) do
      create(
        :fee,
        invoice:,
        charge:,
        fee_type: :charge,
        total_aggregated_units: 100,
        amount_cents: 1_000
      )
    end

    let(:integration) { create(:anrok_integration, organization:) }
    let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
    let(:response1) { instance_double(Net::HTTPOK) }
    let(:lago_client1) { instance_double(LagoHttpClient::Client) }
    let(:response2) { instance_double(Net::HTTPOK) }
    let(:lago_client2) { instance_double(LagoHttpClient::Client) }
    let(:void_endpoint) { "https://api.nango.dev/v1/anrok/void_invoices" }
    let(:negate_endpoint) { "https://api.nango.dev/v1/anrok/negate_invoices" }
    let(:body_void) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_void.json")
      File.read(path)
    end
    let(:body_negate) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_negate.json")
      File.read(path)
    end
    let(:integration_collection_mapping) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :fallback_item,
        settings: {external_id: "1", external_account_code: "11", external_name: ""}
      )
    end

    before do
      integration_collection_mapping
      fee_subscription
      fee_charge
      integration_customer

      allow(LagoHttpClient::Client)
        .to receive(:new)
        .with(void_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client1)
      allow(lago_client1).to receive(:post_with_response).and_return(response1)
      allow(response1).to receive(:body).and_return(body_void)

      allow(LagoHttpClient::Client)
        .to receive(:new)
        .with(negate_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client2)
      allow(lago_client2).to receive(:post_with_response).and_return(response2)
      allow(response2).to receive(:body).and_return(body_negate)
    end

    context "when invoice does not exist" do
      it "returns an error" do
        result = described_class.new(invoice: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when invoice is not voided" do
      before { invoice.finalized! }

      it "returns an error" do
        result = void_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("status_not_voided")
      end
    end

    context "when voided invoice is successfully synced" do
      it "returns successful result" do
        result = void_service.call

        expect(result).to be_success
        expect(result.invoice.id).to eq(invoice.id)
      end

      it "discards previous tax errors" do
        expect { void_service.call }
          .to change(invoice.error_details.tax_voiding_error, :count).from(1).to(0)
      end
    end

    context "when failed result is returned from void endpoint" do
      let(:body_void) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
        File.read(path)
      end

      it "keeps invoice in voided status" do
        result = void_service.call

        expect(result).not_to be_success
        expect(LagoHttpClient::Client).to have_received(:new).with(void_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(LagoHttpClient::Client).not_to have_received(:new).with(negate_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(invoice.reload.status).to eq("voided")
      end

      it "resolves old tax error and creates new one" do
        old_error_id = invoice.reload.error_details.last.id

        void_service.call

        expect(invoice.error_details.tax_voiding_error.last.id).not_to eql(old_error_id)
        expect(invoice.error_details.tax_voiding_error.count).to be(1)
        expect(invoice.error_details.tax_voiding_error.order(created_at: :asc).last).not_to be_discarded
      end
    end

    context "when failed result is returned from negate endpoint" do
      let(:body_void) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response_void.json")
        File.read(path)
      end
      let(:body_negate) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
        File.read(path)
      end

      it "keeps invoice in voided status" do
        result = void_service.call

        expect(result).not_to be_success
        expect(LagoHttpClient::Client).to have_received(:new).with(void_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(LagoHttpClient::Client).to have_received(:new).with(negate_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(invoice.reload.status).to eq("voided")
      end

      it "resolves old tax error and creates new one" do
        old_error_id = invoice.reload.error_details.last.id

        void_service.call

        expect(invoice.error_details.tax_voiding_error.last.id).not_to eql(old_error_id)
        expect(invoice.error_details.tax_voiding_error.count).to be(1)
        expect(invoice.error_details.tax_voiding_error.order(created_at: :asc).last).not_to be_discarded
      end
    end

    context "when failed result is returned from refund endpoint for avalara customer" do
      let(:integration) { create(:avalara_integration, organization:) }
      let(:integration_customer) { create(:avalara_customer, integration:, customer:) }
      let(:void_endpoint) { "https://api.nango.dev/v1/avalara/void_invoices" }
      let(:negate_endpoint) { "https://api.nango.dev/v1/avalara/finalized_invoices" }
      let(:body_void) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response_locked_void.json")
        File.read(path)
      end
      let(:body_negate) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
        File.read(path)
      end

      it "keeps invoice in voided status" do
        result = void_service.call

        expect(result).not_to be_success
        expect(LagoHttpClient::Client).to have_received(:new).with(void_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(LagoHttpClient::Client).to have_received(:new).with(negate_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(invoice.reload.status).to eq("voided")
      end

      it "resolves old tax error and creates new one" do
        old_error_id = invoice.reload.error_details.last.id

        void_service.call

        expect(invoice.error_details.tax_voiding_error.last.id).not_to eql(old_error_id)
        expect(invoice.error_details.tax_voiding_error.count).to be(1)
        expect(invoice.error_details.tax_voiding_error.order(created_at: :asc).last).not_to be_discarded
      end
    end
  end
end
