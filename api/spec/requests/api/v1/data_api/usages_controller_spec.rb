# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::DataApi::UsagesController do # rubocop:disable Rails/FilePath
  describe "GET /analytics/usage" do
    subject { get_with_token(organization, "/api/v1/analytics/usage", params) }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization) }
    let(:params) { {currency: "EUR"} }

    let(:result) do
      BaseService::Result.new.tap do |result|
        result.usages = [{amount_currency: nil, amount_cents: nil}]
      end
    end

    before do
      allow(DataApi::UsagesService).to receive(:call).and_return(result)
    end

    context "when license is premium", :premium do
      include_examples "requires API permission", "analytic", "read"

      it "returns the usage" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:usages].first[:amount_currency]).to eq(nil)
        expect(json[:usages].first[:amount_cents]).to eq(nil)
        expect(DataApi::UsagesService).to have_received(:call).with(organization, **params)
      end
    end

    context "when license is not premium" do
      include_examples "requires API permission", "analytic", "read"

      it "returns the usage" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:usages].first[:amount_currency]).to eq(nil)
        expect(json[:usages].first[:amount_cents]).to eq(nil)
        expect(DataApi::UsagesService).to have_received(:call).with(organization, **params)
      end
    end
  end
end
