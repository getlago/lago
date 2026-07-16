# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::FixedChargeUnitsOverrides::WriteService do
  subject(:write_service) do
    described_class.new(
      subscription:,
      fixed_charge:,
      units:,
      apply_units_immediately:,
      timestamp:
    )
  end

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, organization:, units: 5) }
  let(:subscription) { create(:subscription, plan:) }
  let(:units) { 15 }
  let(:apply_units_immediately) { false }
  let(:timestamp) { Time.current.to_i }

  describe "#call" do
    it "creates a Subscription::FixedChargeUnitsOverride for the (subscription, fixed_charge) pair" do
      expect { write_service.call }
        .to change(::Subscription::FixedChargeUnitsOverride, :count).by(1)

      override = ::Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
      expect(override.units).to eq(15)
      expect(override.organization).to eq(subscription.organization)
    end

    it "emits a fixed charge event for the subscription with the override units" do
      expect { write_service.call }.to change(FixedChargeEvent, :count).by(1)

      event = FixedChargeEvent.find_by(subscription:, fixed_charge:)
      expect(event.units).to eq(15)
    end

    it "returns the override on the result" do
      result = write_service.call

      expect(result).to be_success
      expect(result.units_override).to be_a(::Subscription::FixedChargeUnitsOverride)
      expect(result.units_override.units).to eq(15)
    end

    context "when an override already exists for the pair" do
      before do
        create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, organization:, units: 7)
      end

      it "updates the existing override row rather than creating a new one" do
        expect { write_service.call }
          .not_to change(::Subscription::FixedChargeUnitsOverride, :count)

        override = ::Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
        expect(override.units).to eq(15)
      end
    end

    context "when apply_units_immediately is true on a pay-in-advance fixed charge" do
      let(:apply_units_immediately) { true }
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:, units: 5, pay_in_advance: true) }

      it "enqueues the pay-in-advance billing job after commit" do
        expect { write_service.call }
          .to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          .with(subscription, timestamp)
      end
    end

    context "when apply_units_immediately is true on a pay-in-arrears fixed charge" do
      let(:apply_units_immediately) { true }

      it "does not enqueue the pay-in-advance billing job" do
        expect { write_service.call }
          .not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end

    context "when apply_units_immediately is false on a pay-in-advance fixed charge" do
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:, units: 5, pay_in_advance: true) }

      it "does not enqueue the pay-in-advance billing job" do
        expect { write_service.call }
          .not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
      end
    end
  end
end
