# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::LifetimeUsagesController do
  let!(:lifetime_usage) { create(:lifetime_usage, organization:, subscription:) }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, plan:, organization:, subscription_at:, customer:) }
  let(:subscription_at) { Date.new(2022, 8, 22) }
  let(:plan) { create(:plan) }

  before { create(:usage_threshold, plan:, amount_cents: 100) }

  describe "GET /api/v1/subscriptions/:subscription_external_id/lifetime_usage" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id}/lifetime_usage") }

    let(:external_id) { subscription.external_id }

    include_examples "requires API permission", "lifetime_usage", "read"

    it "returns the lifetime_usage" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:lifetime_usage][:lago_id]).to eq(lifetime_usage.id)
    end

    it "includes the usage_thresholds" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:lifetime_usage][:lago_id]).to eq(lifetime_usage.id)
      expect(json[:lifetime_usage][:usage_thresholds]).to eq([
        {amount_cents: 100, completion_ratio: 0.0, reached_at: nil}
      ])
    end

    context "when subscription cannot be found" do
      let(:external_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/subscriptions/:subscription_external_id/lifetime_usage" do
    subject do
      put_with_token(
        organization,
        "/api/v1/subscriptions/#{external_id}/lifetime_usage",
        {lifetime_usage: update_params}
      )
    end

    let(:external_id) { subscription.external_id }
    let(:update_params) { {external_historical_usage_amount_cents: 20} }

    context "when subscription exists" do
      include_examples "requires API permission", "lifetime_usage", "write"

      it "updates the lifetime_usage" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:lifetime_usage][:lago_id]).to eq(lifetime_usage.id)
        expect(json[:lifetime_usage][:external_historical_usage_amount_cents]).to eq(20)
      end
    end

    context "when subscription does not exist" do
      let(:external_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
