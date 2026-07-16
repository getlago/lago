# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::Usages::InvoicedService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages_invoiced.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/invoiced/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  describe "#call" do
    subject(:service_call) { service.call }

    context "when licence is not premium" do
      it "returns an error" do
        expect(service_call).not_to be_success
        expect(service_call.error.code).to eq("feature_unavailable")
      end
    end

    context "when licence is premium", :premium do
      it "returns expected invoiced usage" do
        expect(service_call).to be_success
        expect(service_call.invoiced_usages.count).to eq(4)
        expect(service_call.invoiced_usages.first).to eq(
          {
            "organization_id" => "2537afc4-0e7c-4abb-89b7-d9b28c35780b",
            "start_of_period_dt" => "2024-01-01",
            "end_of_period_dt" => "2024-01-31",
            "billable_metric_code" => "account_members",
            "amount_currency" => "EUR",
            "amount_cents" => 26600
          }
        )
      end
    end
  end
end
