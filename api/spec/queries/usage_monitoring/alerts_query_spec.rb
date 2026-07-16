# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::AlertsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:subscription) { create(:subscription, organization:) }
  let(:alert_first) { create(:alert, organization:, subscription_external_id: subscription.external_id) }
  let(:alert_second) { create(:billable_metric_current_usage_amount_alert, organization:, subscription_external_id: subscription.external_id) }
  let(:alert_third) { create(:alert, organization:) }
  let(:pagination) { {page: 1, limit: 5} }
  let(:filters) { nil }

  before do
    alert_first
    alert_second
    alert_third
  end

  it "returns all alerts" do
    expect(result.alerts.pluck(:id)).to contain_exactly(alert_first.id, alert_second.id, alert_third.id)
  end

  context "with subscription_external_id" do
    let(:filters) { {subscription_external_id: subscription.external_id} }

    it do
      expect(result.alerts.pluck(:id)).to contain_exactly(alert_first.id, alert_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.alerts.count).to eq(1)
      expect(result.alerts.current_page).to eq(2)
      expect(result.alerts.prev_page).to eq(1)
      expect(result.alerts.next_page).to be_nil
      expect(result.alerts.total_pages).to eq(2)
      expect(result.alerts.total_count).to eq(3)
    end
  end
end
