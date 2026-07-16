# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivateAllPendingService, clickhouse: true do
  subject(:activate_service) { described_class.new(timestamp: timestamp.to_i) }

  let(:timestamp) { Time.current }

  describe ".call" do
    it "activates all pending subscriptions with subscription date set to today" do
      create(:subscription)
      create_list(:subscription, 2, :pending, subscription_at: timestamp)
      create(:subscription, :pending, subscription_at: timestamp, plan: create(:plan, pay_in_advance: true))
      create_list(:subscription, 2, :pending, subscription_at: (timestamp + 10.days))

      expect { activate_service.call }
        .to change(Subscription.pending, :count).by(-3)
        .and change(Subscription.active, :count).by(3)
        .and have_enqueued_job(SendWebhookJob).exactly(3).times
        .and have_enqueued_job(BillSubscriptionJob).once
      expect(Utils::ActivityLog).to have_received(:produce)
        .with(an_instance_of(Subscription), "subscription.started").exactly(3).times
    end

    context "when plan is pay in advance has fixed charges" do
      let(:plan) { create(:plan, pay_in_advance: true) }
      let(:fixed_charge_1) { create(:fixed_charge, plan:) }
      let(:subscription) { create(:subscription, :pending, subscription_at: timestamp, plan:) }

      before do
        fixed_charge_1
        subscription
      end

      it "creates fixed charge events for the new subscription" do
        expect { activate_service.call }.to change(FixedChargeEvent, :count).by(1)
        expect(subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp)).to match_array(
          [
            [fixed_charge_1.id, be_within(5.seconds).of(Time.current)]
          ]
        )
      end

      it "schedules BillSubscriptionJob" do
        expect { activate_service.call }.to have_enqueued_job(BillSubscriptionJob)
      end

      context "when fixed charge is pay in advance" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:, pay_in_advance: true) }

        it "does not schedule Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { activate_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end

      context "when fixed charge is not pay in advance" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:, pay_in_advance: false) }

        it "does not schedule Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { activate_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "when plan is not pay in advance has fixed charges" do
      let(:plan) { create(:plan) }
      let(:fixed_charge_1) { create(:fixed_charge, plan:) }
      let(:subscription) { create(:subscription, :pending, subscription_at: timestamp, plan:) }

      before do
        fixed_charge_1
        subscription
      end

      it "creates fixed charge events for the new subscription" do
        expect { activate_service.call }.to change(FixedChargeEvent, :count).by(1)
        expect(subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp)).to match_array(
          [
            [fixed_charge_1.id, be_within(5.seconds).of(Time.current)]
          ]
        )
      end

      it "does not schedule BillSubscriptionJob" do
        expect { activate_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
      end

      context "when fixed charge is pay in advance" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:, pay_in_advance: true) }

        it "schedules Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { activate_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end

      context "when fixed charge is not pay in advance" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:, pay_in_advance: false) }

        it "does not schedule Invoices::CreatePayInAdvanceFixedChargesJob" do
          expect { activate_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "with customer timezone" do
      let(:timestamp) { DateTime.parse("2023-08-24 00:07:00") }
      let(:customer) { create(:customer, :with_hubspot_integration, timezone: "America/Bogota") }
      let!(:pending_subscription) do
        create(
          :subscription,
          :pending,
          customer:,
          subscription_at: timestamp
        )
      end

      it "enqueues Integrations::Aggregator::Subscriptions::Hubspot::CreateJob" do
        activate_service.call
        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
          .to have_been_enqueued.with(subscription: pending_subscription)
      end

      it "takes timezone into account" do
        activate_service.call
        expect(pending_subscription.reload).to be_active
      end
    end

    context "with a subscription in trial" do
      let(:plan_with_trial) { create(:plan, pay_in_advance: true, trial_period: 10) }

      before do
        create(:subscription, :pending, subscription_at: timestamp, plan: create(:plan, pay_in_advance: true))
        create(
          :subscription,
          :pending,
          subscription_at: timestamp,
          plan: plan_with_trial
        )
        create(:fixed_charge, plan: plan_with_trial, pay_in_advance: true)
      end

      it do
        expect { activate_service.call }
          .to change(Subscription.pending, :count).by(-2)
          .and change(Subscription.active, :count).by(2)
          .and have_enqueued_job(SendWebhookJob).exactly(2).times
          .and have_enqueued_job(BillSubscriptionJob).once
      end

      it "enqueues CreatePayInAdvanceFixedChargesJob for pay-in-advance fixed charges even during trial" do
        expect { activate_service.call }
          .to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob).once
      end
    end
  end
end
