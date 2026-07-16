# frozen_string_literal: true

require "spec_helper"

RSpec.describe Events::Stores::Clickhouse::PreEnrichmentCheckJob, type: :job do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:) }
  let(:codes) { ["metric_code"] }
  let(:batch_size) { 1000 }
  let(:sleep_seconds) { 0 }

  let(:re_enrich_result) { BaseResult.new }

  before do
    allow(Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService).to receive(:call!)
      .and_return(re_enrich_result)
  end

  describe "#perform" do
    it "calls ReEnrichSubscriptionEventsService" do
      described_class.perform_now(subscription_id: subscription.id, codes:, batch_size:, sleep_seconds:)

      expect(Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService).to have_received(:call!).with(
        subscription:, codes:, reprocess: true, batch_size:, sleep_seconds:
      )
    end
  end
end
