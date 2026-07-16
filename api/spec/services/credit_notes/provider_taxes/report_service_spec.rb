# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::ProviderTaxes::ReportService do
  subject(:report_service) { described_class.new(credit_note:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    let(:invoice) do
      create(
        :invoice,
        :voided,
        :with_subscriptions,
        customer:,
        organization:,
        subscriptions: [subscription],
        currency: "EUR",
        issuing_date: Time.zone.at(timestamp).to_date
      )
    end
    let(:credit_note) do
      create(
        :credit_note,
        :with_tax_error,
        customer:,
        organization:,
        invoice:
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
    let(:response) { instance_double(Net::HTTPOK) }
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
    let(:body) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_multiple_fees.json")
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

      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:post_with_response).and_return(response)
      allow(response).to receive(:body).and_return(body)
    end

    context "when credit note does not exist" do
      it "returns an error" do
        result = described_class.new(credit_note: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("credit_note_not_found")
      end
    end

    context "when credit note is successfully synced" do
      it "returns successful result" do
        result = report_service.call

        expect(result).to be_success
        expect(result.credit_note.id).to eq(credit_note.id)
        expect(result.credit_note.integration_resources.last.external_id).not_to be_nil
        expect(result.credit_note.integration_resources.last.integration_id).to eq(integration.id)
      end

      it "discards previous tax errors" do
        expect { report_service.call }
          .to change(credit_note.error_details.tax_error, :count).from(1).to(0)
      end
    end

    context "when failed result is returned" do
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
        File.read(path)
      end

      it "returns validation error" do
        result = report_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(LagoHttpClient::Client).to have_received(:new).with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        expect(credit_note.reload.integration_resources.where(integration_id: integration.id).count).to eq(0)
      end

      it "resolves old tax error and creates new one" do
        old_error_id = credit_note.reload.error_details.order(created_at: :asc).last.id

        report_service.call

        expect(credit_note.error_details.tax_error.order(created_at: :asc).last.id).not_to eql(old_error_id)
        expect(credit_note.error_details.tax_error.count).to be(1)
        expect(credit_note.error_details.tax_error.order(created_at: :asc).last).not_to be_discarded
      end
    end
  end
end
