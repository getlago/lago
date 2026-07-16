# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::ApplyProviderTaxesToStandaloneFeesService do
  subject(:service) { described_class.new(customer:, fees:, currency: "EUR") }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

  let(:fee1) { create(:fee, amount_cents: 1000, precise_amount_cents: 1000, taxes_amount_cents: 0, taxes_precise_amount_cents: 0) }
  let(:fee2) { create(:fee, amount_cents: 500, precise_amount_cents: 500, taxes_amount_cents: 0, taxes_precise_amount_cents: 0) }
  let(:fees) { [fee1, fee2] }

  let(:response) { instance_double(Net::HTTPOK) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }

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
    integration_customer

    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
  end

  describe "#call" do
    context "when provider returns taxes successfully" do
      let(:body) do
        {
          succeededInvoices: [{
            id: "inv_123",
            fees: [
              {item_id: fee1.id, item_code: "code_1", amount_cents: 1000, tax_amount_cents: 100,
               tax_breakdown: [{name: "VAT", rate: "0.10", tax_amount: 100, type: "tax"}]},
              {item_id: fee2.id, item_code: "code_2", amount_cents: 500, tax_amount_cents: 50,
               tax_breakdown: [{name: "VAT", rate: "0.10", tax_amount: 50, type: "tax"}]}
            ]
          }],
          failedInvoices: []
        }.to_json
      end

      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      it "applies provider taxes to each fee" do
        result = service.call

        expect(result).to be_success

        expect(fee1.applied_taxes.count).to eq(1)
        expect(fee1.applied_taxes.first.tax_name).to eq("VAT")
        expect(fee1.taxes_amount_cents).to eq(100)

        expect(fee2.applied_taxes.count).to eq(1)
        expect(fee2.applied_taxes.first.tax_name).to eq("VAT")
        expect(fee2.taxes_amount_cents).to eq(50)
      end
    end

    context "when provider returns a failure" do
      before do
        allow(lago_client).to receive(:post_with_response)
          .and_raise(LagoHttpClient::HttpError.new(500, "error", "http://test"))
      end

      it "returns success without applying taxes" do
        result = service.call

        expect(result).to be_success

        expect(fee1.applied_taxes).to be_empty
        expect(fee1.taxes_amount_cents).to eq(0)

        expect(fee2.applied_taxes).to be_empty
        expect(fee2.taxes_amount_cents).to eq(0)
      end
    end
  end
end
