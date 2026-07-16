# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::ComputeJob do
  subject(:compute_job) { described_class }

  let(:subscription) { create(:subscription) }
  let(:timestamp) { Time.current }

  let(:result) { BaseService::Result.new }

  describe ".perform" do
    it "delegates to DailyUsages::ComputeService" do
      allow(DailyUsages::ComputeService).to receive(:call)
        .with(subscription:, timestamp:)
        .and_return(result)

      compute_job.perform_now(subscription, timestamp:)

      expect(DailyUsages::ComputeService).to have_received(:call)
        .with(subscription:, timestamp:).once
    end
  end

  describe "#lock_key_arguments" do
    let(:customer) { create(:customer, timezone: "Europe/Paris") }
    let(:subscription) { create(:subscription, customer:) }

    it "returns subscription id and date in customer timezone" do
      timestamp = Time.zone.parse("2024-01-15 10:00:00 UTC")
      job = described_class.new(subscription, timestamp:)

      # 10:00 UTC = 11:00 Europe/Paris -> 2024-01-15
      expect(job.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 15)])
    end

    context "when timestamps fall on the same day in customer timezone" do
      it "returns the same lock key" do
        # 23:00 UTC = 00:00+01:00 (Jan 16 in Paris)
        job1 = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-15 23:00:00 UTC"))
        # 00:00 UTC Jan 16 = 01:00+01:00 (Jan 16 in Paris)
        job2 = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-16 00:00:00 UTC"))

        expect(job1.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 16)])
        expect(job2.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 16)])
      end
    end

    context "when timestamps fall on different days in customer timezone" do
      it "returns different lock keys" do
        # 00:00 UTC = 01:00+01:00 (Jan 15 in Paris)
        job1 = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-15 00:00:00 UTC"))
        # 23:00 UTC = 00:00+01:00 (Jan 16 in Paris)
        job2 = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-15 23:00:00 UTC"))

        expect(job1.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 15)])
        expect(job2.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 16)])
      end
    end

    context "when subscriptions are different" do
      it "returns different lock keys" do
        timestamp = Time.zone.parse("2024-01-15 10:00:00 UTC")
        other_subscription = create(:subscription, customer:)

        job1 = described_class.new(subscription, timestamp:)
        job2 = described_class.new(other_subscription, timestamp:)

        expect(job1.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 15)])
        expect(job2.lock_key_arguments).to eq([other_subscription.id, Date.new(2024, 1, 15)])
      end
    end

    context "when customer has no timezone but billing entity has one" do
      let(:billing_entity) { create(:billing_entity, timezone: "America/New_York") }
      let(:customer) { create(:customer, timezone: nil, billing_entity:) }

      it "falls back to billing entity timezone" do
        # 03:00 UTC = 22:00-05:00 (Jan 14 in New York)
        job = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-15 03:00:00 UTC"))

        expect(job.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 14)])
      end
    end

    context "when customer has no timezone and billing entity uses default UTC" do
      let(:billing_entity) { create(:billing_entity, timezone: "UTC") }
      let(:customer) { create(:customer, timezone: nil, billing_entity:) }

      it "falls back to UTC" do
        # 23:00 UTC stays Jan 15 in UTC
        job = described_class.new(subscription, timestamp: Time.zone.parse("2024-01-15 23:00:00 UTC"))

        expect(job.lock_key_arguments).to eq([subscription.id, Date.new(2024, 1, 15)])
      end
    end
  end
end
