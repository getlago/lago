# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::EmitFixedChargeEventsService do
  subject(:service) { described_class.new(subscriptions:, timestamp:) }

  let(:timestamp) { Time.current }
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }

  let(:fixed_charge_1) { create(:fixed_charge, plan:, add_on:) }
  let(:fixed_charge_2) { create(:fixed_charge, plan:, add_on:) }

  let(:subscription_1) { create(:subscription, :active, plan:) }
  let(:subscription_2) { create(:subscription, :active, plan:) }
  let(:subscriptions) { [subscription_1, subscription_2] }

  before do
    fixed_charge_1
    fixed_charge_2
  end

  describe "#call" do
    subject(:result) { service.call }

    def emitted_pairs
      FixedChargeEvent.where(timestamp:).pluck(:subscription_id, :fixed_charge_id)
    end

    it "creates an event for each subscription and fixed charge" do
      expect { result }.to change(FixedChargeEvent, :count).by(4)
      expect(result).to be_success

      expect(emitted_pairs).to match_array(
        [
          [subscription_1.id, fixed_charge_1.id],
          [subscription_1.id, fixed_charge_2.id],
          [subscription_2.id, fixed_charge_1.id],
          [subscription_2.id, fixed_charge_2.id]
        ]
      )
    end

    context "when subscriptions have no fixed charges" do
      let(:plan_without_fixed_charges) { create(:plan, organization:) }
      let(:subscription_without_fixed_charges) { create(:subscription, :active, plan: plan_without_fixed_charges) }
      let(:subscriptions) { [subscription_without_fixed_charges] }

      it "does not create any event" do
        expect { result }.not_to change(FixedChargeEvent, :count)
        expect(result).to be_success
      end
    end

    context "when fixed charges already have events emitted on the same date" do
      before do
        create(:fixed_charge_event, subscription: subscription_1, fixed_charge: fixed_charge_1, timestamp:)
      end

      it "skips the already-emitted pair without duplicating it and creates the rest" do
        expect { result }.to change(FixedChargeEvent, :count).by(3)

        expect(emitted_pairs).to match_array(
          [
            [subscription_1.id, fixed_charge_1.id],
            [subscription_1.id, fixed_charge_2.id],
            [subscription_2.id, fixed_charge_1.id],
            [subscription_2.id, fixed_charge_2.id]
          ]
        )
        expect(
          FixedChargeEvent.where(subscription: subscription_1, fixed_charge: fixed_charge_1, timestamp:).count
        ).to eq(1)
      end
    end

    context "when fixed charge events exist on different dates" do
      before do
        create(:fixed_charge_event, subscription: subscription_1, fixed_charge: fixed_charge_1, timestamp: timestamp - 1.day)
      end

      it "still emits the pair whose existing event is on a different date" do
        expect { result }.to change(FixedChargeEvent, :count).by(4)

        expect(emitted_pairs).to match_array(
          [
            [subscription_1.id, fixed_charge_1.id],
            [subscription_1.id, fixed_charge_2.id],
            [subscription_2.id, fixed_charge_1.id],
            [subscription_2.id, fixed_charge_2.id]
          ]
        )
      end
    end

    context "when customer has a timezone" do
      let(:customer) { create(:customer, organization:, timezone: "America/New_York") }
      let(:subscription) { create(:subscription, :active, plan:, customer:) }
      let(:subscriptions) { [subscription] }
      let(:timestamp) { Time.zone.parse("2025-09-05 12:00 UTC") }
      let(:event_time) { Time.zone.parse("2025-09-05 02:00 UTC") } # Same day in NY timezone

      before do
        create(:fixed_charge_event, subscription:, fixed_charge: fixed_charge_1, timestamp: event_time)
      end

      it "skips the same-day pair when checked in the customer timezone" do
        expect { result }.to change(FixedChargeEvent, :count).by(1)
        expect(emitted_pairs).to eq([[subscription.id, fixed_charge_2.id]])
      end
    end

    context "when billing entity has a timezone" do
      let(:billing_entity) { create(:billing_entity, timezone: "America/New_York") }
      let(:customer) { create(:customer, billing_entity:) }
      let(:subscription) { create(:subscription, :active, plan:, customer:) }
      let(:subscriptions) { [subscription] }
      let(:timestamp) { Time.zone.parse("2025-09-05 12:00 UTC") }
      let(:event_time) { Time.zone.parse("2025-09-05 02:00 UTC") } # Same day in NY timezone

      before do
        create(:fixed_charge_event, subscription:, fixed_charge: fixed_charge_1, timestamp: event_time)
      end

      it "skips the same-day pair when checked in the billing entity timezone" do
        expect { result }.to change(FixedChargeEvent, :count).by(1)
        expect(emitted_pairs).to eq([[subscription.id, fixed_charge_2.id]])
      end
    end
  end
end
