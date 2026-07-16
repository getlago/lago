# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::BillingPeriodFilterService do
  subject(:filter_service) { described_class.new(subscription:, boundaries:) }

  shared_examples "recurring billable metric filtering" do
    let(:recurring_billable_metric) { create(:sum_billable_metric, :recurring, organization:) }
    let(:recurring_charge) { create(:standard_charge, plan:, billable_metric: recurring_billable_metric) }

    let(:charge_filter) { create(:charge_filter, charge: recurring_charge) }
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric: recurring_billable_metric, key: "region", values: ["eu", "us"]) }

    let(:charge_filter_value) do
      create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
    end

    before do
      recurring_charge
      charge_filter_value
    end

    context "when it is the first billing period" do
      let(:started_at) { boundaries.charges_from_datetime }

      it "returns empty hash" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end
    end

    context "when previous fees exist" do
      let(:fee) { create(:charge_fee, subscription:, charge: recurring_charge, charge_filter:, units: 2.4) }

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice: fee.invoice,
          subscription:,
          organization:,
          charges_from_datetime: boundaries.charges_from_datetime - 1.month
        )
      end

      before { invoice_subscription }

      it "returns only charge/filter pairs from previous fees" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({recurring_charge.id => [charge_filter.id]})
      end
    end

    context "when no previous fees exist" do
      let(:invoice) { create(:invoice, organization:) }
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice:,
          subscription:,
          organization:,
          charges_from_datetime: boundaries.charges_from_datetime - 1.month
        )
      end

      before { invoice_subscription }

      it "returns empty hash" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end
    end

    context "when previous fees exist and have no units" do
      let(:invoice) { create(:invoice, organization:) }
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice:,
          subscription:,
          organization:,
          charges_from_datetime: boundaries.charges_from_datetime - 1.month
        )
      end

      let(:fee) { create(:charge_fee, subscription:, charge: recurring_charge, charge_filter:, units: 0, invoice:) }

      before { invoice_subscription }

      it "returns empty hash" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end
    end

    context "when subscription has previous_subscription_id" do
      let(:old_plan) { create(:plan, organization:) }
      let(:previous_subscription) do
        create(:subscription, :terminated, organization:, customer:, plan: old_plan, external_id: "sub_id", started_at: started_at - 1.month)
      end
      let(:subscription) do
        create(
          :subscription,
          organization:,
          customer:,
          plan:,
          started_at:,
          subscription_at: started_at,
          external_id: "sub_id",
          previous_subscription: previous_subscription
        )
      end

      context "when no filters on either side" do
        let(:charge_filter) { nil }
        let(:charge_filter_value) { nil }
        let(:recurring_charge) { create(:standard_charge, plan:, billable_metric: recurring_billable_metric) }
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter_id: nil,
            created_at: started_at - 1.day,
            units: 2.4
          )
        end

        it "returns current charge with nil filter" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({recurring_charge.id => [nil]})
        end
      end

      context "when old has filters but current does not" do
        let(:charge_filter) { nil }
        let(:charge_filter_value) { nil }
        let(:recurring_charge) { create(:standard_charge, plan:, billable_metric: recurring_billable_metric) }
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }
        let(:old_filter) { create(:charge_filter, charge: old_charge) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter: old_filter,
            created_at: started_at - 1.day,
            units: 2.4
          )
        end

        it "returns current charge with nil filter" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({recurring_charge.id => [nil]})
        end
      end

      context "when old has filters with no units and current does not" do
        let(:charge_filter) { nil }
        let(:charge_filter_value) { nil }
        let(:recurring_charge) { create(:standard_charge, plan:, billable_metric: recurring_billable_metric) }
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }
        let(:old_filter) { create(:charge_filter, charge: old_charge) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter: old_filter,
            created_at: started_at - 1.day,
            units: 0
          )
        end

        it "returns empty hash" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "when old has no filters but current has filters" do
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter_id: nil,
            created_at: started_at - 1.day,
            units: 2.4
          )
        end

        it "returns all current filter IDs plus nil" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to match({recurring_charge.id => contain_exactly(charge_filter.id, nil)})
        end
      end

      context "when both have filters" do
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }
        let(:old_filter) { create(:charge_filter, charge: old_charge) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter: old_filter,
            created_at: started_at - 1.day,
            units: 2.4
          )
        end

        it "returns all current filter IDs plus nil" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to match({recurring_charge.id => contain_exactly(charge_filter.id, nil)})
        end
      end

      context "when traversing a chain of subscriptions" do
        let(:oldest_plan) { create(:plan, organization:) }
        let(:oldest_subscription) do
          create(:subscription, :terminated, organization:, customer:, plan: oldest_plan, external_id: "sub_id", started_at: started_at - 2.months)
        end
        let(:previous_subscription) do
          create(:subscription, :terminated, organization:, customer:, plan: old_plan, external_id: "sub_id", started_at: started_at - 1.month, previous_subscription: oldest_subscription)
        end
        let(:oldest_charge) { create(:standard_charge, plan: oldest_plan, billable_metric: recurring_billable_metric) }

        let(:fee) do
          create(
            :charge_fee,
            subscription: oldest_subscription,
            charge: oldest_charge,
            charge_filter_id: nil,
            created_at: started_at - 2.months + 1.day,
            units: 2.4
          )
        end

        before { fee }

        it "picks up fees from the entire chain" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to match({recurring_charge.id => contain_exactly(charge_filter.id, nil)})
        end

        context "when previous fees have no units" do
          let(:fee) do
            create(
              :charge_fee,
              subscription: oldest_subscription,
              charge: oldest_charge,
              charge_filter_id: nil,
              created_at: started_at - 2.months + 1.day,
              units: 0
            )
          end

          it "returns empty hash" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({})
          end
        end
      end

      context "when no previous fees exist for recurring BMs" do
        it "returns empty hash" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "when previous fees include both nil and non-nil charge_filter_id" do
        let(:old_charge) { create(:standard_charge, plan: old_plan, billable_metric: recurring_billable_metric) }
        let(:old_filter) { create(:charge_filter, charge: old_charge) }

        before do
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter: old_filter,
            created_at: started_at - 1.day,
            units: 2.4
          )
          create(
            :charge_fee,
            subscription: previous_subscription,
            charge: old_charge,
            charge_filter_id: nil,
            created_at: started_at - 1.day,
            units: 2.4
          )
        end

        it "returns all current filter IDs plus nil" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to match({recurring_charge.id => contain_exactly(charge_filter.id, nil)})
        end
      end
    end

    context "when previous fee has a discarded charge_filter" do
      let(:fee) { create(:charge_fee, subscription:, charge: recurring_charge, charge_filter:) }

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice: fee.invoice,
          subscription:,
          organization:,
          charges_from_datetime: boundaries.charges_from_datetime - 1.month
        )
      end

      before do
        invoice_subscription
        charge_filter.discard!
      end

      it "excludes the discarded filter from results" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end
    end
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:subscription) do
    create(
      :subscription,
      organization:,
      customer:,
      plan:,
      started_at:,
      subscription_at: started_at,
      external_id: "sub_id"
    )
  end

  let(:started_at) { Time.zone.parse("2022-01-01 00:01") }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:charge_filter) { nil }
  let(:charge_filter_value) { nil }

  let(:boundaries) do
    BillingPeriodBoundaries.new(
      from_datetime: Time.zone.parse("2022-03-01 00:00:00"),
      to_datetime: Time.zone.parse("2022-03-31 23:59:59"),
      charges_from_datetime: Time.zone.parse("2022-03-01 00:00:00"),
      charges_to_datetime: Time.zone.parse("2022-03-31 23:59:59"),
      charges_duration: 31.days,
      timestamp: Time.zone.parse("2022-04-02 00:00").end_of_month.to_i
    )
  end

  before { charge }

  describe "#call" do
    context "when relying on event codes" do
      it "returns the filtered charge_ids" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end

      context "with events matching the boundaries" do
        before do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            timestamp: boundaries.charges_from_datetime + 5.days,
            code: billable_metric.code,
            properties: {"region" => charge_filter_value&.values&.first}
          )

          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            timestamp: boundaries.charges_from_datetime + 5.days,
            code: billable_metric.code,
            properties: {"region" => charge_filter_value&.values&.last}
          )
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({charge.id => [nil]})
        end

        context "with multiple charges for the same billable_metric" do
          let(:charge_2) { create(:standard_charge, plan:, billable_metric:) }

          before { charge_2 }

          it "returns filtered charges" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with multiple billable metrics" do
          let(:billable_metric_2) { create(:billable_metric, organization:) }
          let(:charge_2) { create(:standard_charge, plan:, billable_metric: billable_metric_2) }

          before do
            charge_2

            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              timestamp: boundaries.charges_from_datetime + 10.days,
              code: billable_metric_2.code,
              properties: {"region" => charge_filter_value&.values&.first}
            )
          end

          it "returns charges and filters for all billable metrics with matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with charge filters" do
          let(:charge_filter) { create(:charge_filter, charge:) }
          let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: ["eu", "us"]) }

          let(:charge_filter_value) do
            create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
          end

          let(:charge_filter2) { create(:charge_filter, charge:) }

          before { charge_filter2 }

          it "returns the filters that the events can match" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to match({charge.id => contain_exactly(charge_filter.id, charge_filter2.id)})
          end
        end

        context "when events only match a subset of the charge filters" do
          let(:charge_filter) { create(:charge_filter, charge:) }
          let(:billable_metric_filter) do
            create(:billable_metric_filter, billable_metric:, key: "region", values: %w[eu us])
          end
          let(:charge_filter_value) do
            create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
          end

          let(:charge_filter_us) { create(:charge_filter, charge:) }
          let(:charge_filter_us_value) do
            create(:charge_filter_value, charge_filter: charge_filter_us, billable_metric_filter:, values: ["us"])
          end

          before { charge_filter_us_value }

          it "returns only the filters that received matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [charge_filter.id]})
          end
        end

        context "when an event matches no charge filter" do
          let(:charge_filter) { create(:charge_filter, charge:) }
          let(:billable_metric_filter) do
            create(:billable_metric_filter, billable_metric:, key: "region", values: %w[eu us])
          end
          let(:charge_filter_value) do
            create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
          end

          before do
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              timestamp: boundaries.charges_from_datetime + 6.days,
              code: billable_metric.code,
              properties: {"region" => "us"}
            )
          end

          it "returns the default filter for the unmatched usage" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to match({charge.id => contain_exactly(charge_filter.id, nil)})
          end
        end
      end

      context "with recurring billable metric" do
        let(:recurring_billable_metric) { create(:sum_billable_metric, :recurring, organization:) }
        let(:recurring_charge) { create(:standard_charge, plan:, billable_metric: recurring_billable_metric) }

        let(:charge_filter) { create(:charge_filter, charge: recurring_charge) }
        let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric: recurring_billable_metric, key: "region", values: ["eu", "us"]) }

        let(:charge_filter_value) do
          create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
        end

        before do
          recurring_charge
          charge_filter_value
        end

        it "returns recurring charge_ids even without events" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({recurring_charge.id => [charge_filter.id, nil]})
        end
      end

      context "with events that does not match the boundaries" do
        before do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            timestamp: boundaries.charges_from_datetime - 5.days,
            code: billable_metric.code
          )
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "with unknown event codes" do
        before do
          create(
            :event,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            timestamp: boundaries.charges_from_datetime + 5.days,
            code: "unknown_code"
          )
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      it "scopes the event store query to the plan billable metric codes" do
        event_store = instance_double(Events::Stores::PostgresStore, distinct_codes_and_property_combinations: [])
        allow(Events::Stores::StoreFactory).to receive(:new_instance).and_return(event_store)

        filter_service.call

        expect(event_store).to have_received(:distinct_codes_and_property_combinations)
          .with(codes: [billable_metric.code], filter_keys: [])
      end
    end

    context "when relying on clickhouse enriched events", clickhouse: true do
      let(:organization) do
        create(:organization, clickhouse_events_store: true, pre_filter_events: true)
      end

      it "returns filtered charges" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end

      context "with events matching the boundaries" do
        let(:events) do
          Clickhouse::EventsEnrichedExpanded.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            subscription_id: subscription.id,
            plan_id: plan.id,
            code: billable_metric.code,
            aggregation_type: billable_metric.aggregation_type,
            charge_id: charge.id,
            charge_version: charge.updated_at,
            charge_filter_id: charge_filter&.id,
            charge_filter_version: charge_filter&.updated_at,
            timestamp: boundaries.charges_from_datetime + 5.days,
            properties: {"region" => charge_filter_value&.values&.first},
            value: "12",
            decimal_value: 12.0,
            precise_total_amount_cents: nil
          )

          Clickhouse::EventsEnrichedExpanded.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            subscription_id: subscription.id,
            plan_id: plan.id,
            code: billable_metric.code,
            aggregation_type: billable_metric.aggregation_type,
            charge_id: charge.id,
            charge_version: charge.updated_at,
            charge_filter_id: charge_filter&.id,
            charge_filter_version: charge_filter&.updated_at,
            timestamp: boundaries.charges_from_datetime + 5.days,
            properties: {"region" => charge_filter_value&.values&.last},
            value: "12",
            decimal_value: 12.0,
            precise_total_amount_cents: nil
          )
        end

        before { events }

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({charge.id => [nil]})
        end

        context "with multiple charges for the same billable_metric" do
          let(:charge_2) { create(:standard_charge, plan:, billable_metric:) }

          let(:events) do
            Clickhouse::EventsEnrichedExpanded.create!(
              transaction_id: SecureRandom.uuid,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              subscription_id: subscription.id,
              plan_id: plan.id,
              code: billable_metric.code,
              aggregation_type: billable_metric.aggregation_type,
              charge_id: charge.id,
              charge_version: charge.updated_at,
              charge_filter_id: charge_filter&.id,
              charge_filter_version: charge_filter&.updated_at,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.first},
              value: "12",
              decimal_value: 12.0,
              precise_total_amount_cents: nil
            )

            Clickhouse::EventsEnrichedExpanded.create!(
              transaction_id: SecureRandom.uuid,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              subscription_id: subscription.id,
              plan_id: plan.id,
              code: billable_metric.code,
              aggregation_type: billable_metric.aggregation_type,
              charge_id: charge_2.id,
              charge_version: charge_2.updated_at,
              charge_filter_id: charge_filter&.id,
              charge_filter_version: charge_filter&.updated_at,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.last},
              value: "12",
              decimal_value: 12.0,
              precise_total_amount_cents: nil
            )
          end

          it "returns filtered charges" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with multiple billable metrics" do
          let(:billable_metric_2) { create(:billable_metric, organization:) }
          let(:charge_2) { create(:standard_charge, plan:, billable_metric: billable_metric_2) }

          before do
            charge_2

            Clickhouse::EventsEnrichedExpanded.create!(
              transaction_id: SecureRandom.uuid,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              subscription_id: subscription.id,
              plan_id: plan.id,
              code: billable_metric.code,
              aggregation_type: billable_metric.aggregation_type,
              charge_id: charge_2.id,
              charge_version: charge_2.updated_at,
              charge_filter_id: charge_filter&.id,
              charge_filter_version: charge_filter&.updated_at,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.last},
              value: "12",
              decimal_value: 12.0,
              precise_total_amount_cents: nil
            )
          end

          it "returns charges and filters for all billable metrics with matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with charge filters" do
          let(:charge_filter) { create(:charge_filter, charge:) }
          let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: ["eu", "us"]) }

          let(:charge_filter_value) do
            create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
          end

          let(:charge_filter2) { create(:charge_filter, charge:) }

          before { charge_filter2 }

          it "returns charges and filters for all billable metrics with matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to match({charge.id => contain_exactly(charge_filter.id)})
          end

          context "when events matches the default bucket" do
            let(:events) do
              Clickhouse::EventsEnrichedExpanded.create!(
                transaction_id: SecureRandom.uuid,
                organization_id: organization.id,
                external_subscription_id: subscription.external_id,
                subscription_id: subscription.id,
                plan_id: plan.id,
                code: billable_metric.code,
                aggregation_type: billable_metric.aggregation_type,
                charge_id: charge.id,
                charge_version: charge.updated_at,
                timestamp: boundaries.charges_from_datetime + 5.days,
                properties: {"region" => charge_filter_value&.values&.first},
                value: "12",
                decimal_value: 12.0,
                precise_total_amount_cents: nil
              )

              Clickhouse::EventsEnrichedExpanded.create!(
                transaction_id: SecureRandom.uuid,
                organization_id: organization.id,
                external_subscription_id: subscription.external_id,
                subscription_id: subscription.id,
                plan_id: plan.id,
                code: billable_metric.code,
                aggregation_type: billable_metric.aggregation_type,
                charge_id: charge.id,
                charge_version: charge.updated_at,
                timestamp: boundaries.charges_from_datetime + 5.days,
                properties: {"region" => charge_filter_value&.values&.last},
                value: "12",
                decimal_value: 12.0,
                precise_total_amount_cents: nil
              )
            end

            before { charge_filter }

            it "returns charges and filters for all billable metrics with matching events" do
              result = filter_service.call

              expect(result).to be_success
              expect(result.charges).to match({charge.id => [nil]})
            end
          end
        end
      end

      context "with recurring billable metric" do
        it_behaves_like "recurring billable metric filtering"
      end

      context "with unknown charges" do
        before do
          Clickhouse::EventsEnrichedExpanded.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            subscription_id: subscription.id,
            plan_id: plan.id,
            code: billable_metric.code,
            aggregation_type: billable_metric.aggregation_type,
            charge_id: SecureRandom.uuid,
            charge_version: boundaries.charges_from_datetime - 3.days,
            charge_filter_id: charge_filter&.id,
            charge_filter_version: charge_filter&.updated_at,
            timestamp: boundaries.charges_from_datetime + 5.days,
            properties: {"region" => charge_filter_value&.values&.last},
            value: "12",
            decimal_value: 12.0,
            precise_total_amount_cents: nil
          )
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "with events that does not match the boundaries" do
        before do
          Clickhouse::EventsEnrichedExpanded.create!(
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            subscription_id: subscription.id,
            plan_id: plan.id,
            code: billable_metric.code,
            aggregation_type: billable_metric.aggregation_type,
            charge_id: charge.id,
            charge_version: charge.updated_at,
            timestamp: boundaries.charges_from_datetime - 5.days,
            properties: {"region" => charge_filter_value&.values&.first},
            value: "12",
            decimal_value: 12.0,
            precise_total_amount_cents: nil
          )
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end
    end

    context "when relying on Postgres enriched events" do
      let(:organization) do
        create(:organization, pre_filter_events: true)
      end

      it "returns filtered charges" do
        result = filter_service.call

        expect(result).to be_success
        expect(result.charges).to eq({})
      end

      context "with events matching the boundaries" do
        let(:events) do
          [
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.first}
            ),
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.last}
            )
          ]
        end

        let(:enriched_events) do
          events.map do |event|
            create(
              :enriched_event,
              event:,
              subscription:,
              value: 12,
              decimal_value: 12.0,
              charge:,
              charge_filter_id: charge_filter&.id
            )
          end
        end

        before { enriched_events }

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({charge.id => [nil]})
        end

        context "with multiple charges for the same billable_metric" do
          let(:charge_2) { create(:standard_charge, plan:, billable_metric:) }

          let(:enriched_events) do
            [
              create(
                :enriched_event,
                event: events.first,
                subscription:,
                value: 12,
                decimal_value: 12.0,
                charge:
              ),
              create(
                :enriched_event,
                event: events.last,
                subscription:,
                value: 12,
                decimal_value: 12.0,
                charge: charge_2
              )
            ]
          end

          it "returns filtered charges" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with multiple billable metrics" do
          let(:billable_metric_2) { create(:billable_metric, organization:) }
          let(:charge_2) { create(:standard_charge, plan:, billable_metric: billable_metric_2) }

          let(:events) do
            [
              create(
                :event,
                organization_id: organization.id,
                external_subscription_id: subscription.external_id,
                code: billable_metric.code,
                timestamp: boundaries.charges_from_datetime + 5.days,
                properties: {"region" => charge_filter_value&.values&.first}
              ),
              create(
                :event,
                organization_id: organization.id,
                external_subscription_id: subscription.external_id,
                code: billable_metric_2.code,
                timestamp: boundaries.charges_from_datetime + 5.days,
                properties: {"region" => charge_filter_value&.values&.last}
              )
            ]
          end

          let(:enriched_events) do
            [
              create(
                :enriched_event,
                event: events.first,
                subscription:,
                value: 12,
                decimal_value: 12.0,
                charge:
              ),
              create(
                :enriched_event,
                event: events.last,
                subscription:,
                value: 12,
                decimal_value: 12.0,
                charge: charge_2
              )
            ]
          end

          it "returns charges and filters for all billable metrics with matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to eq({charge.id => [nil], charge_2.id => [nil]})
          end
        end

        context "with charge filters" do
          let(:charge_filter) { create(:charge_filter, charge:) }
          let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, key: "region", values: ["eu", "us"]) }

          let(:charge_filter_value) do
            create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["eu"])
          end

          let(:charge_filter2) { create(:charge_filter, charge:) }

          before { charge_filter2 }

          it "returns charges and filters for all billable metrics with matching events" do
            result = filter_service.call

            expect(result).to be_success
            expect(result.charges).to match({charge.id => contain_exactly(charge_filter.id)})
          end

          context "when events matches the default bucket" do
            let(:enriched_events) do
              [
                create(
                  :enriched_event,
                  event: events.first,
                  subscription:,
                  value: 12,
                  decimal_value: 12.0,
                  charge:
                ),
                create(
                  :enriched_event,
                  event: events.last,
                  subscription:,
                  value: 12,
                  decimal_value: 12.0,
                  charge:
                )
              ]
            end

            before { charge_filter }

            it "returns charges and filters for all billable metrics with matching events" do
              result = filter_service.call

              expect(result).to be_success
              expect(result.charges).to match({charge.id => [nil]})
            end
          end
        end
      end

      context "with recurring billable metric" do
        it_behaves_like "recurring billable metric filtering"
      end

      context "with unknown charges" do
        let(:events) do
          [
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: boundaries.charges_from_datetime + 5.days,
              properties: {"region" => charge_filter_value&.values&.first}
            )
          ]
        end

        let(:enriched_events) do
          events.map do |event|
            create(
              :enriched_event,
              event:,
              subscription:,
              value: 12,
              decimal_value: 12.0,
              charge: create(:standard_charge)
            )
          end
        end

        before do
          enriched_events
        end

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "with events that does not match the boundaries" do
        let(:events) do
          [
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              timestamp: boundaries.charges_from_datetime - 5.days,
              properties: {"region" => charge_filter_value&.values&.first}
            )
          ]
        end

        let(:enriched_events) do
          events.map do |event|
            create(
              :enriched_event,
              event:,
              subscription:,
              value: 12,
              decimal_value: 12.0,
              charge:
            )
          end
        end

        before { enriched_events }

        it "returns filtered charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      context "with enriched events not matching the plan billable metric codes" do
        let(:events) do
          [
            create(
              :event,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id,
              code: "unknown_code",
              timestamp: boundaries.charges_from_datetime + 5.days
            )
          ]
        end

        let(:enriched_events) do
          events.map do |event|
            create(
              :enriched_event,
              event:,
              subscription:,
              value: 12,
              decimal_value: 12.0,
              charge:
            )
          end
        end

        before { enriched_events }

        it "returns empty charges" do
          result = filter_service.call

          expect(result).to be_success
          expect(result.charges).to eq({})
        end
      end

      it "scopes the event store query to the plan billable metric codes" do
        event_store = instance_double(Events::Stores::PostgresStore, distinct_charges_and_filters: [])
        allow(Events::Stores::StoreFactory).to receive(:new_instance).and_return(event_store)

        filter_service.call

        expect(event_store).to have_received(:distinct_charges_and_filters).with(codes: [billable_metric.code])
      end
    end
  end
end
