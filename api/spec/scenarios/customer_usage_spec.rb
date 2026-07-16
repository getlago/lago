# frozen_string_literal: true

require "rails_helper"

describe "Customer usage Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }

  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:, currency: "EUR") }

  let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: false, interval: "yearly") }

  context "with start date in the past" do
    it "retrieve the customer usage" do
      travel_to(DateTime.new(2023, 8, 8, 9, 30)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            subscription_at: DateTime.new(2023, 1, 1, 9, 30).iso8601
          }
        )

        subscription = customer.subscriptions.first
        fetch_current_usage(customer:, subscription:)

        expect(json[:customer_usage][:from_datetime]).to eq("2023-01-01T09:30:00Z")
        expect(json[:customer_usage][:to_datetime]).to eq("2023-12-31T23:59:59Z")
      end
    end

    context "with Europe/Berlin timezone" do
      let(:timezone) { "Europe/Berlin" }

      it "retrieve the customer usage" do
        travel_to(DateTime.new(2023, 8, 8, 9, 30)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              subscription_at: DateTime.new(2023, 1, 1, 9, 30).iso8601
            }
          )

          subscription = customer.subscriptions.first
          fetch_current_usage(customer:, subscription:)

          expect(json[:customer_usage][:from_datetime]).to eq("2023-01-01T09:30:00Z")
          expect(json[:customer_usage][:to_datetime]).to eq("2023-12-31T22:59:59Z")
        end
      end
    end

    context "with America/Los_Angeles timezone" do
      let(:timezone) { "America/Los_Angeles" }

      it "retrieve the customer usage" do
        travel_to(DateTime.new(2023, 8, 8, 9, 30)) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              subscription_at: DateTime.new(2023, 1, 1, 9, 30).iso8601
            }
          )

          subscription = customer.subscriptions.first
          fetch_current_usage(customer:, subscription:)

          expect(json[:customer_usage][:from_datetime]).to eq("2023-01-01T09:30:00Z")
          expect(json[:customer_usage][:to_datetime]).to eq("2024-01-01T07:59:59Z")
        end
      end
    end
  end

  context "with filter_by_charge and filter_by_group filtering" do
    let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }

    let(:billable_metric_1) { create(:sum_billable_metric, organization:, field_name: "units") }
    let(:billable_metric_2) { create(:sum_billable_metric, organization:, field_name: "units") }

    let(:charge_1) do
      create(
        :standard_charge,
        plan:,
        billable_metric: billable_metric_1,
        properties: {amount: "10", pricing_group_keys: ["user"]}
      )
    end
    let(:charge_2) do
      create(
        :standard_charge,
        plan:,
        billable_metric: billable_metric_2,
        properties: {amount: "5", pricing_group_keys: ["user"]}
      )
    end

    let(:subscription) do
      sub = nil
      travel_to(DateTime.new(2024, 3, 1, 10, 0)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary"
          }
        )
        sub = customer.subscriptions.first
      end
      sub
    end

    before do
      charge_1
      charge_2
      subscription
      travel_to(DateTime.new(2024, 3, 5, 10, 0)) do
        # Send 10 events for charge_1's metric with user 0..9
        10.times do |i|
          create_event(
            {
              code: billable_metric_1.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {user: i.to_s, units: 5}
            }
          )
        end

        # Send 10 events for charge_2's metric with user 0..9
        10.times do |i|
          create_event(
            {
              code: billable_metric_2.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {user: i.to_s, units: 3}
            }
          )
        end
      end
    end

    it "with filter_by_group returns one fee per charge filtered to that group" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_group: {user: ["0"]})
        )

        expect(result).to be_success

        fees = result.usage.fees
        expect(fees.size).to eq(2)

        fee_1 = fees.find { |f| f.charge_id == charge_1.id }
        expect(fee_1.units).to eq(5)
        expect(fee_1.events_count).to eq(1)
        expect(fee_1.amount_cents).to eq(5_000) # 5 units * 10 amount * 100 cents

        fee_2 = fees.find { |f| f.charge_id == charge_2.id }
        expect(fee_2.units).to eq(3)
        expect(fee_2.events_count).to eq(1)
        expect(fee_2.amount_cents).to eq(1_500) # 3 units * 5 amount * 100 cents
      end
    end

    it "with filter_by_charge returns all grouped usage for that charge" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_charge_id: charge_1.id)
        )

        expect(result).to be_success

        fees = result.usage.fees
        # 10 groups (user 0..9), all for charge_1
        expect(fees.size).to eq(10)
        expect(fees.map(&:charge_id).uniq).to eq([charge_1.id])

        fees.each do |fee|
          expect(fee.units).to eq(5)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(5_000)
        end

        expect(fees.map { |f| f.grouped_by["user"] }).to match_array(
          (0..9).map(&:to_s)
        )
      end
    end
  end

  context "with multi-level pricing_group_keys filtering by workspace" do
    let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false, interval: "monthly") }
    let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "units") }

    let(:charge) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        properties: {amount: "10", pricing_group_keys: %w[workspace user]}
      )
    end

    let(:subscription) do
      sub = nil
      travel_to(DateTime.new(2024, 3, 1, 10, 0)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary"
          }
        )
        sub = customer.subscriptions.first
      end
      sub
    end

    before do
      charge
      subscription
      travel_to(DateTime.new(2024, 3, 5, 10, 0)) do
        # Send 10 events for different users across two workspaces
        # workspace_a: users 0..4, workspace_b: users 5..9
        10.times do |i|
          workspace = (i < 5) ? "workspace_a" : "workspace_b"
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {workspace:, user: i.to_s, units: 3}
            }
          )
        end
      end
    end

    it "filtering by workspace still returns fees divided by user" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_group: {workspace: ["workspace_a"]})
        )

        expect(result).to be_success

        fees = result.usage.fees
        # 5 users in workspace_a, each with their own fee grouped by user
        expect(fees.size).to eq(5)

        fees.each do |fee|
          expect(fee.charge_id).to eq(charge.id)
          expect(fee.units).to eq(3)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(3_000) # 3 units * 10 amount * 100 cents
        end

        expect(fees.map { |f| f.grouped_by["user"] }).to match_array(
          (0..4).map(&:to_s)
        )
      end
    end

    it "filtering by the other workspace returns only its users" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_group: {workspace: ["workspace_b"]})
        )

        expect(result).to be_success

        fees = result.usage.fees
        expect(fees.size).to eq(5)

        fees.each do |fee|
          expect(fee.charge_id).to eq(charge.id)
          expect(fee.units).to eq(3)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(3_000)
        end

        expect(fees.map { |f| f.grouped_by["user"] }).to match_array(
          (5..9).map(&:to_s)
        )
      end
    end

    it "without filter returns fees grouped by both workspace and user" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false
        )

        expect(result).to be_success

        fees = result.usage.fees
        # 10 unique workspace+user combinations
        expect(fees.size).to eq(10)

        fees.each do |fee|
          expect(fee.charge_id).to eq(charge.id)
          expect(fee.units).to eq(3)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(3_000)
          expect(fee.grouped_by.keys).to match_array(%w[workspace user])
        end
      end
    end

    it "with skip_grouping returns a single aggregated fee" do
      travel_to(DateTime.new(2024, 3, 10, 10, 0)) do
        result = Invoices::CustomerUsageService.call(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(skip_grouping: true)
        )

        expect(result).to be_success

        fees = result.usage.fees
        # All 10 events aggregated into a single fee
        expect(fees.size).to eq(1)
        expect(fees.first.charge_id).to eq(charge.id)
        expect(fees.first.units).to eq(30) # 10 events * 3 units each
        expect(fees.first.events_count).to eq(10)
        expect(fees.first.amount_cents).to eq(30_000) # 30 units * 10 amount * 100 cents
        expect(fees.first.grouped_by).to eq({})
      end
    end
  end
end
