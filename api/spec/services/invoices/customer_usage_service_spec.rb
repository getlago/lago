# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CustomerUsageService, cache: :memory do
  subject(:usage_service) do
    described_class.with_ids(
      organization_id: membership.organization_id,
      customer_id:,
      subscription_id:,
      apply_taxes:
    )
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:customer) { create(:customer, organization:) }
  let(:customer_id) { customer&.id }
  let(:subscription_id) { subscription&.id }
  let(:plan) { create(:plan, organization:, interval: "monthly") }
  let(:timestamp) { Time.current }
  let(:apply_taxes) { true }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      started_at: Time.zone.now - 2.years
    )
  end

  let(:billable_metric) do
    create(:billable_metric, aggregation_type: "count_agg")
  end

  let(:charge) do
    create(
      :standard_charge,
      plan:,
      billable_metric:,
      properties: {amount: "12.66"}
    )
  end

  let(:events) do
    create_list(
      :event,
      2,
      organization:,
      subscription:,
      customer:,
      code: billable_metric.code,
      timestamp:
    )
  end

  describe "#call" do
    before do
      events if subscription
      charge
      Rails.cache.clear

      tax
    end

    it "uses the Rails cache" do
      key = [
        "charge-usage",
        Subscriptions::ChargeCacheService::CACHE_KEY_VERSION,
        charge.id,
        subscription.id,
        charge.updated_at.iso8601
      ].join("/")

      expect do
        usage_service.call
      end.to change { Rails.cache.exist?(key) }.from(false).to(true)
    end

    it "does not query AdjustedFee and skips adjusted fees" do
      allow(AdjustedFee).to receive(:matching_charge_boundaries).and_call_original
      allow(Fees::ChargeService).to receive(:call!).and_call_original
      usage_service.call

      expect(AdjustedFee).not_to have_received(:matching_charge_boundaries)
      expect(Fees::ChargeService).to have_received(:call!)
        .with(hash_including(skip_adjusted_fees: true))
    end

    context "when initializes an invoice" do
      let(:current_date) { DateTime.parse("2025-06-15") }
      let(:timestamp) { current_date }

      it "initializes an invoice" do
        travel_to(current_date) do
          result = usage_service.call

          expect(result).to be_success
          expect(result.invoice).to be_a(Invoice)
          expect(result.invoice.organization).to eq(organization)
          expect(result.invoice.billing_entity).to eq(customer.billing_entity)
          expect(result.invoice.total_paid_amount_cents).to eq(0)
          expect(result.invoice.prepaid_credit_amount_cents).to eq(0)

          expect(result.usage).to have_attributes(
            from_datetime: Time.current.beginning_of_month.iso8601,
            to_datetime: Time.current.end_of_month.iso8601,
            issuing_date: Time.zone.today.end_of_month.iso8601,
            currency: "EUR",
            amount_cents: 2532, # 1266 * 2,
            taxes_amount_cents: 506, # 1266 * 2 * 0.2 = 506.4
            total_amount_cents: 3038
          )
          expect(result.usage.fees.size).to eq(1)
          expect(result.usage.fees.first.charge.invoice_display_name).to eq(charge.invoice_display_name)
        end
      end
    end

    context "when apply_taxes property is set to false" do
      let(:current_date) { DateTime.parse("2025-06-15") }
      let(:timestamp) { current_date }
      let(:apply_taxes) { false }

      it "initializes an invoice" do
        travel_to(current_date) do
          result = usage_service.call

          expect(result).to be_success
          expect(result.invoice).to be_a(Invoice)

          expect(result.usage).to have_attributes(
            from_datetime: Time.current.beginning_of_month.iso8601,
            to_datetime: Time.current.end_of_month.iso8601,
            issuing_date: Time.zone.today.end_of_month.iso8601,
            currency: "EUR",
            amount_cents: 2532, # 1266 * 2,
            taxes_amount_cents: 0,
            total_amount_cents: 2532
          )
          expect(result.usage.fees.size).to eq(1)
          expect(result.usage.fees.first.charge.invoice_display_name).to eq(charge.invoice_display_name)
        end
      end
    end

    context "when there is tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
      let(:endpoint) { "https://api.nango.dev/v1/anrok/draft_invoices" }
      let(:integration_collection_mapping) do
        create(
          :netsuite_collection_mapping,
          integration:,
          mapping_type: :fallback_item,
          settings: {external_id: "1", external_account_code: "11", external_name: ""}
        )
      end

      before do
        integration_collection_mapping
        integration_customer
      end

      context "when there is no error" do
        let(:current_date) { DateTime.parse("2025-06-15") }
        let(:timestamp) { current_date }

        before do
          stub_request(:post, endpoint).to_return do |request|
            response = JSON.parse(File.read(
              Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
            ))

            # setting item_id based on the test example
            key = JSON.parse(request.body).first["fees"].last["item_key"]
            response["succeededInvoices"].first["fees"].last["item_key"] = key
            response["succeededInvoices"].first["fees"].last["item_id"] = charge.billable_metric.id
            response["succeededInvoices"].first["fees"].last["amount_cents"] = 2532

            {body: response.to_json}
          end
        end

        it "initializes an invoice" do
          travel_to(current_date) do
            result = usage_service.call

            expect(result).to be_success
            expect(result.invoice).to be_a(Invoice)

            expect(result.usage).to have_attributes(
              from_datetime: Time.current.beginning_of_month.iso8601,
              to_datetime: Time.current.end_of_month.iso8601,
              issuing_date: Time.zone.today.end_of_month.iso8601,
              currency: "EUR",
              amount_cents: 2532, # 1266 * 2,
              taxes_amount_cents: 253, # 2532 * 0.1
              total_amount_cents: 2785
            )
            expect(result.usage.fees.size).to eq(1)
            expect(result.usage.fees.first.charge.invoice_display_name).to eq(charge.invoice_display_name)
          end
        end
      end

      context "when a charge produces a zero fee" do
        let(:current_date) { DateTime.parse("2025-06-15") }
        let(:timestamp) { current_date }
        let(:empty_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
        let(:empty_charge) { create(:standard_charge, plan:, billable_metric: empty_metric, properties: {amount: "5"}) }
        # Free usage: has events and units but a zero amount, so it is non_zero? but not taxable?
        let(:free_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }
        let(:free_charge) { create(:standard_charge, plan:, billable_metric: free_metric, properties: {amount: "0"}) }

        before do
          empty_charge
          free_charge
          create_list(:event, 2, organization:, subscription:, customer:, code: free_metric.code, timestamp:)
          allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to receive(:call).and_call_original

          stub_request(:post, endpoint).to_return do |request|
            response = JSON.parse(File.read(
              Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
            ))

            key = JSON.parse(request.body).first["fees"].last["item_key"]
            response["succeededInvoices"].first["fees"].last["item_key"] = key
            response["succeededInvoices"].first["fees"].last["item_id"] = charge.billable_metric.id
            response["succeededInvoices"].first["fees"].last["amount_cents"] = 2532

            {body: response.to_json}
          end
        end

        it "keeps the non-taxable fees in the usage but excludes them from the tax provider payload" do
          travel_to(current_date) do
            result = usage_service.call

            expect(result).to be_success
            # both zero-amount fees (empty + free usage) stay in the usage response
            expect(result.usage.fees.map(&:amount_cents)).to match_array([0, 0, 2532])
            # only the taxable (positive-amount) fee is sent to the provider
            expect(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to have_received(:call) do |invoice:, fees:|
              expect(fees.map(&:amount_cents)).to match_array([2532])
            end
          end
        end

        it "leaves the excluded non-taxable fees with default zero taxes" do
          travel_to(current_date) do
            result = usage_service.call

            non_taxable_fees = result.usage.fees.reject(&:taxable?)
            expect(non_taxable_fees.size).to eq(2)
            non_taxable_fees.each do |fee|
              expect(fee.taxes_amount_cents).to eq(0)
              expect(fee.taxes_rate).to eq(0)
              expect(fee.applied_taxes).to be_empty
            end
          end
        end

        it "computes the invoice taxes_rate without diluting it by the excluded fees" do
          travel_to(current_date) do
            result = usage_service.call

            # The rate is prorated by amount over the taxable fee only (10%), not by fee
            # count over all three fees, which would dilute it to 1/3 * 10 = 3.33%.
            expect(result.invoice.taxes_rate).to eq(10)
            expect(result.usage.taxes_amount_cents).to eq(253)
          end
        end
      end

      context "when there are no taxable fees" do
        # The single charge produces a zero-amount fee, so taxable_fees is empty.
        let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "0"}) }

        before do
          allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to receive(:call)
        end

        it "skips the provider request and returns a zero-tax usage" do
          result = usage_service.call

          expect(result).to be_success
          expect(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).not_to have_received(:call)
          expect(result.usage).to have_attributes(
            amount_cents: 0,
            taxes_amount_cents: 0,
            total_amount_cents: 0
          )
        end

        it "leaves the zero fee with default zero taxes" do
          result = usage_service.call

          fee = result.usage.fees.sole
          expect(fee.taxes_amount_cents).to eq(0)
          expect(fee.taxes_rate).to eq(0)
          expect(fee.applied_taxes).to be_empty
        end
      end

      context "when there is error received from the provider" do
        before do
          stub_request(:post, endpoint).to_return do |request|
            response = File.read(
              Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
            )
            {body: response}
          end
        end

        it "returns tax error" do
          result = usage_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:tax_error]).to eq(["taxDateTooFarInFuture: Service failure"])
        end
      end
    end

    context "with subscription started in current billing period" do
      before { subscription.update!(started_at: Time.zone.today) }

      it "changes the from date of the invoice" do
        result = usage_service.call

        expect(result).to be_success
        expect(result.usage.from_datetime).to eq(subscription.started_at.iso8601)
      end
    end

    context "when subscription is billed on anniversary date" do
      let(:current_date) { DateTime.parse("2022-06-22") }
      let(:started_at) { DateTime.parse("2022-03-07") }
      let(:subscription_at) { started_at }
      let(:timestamp) { current_date }

      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          subscription_at:,
          started_at:,
          billing_time: :anniversary
        )
      end

      it "initializes an invoice" do
        travel_to(current_date) do
          result = usage_service.call

          expect(result).to be_success
          expect(result.invoice).to be_a(Invoice)

          expect(result.usage).to have_attributes(
            issuing_date: "2022-07-06",
            currency: "EUR",
            amount_cents: 2532, # 1266 * 2,
            taxes_amount_cents: 506, # 1266 * 2 * 0.2 = 506.4
            total_amount_cents: 3038
          )

          expect(result.usage.from_datetime.to_date.to_s).to eq("2022-06-07")
          expect(result.usage.to_datetime.to_date.to_s).to eq("2022-07-06")
          expect(result.usage.fees.size).to eq(1)
        end
      end
    end

    context "when customer is not found" do
      let(:customer_id) { "foo" }

      it "returns an error" do
        result = usage_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("customer_not_found")
      end
    end

    context "when no_active_subscription" do
      let(:subscription) { nil }

      it "fails" do
        result = usage_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("no_active_subscription")
      end
    end

    context "with filter_by_charge_id" do
      subject(:usage_service) do
        described_class.new(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_charge_id: charge.id)
        )
      end

      let(:billable_metric_2) { create(:billable_metric, aggregation_type: "count_agg") }

      let(:charge_2) do
        create(:standard_charge, plan:, billable_metric: billable_metric_2, properties: {amount: "5"})
      end

      let(:events_2) do
        create_list(:event, 3, organization:, subscription:, customer:, code: billable_metric_2.code, timestamp:)
      end

      before do
        events_2
        charge_2
      end

      it "returns fees only for the specified charge" do
        result = usage_service.call

        expect(result).to be_success
        expect(result.usage.fees.map(&:charge_id).uniq).to eq([charge.id])
      end
    end

    context "with filter_by_charge_code" do
      subject(:usage_service) do
        described_class.new(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_charge_code: charge.code)
        )
      end

      let(:billable_metric_2) { create(:billable_metric, aggregation_type: "count_agg") }

      let(:charge_2) do
        create(:standard_charge, plan:, billable_metric: billable_metric_2, properties: {amount: "5"})
      end

      let(:events_2) do
        create_list(:event, 3, organization:, subscription:, customer:, code: billable_metric_2.code, timestamp:)
      end

      before do
        events_2
        charge_2
      end

      it "returns fees only for the specified charge" do
        result = usage_service.call

        expect(result).to be_success
        expect(result.usage.fees.map(&:charge_id).uniq).to eq([charge.id])
      end
    end

    context "with filter_by_group" do
      subject(:usage_service) do
        described_class.new(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(filter_by_group: {"cloud" => ["aws"]})
        )
      end

      let(:billable_metric) do
        create(:billable_metric, aggregation_type: "sum_agg", field_name: "value")
      end

      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          properties: {amount: "10", pricing_group_keys: %w[cloud]}
        )
      end

      let(:events) { [] }

      before do
        create(:event, organization:, subscription:, customer:, code: billable_metric.code,
          timestamp:, properties: {cloud: "aws", value: 10})
        create(:event, organization:, subscription:, customer:, code: billable_metric.code,
          timestamp:, properties: {cloud: "gcp", value: 5})
      end

      it "returns fees filtered by the group" do
        result = usage_service.call

        expect(result).to be_success
        expect(result.usage.fees.size).to eq(1)
        expect(result.usage.fees.first.units).to eq(10)
      end
    end

    context "with full_usage" do
      let(:billable_metric) do
        create(:billable_metric, aggregation_type: "count_agg")
      end

      let(:charge) do
        create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
      end

      let(:events) { [] }

      context "when organization does not have lifetime_usage enabled", :premium do
        subject(:usage_service) do
          described_class.new(
            customer:,
            subscription:,
            apply_taxes: false,
            with_cache: false,
            usage_filters: UsageFilters.new(filter_by_charge_id: charge.id, full_usage: true)
          )
        end

        it "returns a not_allowed failure" do
          result = usage_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("full_usage_not_allowed")
        end
      end

      context "when granular_lifetime_usage is enabled", :premium do
        before do
          organization.update!(premium_integrations: %w[granular_lifetime_usage])
        end

        context "when filter_by_charge_id is provided and no prorated charges" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: false,
              usage_filters: UsageFilters.new(filter_by_charge_id: charge.id, full_usage: true)
            )
          end

          before do
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "returns usage successfully" do
            result = usage_service.call

            expect(result).to be_success
            expect(result.usage.fees.size).to eq(1)
          end
        end

        context "when filter_by_charge_code is provided and no prorated charges" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: false,
              usage_filters: UsageFilters.new(filter_by_charge_code: charge.code, full_usage: true)
            )
          end

          before do
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "returns usage successfully" do
            result = usage_service.call

            expect(result).to be_success
            expect(result.usage.fees.size).to eq(1)
          end
        end

        context "when no filter is provided" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: false,
              usage_filters: UsageFilters.new(full_usage: true)
            )
          end

          before do
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "returns a not_allowed failure" do
            result = usage_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
            expect(result.error.code).to eq("full_usage_not_allowed")
          end
        end

        context "when a different charge is prorated but filtered charge is not" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: false,
              usage_filters: UsageFilters.new(filter_by_charge_id: charge.id, full_usage: true)
            )
          end

          let(:prorated_metric) { create(:billable_metric, :recurring, organization:, aggregation_type: "sum_agg", field_name: "value") }
          let(:prorated_charge) do
            create(:standard_charge, plan:, billable_metric: prorated_metric, prorated: true, properties: {amount: "5"})
          end

          before do
            prorated_charge
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "returns usage successfully" do
            result = usage_service.call

            expect(result).to be_success
            expect(result.usage.fees.size).to eq(1)
          end
        end

        context "when the filtered charge itself is prorated" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: false,
              usage_filters: UsageFilters.new(filter_by_charge_id: prorated_charge.id, full_usage: true)
            )
          end

          let(:prorated_metric) { create(:billable_metric, :recurring, organization:, aggregation_type: "sum_agg", field_name: "value") }
          let(:prorated_charge) do
            create(:standard_charge, plan:, billable_metric: prorated_metric, prorated: true, properties: {amount: "5"})
          end

          before do
            prorated_charge
            create_list(:event, 2, organization:, subscription:, customer:, code: prorated_metric.code, timestamp:)
          end

          it "returns a not_allowed failure" do
            result = usage_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
            expect(result.error.code).to eq("full_usage_not_allowed")
          end
        end

        context "when subscription started at current period boundary" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: true,
              usage_filters: UsageFilters.new(filter_by_charge_id: charge.id, full_usage: true)
            )
          end

          let(:current_date) { DateTime.parse("2025-06-15") }
          let(:timestamp) { current_date }

          let(:subscription) do
            create(:subscription, plan:, customer:, started_at: DateTime.parse("2025-06-01"))
          end

          before do
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "uses the Rails cache" do
            key = [
              "charge-usage",
              Subscriptions::ChargeCacheService::CACHE_KEY_VERSION,
              charge.id,
              subscription.id,
              charge.updated_at.iso8601
            ].join("/")

            travel_to(current_date) do
              expect { usage_service.call }.to change { Rails.cache.exist?(key) }.from(false).to(true)
            end
          end
        end

        context "when subscription started before current period" do
          subject(:usage_service) do
            described_class.new(
              customer:,
              subscription:,
              apply_taxes: false,
              with_cache: true,
              usage_filters: UsageFilters.new(filter_by_charge_id: charge.id, full_usage: true)
            )
          end

          let(:current_date) { DateTime.parse("2025-06-15") }
          let(:timestamp) { current_date }

          let(:subscription) do
            create(:subscription, plan:, customer:, started_at: DateTime.parse("2025-03-01"))
          end

          before do
            create_list(:event, 2, organization:, subscription:, customer:, code: billable_metric.code, timestamp:)
          end

          it "does not use the Rails cache" do
            key = [
              "charge-usage",
              Subscriptions::ChargeCacheService::CACHE_KEY_VERSION,
              charge.id,
              subscription.id,
              charge.updated_at.iso8601
            ].join("/")

            travel_to(current_date) do
              expect { usage_service.call }.not_to change { Rails.cache.exist?(key) }
            end
          end
        end
      end
    end

    context "with skip_grouping" do
      subject(:usage_service) do
        described_class.new(
          customer:,
          subscription:,
          apply_taxes: false,
          with_cache: false,
          usage_filters: UsageFilters.new(skip_grouping: true)
        )
      end

      let(:billable_metric) do
        create(:billable_metric, aggregation_type: "sum_agg", field_name: "value")
      end

      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          properties: {amount: "10", pricing_group_keys: %w[cloud]}
        )
      end

      let(:events) { [] }

      before do
        create(:event, organization:, subscription:, customer:, code: billable_metric.code,
          timestamp:, properties: {cloud: "aws", value: 10})
        create(:event, organization:, subscription:, customer:, code: billable_metric.code,
          timestamp:, properties: {cloud: "gcp", value: 5})
      end

      it "returns a single fee with all events aggregated without grouping" do
        result = usage_service.call

        expect(result).to be_success
        expect(result.usage.fees.size).to eq(1)
        expect(result.usage.fees.first.units).to eq(15)
        expect(result.usage.fees.first.grouped_by).to eq({})
      end
    end
  end
end
