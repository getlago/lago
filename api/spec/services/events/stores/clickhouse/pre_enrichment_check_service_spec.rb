# frozen_string_literal: true

require "spec_helper"

RSpec.describe Events::Stores::Clickhouse::PreEnrichmentCheckService do
  subject(:service) do
    described_class.new(organization:, reprocess:, batch_size: 1000, sleep_seconds: 0)
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:reprocess) { false }

  let(:plan) { create(:plan, organization:) }
  let(:started_at) { Time.zone.parse("2024-12-01") }
  let(:subscription) do
    create(:subscription, organization:, customer:, plan:, started_at:)
  end

  before { subscription }

  describe "#call" do
    context "when organization has no matching charges" do
      it "returns empty subscriptions_to_reprocess" do
        result = service.call

        expect(result).to be_success
        expect(result.subscriptions_to_reprocess).to eq({})
      end
    end

    context "with recurring BM subscriptions" do
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:, code: "recurring_metric") }

      before { create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at - 1.month) }

      context "when subscription started before cutoff and has active subscription with same external_id" do
        let(:started_at) { Time.zone.parse("2025-11-01") }

        it "includes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({subscription.id => ["recurring_metric"]})
        end
      end

      context "when subscription started after cutoff" do
        let(:started_at) { Time.zone.parse("2025-12-01") }

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end

      context "when subscription external_id has no active subscription" do
        let(:subscription) do
          create(:subscription, :terminated, organization:, customer:, plan:, started_at:)
        end

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end
    end

    context "with pricing_group_keys subscriptions" do
      let(:billable_metric) { create(:billable_metric, organization:, code: "grouped_metric") }

      before do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          organization:,
          properties: {amount: "100", pricing_group_keys: ["region"]},
          created_at: started_at - 1.month
        )
      end

      context "when active subscription started before cutoff" do
        let(:started_at) { Time.zone.parse("2026-03-01") }

        it "includes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({subscription.id => ["grouped_metric"]})
        end
      end

      context "when subscription is terminated" do
        let(:subscription) do
          create(:subscription, :terminated, organization:, customer:, plan:, started_at:)
        end

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end

      context "when subscription started after cutoff" do
        let(:started_at) { Time.zone.parse("2026-03-10") }

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end

      context "when pricing_group_keys is on charge_filter but not on charge" do
        let(:started_at) { Time.zone.parse("2026-03-01") }
        let(:billable_metric) { create(:billable_metric, organization:, code: "filter_grouped_metric") }

        let(:charge) do
          create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at - 1.month)
        end

        before do
          create(:charge_filter, charge:, properties: {amount: "50", pricing_group_keys: ["zone"]}, created_at: started_at - 1.day)
        end

        it "includes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({subscription.id => ["filter_grouped_metric"]})
        end
      end
    end

    context "with new_charge_or_filters subscriptions" do
      let(:billable_metric) { create(:billable_metric, organization:, code: "new_charge_metric") }
      let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at + 1.month) }

      before { charge }

      context "when charge was created after subscription started" do
        it "includes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({subscription.id => ["new_charge_metric"]})
        end
      end

      context "when charge was created before subscription started" do
        let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at - 1.month) }

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end

      context "when subscription is terminated" do
        let(:subscription) do
          create(:subscription, :terminated, organization:, customer:, plan:, started_at:)
        end

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end

      context "when charge_filter was created after subscription started" do
        let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at - 1.month) }

        before do
          create(:charge_filter, charge:, created_at: started_at + 1.day)
        end

        it "includes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({subscription.id => ["new_charge_metric"]})
        end
      end

      context "when charge_filter was created before subscription started" do
        let(:charge) { create(:standard_charge, plan:, billable_metric:, organization:, created_at: started_at - 1.month) }

        before do
          create(:charge_filter, charge:, created_at: started_at - 1.day)
        end

        it "excludes the subscription" do
          result = service.call

          expect(result).to be_success
          expect(result.subscriptions_to_reprocess).to eq({})
        end
      end
    end

    context "when subscription matches multiple criteria" do
      let(:recurring_metric) { create(:sum_billable_metric, :recurring, organization:, code: "recurring_metric") }
      let(:grouped_metric) { create(:billable_metric, organization:, code: "grouped_metric") }
      let(:shared_metric) { create(:sum_billable_metric, :recurring, organization:, code: "shared_metric") }

      before do
        create(:standard_charge, plan:, billable_metric: recurring_metric, organization:)

        create(
          :standard_charge,
          plan:,
          billable_metric: grouped_metric,
          organization:,
          properties: {amount: "100", pricing_group_keys: ["region"]}
        )

        create(
          :standard_charge,
          plan:,
          billable_metric: shared_metric,
          organization:,
          properties: {amount: "100", pricing_group_keys: ["zone"]}
        )
      end

      it "merges BM codes without duplicates" do
        result = service.call

        expect(result).to be_success
        codes = result.subscriptions_to_reprocess[subscription.id]
        expect(codes).to match_array(["recurring_metric", "shared_metric", "grouped_metric"])
      end
    end

    context "when reprocess is true" do
      let(:reprocess) { true }
      let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:, code: "recurring_metric") }
      let(:started_at) { Time.zone.parse("2025-11-01") }

      before do
        create(:standard_charge, plan:, billable_metric:, organization:)
      end

      it "enqueues PreEnrichmentCheckJob for each subscription" do
        service.call

        expect(Events::Stores::Clickhouse::PreEnrichmentCheckJob).to have_been_enqueued
          .with(subscription_id: subscription.id, codes: ["recurring_metric"], batch_size: 1000, sleep_seconds: 0)
      end
    end
  end
end
