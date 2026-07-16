# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::PostProcessService do
  subject(:process_service) { described_class.new(event:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, organization:, customer:, plan:, started_at:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:) }

  let(:started_at) { Time.current - 3.days }
  let(:external_subscription_id) { subscription.external_id }
  let(:code) { billable_metric&.code }
  let(:timestamp) { Time.current - 1.second }
  let(:event_properties) { {} }

  let(:event) do
    create(
      :event,
      organization_id: organization.id,
      external_subscription_id:,
      timestamp:,
      code:,
      properties: event_properties
    )
  end

  before do
    charge
    create(:wallet, customer:)
  end

  describe "#call" do
    it "marks customer as awaiting wallet refresh" do
      expect { process_service.call }.to change { customer.reload.awaiting_wallet_refresh }.from(false).to(true)
    end

    it "tracks subscription activity" do
      allow(UsageMonitoring::TrackSubscriptionActivityService).to receive(:call)

      process_service.call

      expected_date = Time.current.in_time_zone(customer.applicable_timezone).to_date
      expect(UsageMonitoring::TrackSubscriptionActivityService).to have_received(:call)
        .with(subscription:, organization:, date: expected_date)
    end

    context "with events enrichment" do
      it "does not create an enriched event" do
        expect { process_service.call }.not_to change(EnrichedEvent, :count)
      end

      context "when the feature flag is enabled" do
        let(:organization) { create(:organization, feature_flags: [:postgres_enriched_events]) }

        it "creates enriched event" do
          expect { process_service.call }.to change(EnrichedEvent, :count).by(1)
        end
      end
    end

    context "when subscription is incomplete" do
      let(:subscription) do
        create(:subscription, :incomplete, organization:, customer:, plan:, started_at:)
      end

      it "does not enqueue a pay in advance job" do
        expect { process_service.call }.not_to have_enqueued_job(Events::PayInAdvanceJob)
      end

      it "does not track subscription activity" do
        allow(UsageMonitoring::TrackSubscriptionActivityService).to receive(:call)

        process_service.call

        expect(UsageMonitoring::TrackSubscriptionActivityService).not_to have_received(:call)
      end
    end

    context "when event matches an pay_in_advance charge" do
      let(:charge) { create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: false) }
      let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "item_id") }
      let(:event_properties) { {billable_metric.field_name => "12"} }

      before { charge }

      it "enqueues a job to perform the pay_in_advance aggregation" do
        expect { process_service.call }.to have_enqueued_job(Events::PayInAdvanceJob)
      end
    end

    describe "#check_targeted_wallets", :premium do
      let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:) }
      let(:accepts_target_wallet) { false }
      let(:event_properties) { {"target_wallet_code" => target_wallet_code} }
      let(:target_wallet_code) { "my_wallet" }

      before do
        organization.update!(premium_integrations: ["events_targeting_wallets"])
        charge.update!(accepts_target_wallet:)
      end

      context "when events_targeting_wallets feature is not enabled" do
        before do
          organization.update!(premium_integrations: [])
        end

        it "does not send error webhook" do
          expect { process_service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when target_wallet_code is not present in event properties" do
        let(:event_properties) { {} }

        it "does not send error webhook" do
          expect { process_service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when charge does not accept wallet target" do
        let(:accepts_target_wallet) { false }

        it "does not send error webhook" do
          expect { process_service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when charge accepts wallet target" do
        let(:accepts_target_wallet) { true }

        context "when wallet with target code exists" do
          before do
            create(:wallet, customer:, code: target_wallet_code)
          end

          it "does not send error webhook" do
            expect { process_service.call }.not_to have_enqueued_job(SendWebhookJob).with("event.error", anything, anything)
          end
        end

        context "when active wallet with target code does not exist" do
          let(:wallet) { create(:wallet, customer:, code: target_wallet_code, status: :terminated) }

          before { wallet }

          it "sends error webhook with target_wallet_code_not_found" do
            expect { process_service.call }.to have_enqueued_job(SendWebhookJob)
              .with("event.error", event, {error: {target_wallet_code: ["target_wallet_code_not_found"]}})
          end
        end
      end
    end
  end
end
