# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Common do
  subject(:event) do
    described_class.new(
      id: nil,
      organization_id: organization.id,
      transaction_id: SecureRandom.uuid,
      external_subscription_id: subscription.external_id,
      timestamp:,
      code: billable_metric.code,
      properties: {}
    )
  end

  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization: organization) }
  let(:timestamp) { Time.current - 1.second }

  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:, started_at:) }

  let(:started_at) { Time.current - 3.days }
  let(:external_subscription_id) { subscription.external_id }

  describe "#persisted?" do
    it { expect(event.persisted).to be_truthy }

    context "when persisted value is passed to the event" do
      subject(:event) do
        described_class.new(
          id: nil,
          organization_id: organization.id,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: subscription.external_id,
          timestamp:,
          code: billable_metric.code,
          properties: {},
          persisted: false
        )
      end

      it "sets the value to the instance" do
        expect(event.persisted).to be_falsey
      end
    end
  end

  describe "#event_id" do
    it "returns the transaction_id" do
      expect(event.event_id).to eq(event.transaction_id)
    end

    context "when id is set" do
      before { event.id = "event-id" }

      it "returns the id" do
        expect(event.event_id).to eq("event-id")
      end
    end
  end

  describe "#organization" do
    it "returns the organization" do
      expect(event.organization).to eq(organization)
    end
  end

  describe "#billable_metric" do
    it "returns the billable_metric" do
      expect(event.billable_metric).to eq(billable_metric)
    end
  end

  describe "#subscription" do
    it "returns the subscription" do
      expect(event.subscription).to eq(subscription)
    end

    context "when subscription is terminated" do
      let(:subscription) { create(:subscription, :terminated, organization:, customer:, started_at:) }

      it "returns the subscription" do
        expect(event.subscription).to eq(subscription)
      end

      context "when subscription is terminated just after the ingestion" do
        before do
          subscription.update!(terminated_at: timestamp + 0.2.seconds)
        end

        it "returns the subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end

      context "when a new active subscription exists" do
        let(:started_at) { 1.month.ago }
        let(:timestamp) { 1.week.ago }

        let(:active_subscription) do
          create(
            :subscription,
            customer:,
            organization:,
            started_at: 1.day.ago,
            external_id: subscription.external_id
          )
        end

        before { active_subscription }

        it "returns the active subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end

      context "when subscription is an upgrade/downgrade" do
        let(:started_at) { 1.week.ago }

        let(:terminated_subscription) do
          create(
            :subscription,
            :terminated,
            organization:,
            customer:,
            external_id: external_subscription_id,
            started_at: 1.month.ago,
            terminated_at: timestamp - 1.day
          )
        end

        before { terminated_subscription }

        it "returns the subscription" do
          expect(event.subscription).to eq(subscription)
        end
      end
    end
  end

  describe "#as_json" do
    it "returns the event as json" do
      expect(event.as_json).to include(
        "organization_id" => organization.id,
        "transaction_id" => event.transaction_id,
        "external_subscription_id" => subscription.external_id,
        "code" => billable_metric.code,
        "properties" => {},
        "timestamp" => timestamp.to_f,
        "timestamp_with_precision" => timestamp.iso8601(9)
      )
    end
  end

  describe ".timestamp_from_source" do
    let(:timestamp) { Time.zone.parse("2026-05-22 10:04:50.227587000 +0000") }
    let(:source) { event.as_json }

    it "preserves timestamp precision from the serialized event" do
      expect(described_class.timestamp_from_source(source)).to eq(timestamp)
    end

    context "when the precise timestamp is not present" do
      before { source.delete("timestamp_with_precision") }

      it "falls back to the float timestamp" do
        expect(described_class.timestamp_from_source(source)).to eq(Time.zone.at(source["timestamp"].to_f))
      end
    end

    context "when the precise timestamp cannot be parsed" do
      before { source["timestamp_with_precision"] = "invalid" }

      it "falls back to the float timestamp" do
        expect(described_class.timestamp_from_source(source)).to eq(Time.zone.at(source["timestamp"].to_f))
      end
    end
  end
end
