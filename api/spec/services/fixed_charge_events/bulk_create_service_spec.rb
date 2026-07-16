# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedChargeEvents::BulkCreateService do
  subject(:service) { described_class.new(events_attributes:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
  let(:subscription) { create(:subscription, :active, plan:) }
  let(:timestamp) { Time.current }

  let(:events_attributes) do
    [
      {
        organization_id: organization.id,
        subscription_id: subscription.id,
        fixed_charge_id: fixed_charge.id,
        units: 5,
        timestamp:
      }
    ]
  end

  describe "#call" do
    subject(:result) { service.call }

    it "bulk-inserts the fixed charge events" do
      expect { result }.to change(FixedChargeEvent, :count).by(1)
    end

    it "returns the persisted events" do
      event = result.fixed_charge_events.first

      expect(result.fixed_charge_events.size).to eq(1)
      expect(event).to be_persisted
      expect(event.organization_id).to eq(organization.id)
      expect(event.subscription_id).to eq(subscription.id)
      expect(event.fixed_charge_id).to eq(fixed_charge.id)
      expect(event.units).to eq(5)
      expect(event.timestamp).to be_within(1.second).of(timestamp)
    end

    it "is successful" do
      expect(result).to be_success
    end

    context "when given multiple rows" do
      let(:other_subscription) { create(:subscription, :active, plan:) }

      let(:events_attributes) do
        [
          {organization_id: organization.id, subscription_id: subscription.id, fixed_charge_id: fixed_charge.id, units: 1, timestamp:},
          {organization_id: organization.id, subscription_id: other_subscription.id, fixed_charge_id: fixed_charge.id, units: 2, timestamp:}
        ]
      end

      it "inserts all rows in a single batch" do
        expect { result }.to change(FixedChargeEvent, :count).by(2)
        expect(result.fixed_charge_events.map(&:subscription_id))
          .to match_array([subscription.id, other_subscription.id])
      end
    end

    context "when the number of rows exceeds the insert batch size" do
      before { stub_const("FixedChargeEvents::BulkCreateService::BATCH_SIZE", 1) }

      let(:other_subscription) { create(:subscription, :active, plan:) }

      let(:events_attributes) do
        [
          {organization_id: organization.id, subscription_id: subscription.id, fixed_charge_id: fixed_charge.id, units: 1, timestamp:},
          {organization_id: organization.id, subscription_id: other_subscription.id, fixed_charge_id: fixed_charge.id, units: 2, timestamp:}
        ]
      end

      it "inserts in multiple batches and returns every persisted event" do
        allow(FixedChargeEvent).to receive(:insert_all!).and_call_original

        expect { result }.to change(FixedChargeEvent, :count).by(2)
        expect(FixedChargeEvent).to have_received(:insert_all!).twice
        expect(result.fixed_charge_events.map(&:subscription_id))
          .to match_array([subscription.id, other_subscription.id])
      end
    end

    context "when events_attributes is empty" do
      let(:events_attributes) { [] }

      it "does not create any event and returns an empty collection" do
        expect { result }.not_to change(FixedChargeEvent, :count)
        expect(result).to be_success
        expect(result.fixed_charge_events).to eq([])
      end
    end

    context "when a row has negative units" do
      let(:events_attributes) do
        [{organization_id: organization.id, subscription_id: subscription.id, fixed_charge_id: fixed_charge.id, units: -1, timestamp:}]
      end

      it "fails with a validation error and persists nothing" do
        expect { result }.not_to change(FixedChargeEvent, :count)
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:units]).to eq(["value_is_out_of_range"])
      end
    end
  end
end
