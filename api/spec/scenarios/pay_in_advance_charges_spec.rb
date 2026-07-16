# frozen_string_literal: true

require "rails_helper"

describe "Pay in advance charges Scenarios", transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  let(:plan) { create(:plan, organization:, amount_cents: 1000) }
  let(:aggregation_type) { "count_agg" }
  let(:field_name) { nil }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type:, field_name:) }

  describe "with count_agg / standard" do
    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :standard_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {amount: "10"}
      )

      subscription = customer.subscriptions.first

      ### 15 February: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      # NOTE: This does not seem to matter
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days)

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1000)
        expect(fee.amount_details).to eq({})
      end

      ### 17 february: Send an other event.
      feb17 = DateTime.new(2023, 2, 17)

      travel_to(feb17) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1000)
      end
    end
  end

  describe "with count_agg / graduated when events are ingested in the same second" do
    it "assigns each event its own marginal amount" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :graduated_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 2, per_unit_amount: "0", flat_amount: "0"},
            {from_value: 3, to_value: nil, per_unit_amount: "2", flat_amount: "0"}
          ]
        }
      )

      subscription = customer.subscriptions.first

      ### 15 february: Ingest 3 events sharing the same timestamp.
      # All events are persisted before any fee is calculated, so each fee must
      # be priced at its own position in the graduated ranges (0, 0, 2), not all
      # of them as the last unit of the batch.
      feb15 = DateTime.new(2023, 2, 15)

      travel_to(feb15) do
        expect do
          api_call do
            post_with_token(
              organization,
              "/api/v1/events/batch",
              {
                events: Array.new(3) do
                  {
                    code: billable_metric.code,
                    transaction_id: SecureRandom.uuid,
                    external_subscription_id: subscription.external_id,
                    timestamp: feb15.to_i
                  }
                end
              }
            )
          end
        end.to change { subscription.reload.fees.count }.from(0).to(3)

        fees = subscription.fees.where(charge:)
        expect(fees.map(&:pay_in_advance_event_transaction_id).uniq.count).to eq(3)
        expect(fees.map(&:units)).to all(eq(1))
        expect(fees.map(&:amount_cents).sort).to eq([0, 0, 200])
      end
    end
  end

  describe "with unique_count_agg / standard" do
    let(:aggregation_type) { "unique_count_agg" }
    let(:field_name) { "unique_id" }

    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :standard_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {amount: "12"}
      )

      subscription = customer.subscriptions.order(created_at: :desc).first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      # NOTE: This does not seem to matter
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 10.days, properties: {unique_id: "id_1"})

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_1"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1200)
        expect(fee.amount_details).to eq({})
      end

      ### 16 february: Send an event.
      feb16 = DateTime.new(2023, 2, 16)

      travel_to(feb16) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_1", operation_type: "remove"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(0)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0)
      end

      ### 17 february: Send an other event.
      feb17 = DateTime.new(2023, 2, 17)

      travel_to(feb17) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_1"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(2).to(3)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0)
      end

      ### 18 february: Send an other event.
      feb18 = DateTime.new(2023, 2, 18)

      travel_to(feb18) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_2"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(3).to(4)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1200)
      end

      ### 19 february: Send an event with the same unique id. It creates a 0 amount fee.
      feb19 = DateTime.new(2023, 2, 19)
      travel_to(feb19) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_2"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(4).to(5)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(0)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0)
      end

      ### 20 february: Send an other event.
      feb20 = DateTime.new(2023, 2, 20)

      travel_to(feb20) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_3"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(5).to(6)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1200)
      end

      ### 21 february: Send an event.
      feb21 = DateTime.new(2023, 2, 21)

      travel_to(feb21) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {unique_id: "id_3", operation_type: "remove"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(6).to(7)

        fee = subscription.fees.order(created_at: :desc).first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(0)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0)
      end
    end
  end

  describe "with sum_agg / standard" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    it "creates a pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :standard_charge,
        :pay_in_advance,
        invoiceable: true,
        plan:,
        billable_metric:,
        properties: {amount: "1"}
      )

      subscription = customer.subscriptions.first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      # NOTE: This does not seem to matter
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days, properties: {amount: "5000"})

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "10"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).not_to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(10)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1000)
        expect(fee.amount_details).to eq({})
      end

      travel_to(DateTime.new(2023, 2, 17)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "-4"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(0)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0)
      end

      travel_to(DateTime.new(2023, 2, 18)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "8"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(2).to(3)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(4)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(400)
      end
    end

    context "when there is matching filter" do
      let(:transaction_id) { "#{SecureRandom.uuid}test" }
      let(:billable_metric_filter) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe])
      end

      it "creates a pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :standard_charge,
          :pay_in_advance,
          invoiceable: true,
          plan:,
          billable_metric:,
          properties: {amount: "0"}
        )
        charge_filter = create(:charge_filter, charge:, properties: {amount: "20"})
        create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["europe"])

        subscription = customer.subscriptions.first

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        # NOTE: This does not seem to matter
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days, properties: {amount: "50", region: "europe"})

        travel_to(feb15) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id:,
              external_subscription_id: subscription.external_id,
              properties: {amount: "10", region: "europe"}
            }
          )

          expect(subscription.reload.fees.count).to eq(1)
          event = Event.find_by(transaction_id:)
          expect(CachedAggregation.find_by(event_transaction_id: event.transaction_id).current_aggregation).to eq(10)

          fee = subscription.fees.first

          expect(fee.invoice_id).not_to be_nil
          expect(fee.charge_id).to eq(charge.id)
          expect(fee.pay_in_advance).to eq(true)
          expect(fee.units).to eq(10)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(20_000)
          expect(fee.charge_filter_id).to eq(charge_filter.id)
        end
      end
    end

    context "when there is no matching filter" do
      let(:transaction_id) { "#{SecureRandom.uuid}test" }
      let(:cloud_metric_filter) do
        create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[AWS])
      end
      let(:region_metric_filter) do
        create(:billable_metric_filter, billable_metric:, key: "region", values: %w[europe])
      end

      it "creates a pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :standard_charge,
          :pay_in_advance,
          invoiceable: true,
          plan:,
          billable_metric:,
          properties: {amount: "10"}
        )
        charge_filter = create(:charge_filter, charge:, properties: {amount: "20"})
        create(:charge_filter_value, charge_filter:, billable_metric_filter: region_metric_filter, values: ["europe"])
        create(:charge_filter_value, charge_filter:, billable_metric_filter: cloud_metric_filter, values: ["AWS"])

        subscription = customer.subscriptions.first

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        # NOTE: This does not seem to matter
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15, properties: {amount: "50", region: "africa", cloud: "AWS"})

        travel_to(feb15) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id:,
              external_subscription_id: subscription.external_id,
              properties: {amount: "10", region: "africa", cloud: "AWS"}
            }
          )

          expect(Event.find_by(transaction_id:).metadata["current_aggregation"]).to be_nil
          expect(subscription.reload.fees.count).to eq(1)
          expect(subscription.invoices.count).to eq(1)

          fee = subscription.fees.first

          expect(fee.invoice_id).not_to be_nil
          expect(fee.charge_id).to eq(charge.id)
          expect(fee.pay_in_advance).to eq(true)
          expect(fee.units).to eq(10)
          expect(fee.events_count).to eq(1)
          expect(fee.amount_cents).to eq(10_000)
          expect(fee.charge_filter_id).to be_nil
        end
      end
    end
  end

  describe "with sum_agg / package" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :package_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {amount: "100", free_units: 3, package_size: 2}
      )

      subscription = customer.subscriptions.first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      # Test create events until the 18th so we make this event is after that
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days, properties: {amount: "5"})

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "3"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(3)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(0) # free units
        expect(fee.amount_details).to eq({})
      end

      travel_to(DateTime.new(2023, 2, 17)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "1"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(10_000)
      end

      travel_to(DateTime.new(2023, 2, 18)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "2"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(2).to(3)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(2)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(10_000)
      end
    end
  end

  describe "with sum_agg / graduated" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :graduated_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {
          graduated_ranges: [
            {
              from_value: 0,
              to_value: 5,
              per_unit_amount: "0.02",
              flat_amount: "0.01"
            },
            {
              from_value: 6,
              to_value: nil,
              per_unit_amount: "0.01",
              flat_amount: "0.01"
            }
          ]
        }
      )

      subscription = customer.subscriptions.first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      # Test create events until the 18th so we make this event is after that
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days, properties: {amount: "5"})

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "3"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(3)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(2 * 3 + 1) # 3 events * 0.02 + 0.01 flat fee
        expect(fee.amount_details).to eq({})
      end

      travel_to(DateTime.new(2023, 2, 17)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "1"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(2 * 1)
      end

      travel_to(DateTime.new(2023, 2, 18)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "2"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(2).to(3)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(2)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(2 * 1 + 1 * 1 + 1)
      end
    end
  end

  # TODO: Add free_units calculation fix
  describe "with sum_agg / percentage" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    describe "with free_units_per_events" do
      it "creates an pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :percentage_charge,
          :pay_in_advance,
          invoiceable: false,
          plan:,
          billable_metric:,
          properties: {
            rate: "5",
            fixed_amount: "1",
            free_units_per_events: 2
          }
        )

        subscription = customer.subscriptions.first

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        # NOTE: This does not seem to matter
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: DateTime.new(2023, 2, 17), properties: {amount: "5"})

        travel_to(DateTime.new(2023, 2, 14)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "8"}
            }
          )
          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 8,
            events_count: 1,
            amount_cents: 0,
            amount_details: {
              "rate" => "5.0", "units" => "8.0", "free_units" => "8.0", "paid_units" => "0.0",
              "free_events" => "1.0", "paid_events" => "0.0", "fixed_fee_unit_amount" => "0.0",
              "per_unit_total_amount" => "0.0", "fixed_fee_total_amount" => "0.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        travel_to(feb15) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "5"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(1).to(2)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 5,
            events_count: 1,
            amount_cents: 0,
            amount_details: {
              "rate" => "5.0", "units" => "5.0", "free_units" => "5.0", "paid_units" => "0.0",
              "free_events" => "1.0", "paid_events" => "0.0", "fixed_fee_unit_amount" => "0.0",
              "per_unit_total_amount" => "0.0", "fixed_fee_total_amount" => "0.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end

        travel_to(DateTime.new(2023, 2, 16)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "3"}
            }
          )

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 3,
            events_count: 1,
            amount_cents: 100 + 15,
            amount_details: {
              "rate" => "5.0", "units" => "3.0", "free_units" => "0.0", "paid_units" => "3.0",
              "free_events" => "0.0", "paid_events" => "1.0", "fixed_fee_unit_amount" => "1.0",
              "per_unit_total_amount" => "0.15", "fixed_fee_total_amount" => "1.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end
      end
    end

    describe "with free_units_per_total_aggregation" do
      it "creates an pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :percentage_charge,
          :pay_in_advance,
          invoiceable: false,
          plan:,
          billable_metric:,
          properties: {
            rate: "5",
            fixed_amount: "1",
            free_units_per_total_aggregation: "120.0"
          }
        )

        subscription = customer.subscriptions.first

        ### 14 february: Send an event.
        travel_to(DateTime.new(2023, 2, 14)) do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "100"}
            }
          )
          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 100,
            events_count: 1,
            amount_cents: 0,
            amount_details: {
              "rate" => "5.0", "units" => "100.0", "free_units" => "100.0", "paid_units" => "0.0",
              "free_events" => "1.0", "paid_events" => "0.0", "fixed_fee_unit_amount" => "0.0",
              "per_unit_total_amount" => "0.0", "fixed_fee_total_amount" => "0.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        # NOTE: This does not seem to matter
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 4.days, properties: {amount: "50"})

        travel_to(feb15) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "10"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(1).to(2)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 10,
            events_count: 1,
            amount_cents: 0,
            amount_details: {
              "rate" => "5.0", "units" => "10.0", "free_units" => "10.0", "paid_units" => "0.0",
              "free_events" => "1.0", "paid_events" => "0.0", "fixed_fee_unit_amount" => "0.0",
              "per_unit_total_amount" => "0.0", "fixed_fee_total_amount" => "0.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end

        ### 16 february: Send an event.
        feb16 = DateTime.new(2023, 2, 16)

        travel_to(feb16) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "20"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(2).to(3)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 20,
            events_count: 1,
            amount_cents: 150,
            amount_details: {
              "rate" => "5.0", "units" => "20.0", "free_units" => "10.0", "paid_units" => "10.0",
              "free_events" => "0.0", "paid_events" => "1.0", "fixed_fee_unit_amount" => "1.0",
              "per_unit_total_amount" => "0.5", "fixed_fee_total_amount" => "1.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end

        ### 17 february: Send an event.
        feb17 = DateTime.new(2023, 2, 17)

        travel_to(feb17) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "20"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(3).to(4)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 20,
            events_count: 1,
            amount_cents: 200,
            amount_details: {
              "rate" => "5.0", "units" => "20.0", "free_units" => "0.0", "paid_units" => "20.0",
              "free_events" => "0.0", "paid_events" => "1.0", "fixed_fee_unit_amount" => "1.0",
              "per_unit_total_amount" => "1.0", "fixed_fee_total_amount" => "1.0",
              "min_max_adjustment_total_amount" => "0.0"
            }
          )
        end
      end
    end

    describe "with min / max per transaction", :premium do
      it "creates a pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :percentage_charge,
          :pay_in_advance,
          invoiceable: false,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "0.5",
            per_transaction_max_amount: "2",
            per_transaction_min_amount: "1.75"
          }
        )

        subscription = customer.subscriptions.first

        ### 14 february: Send an event.
        travel_to(DateTime.new(2023, 2, 14)) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "100"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(0).to(1)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 100,
            events_count: 1,
            amount_cents: 175 # Apply minimum amount
          )
        end

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 5.days, properties: {amount: "333"})

        travel_to(feb15) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "1000"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(1).to(2)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 1_000,
            events_count: 1,
            amount_cents: 200 # Apply maximum amount
          )
        end

        ### 16 february: Send an event.
        feb16 = DateTime.new(2023, 2, 16)

        travel_to(feb16) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "10000"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(2).to(3)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 10_000,
            events_count: 1,
            amount_cents: 200 # Apply maximum amount
          )

          fetch_current_usage(customer:)

          # NOTE: Notice that our event in the future is taken into account in current usage
          expect(json[:customer_usage][:charges_usage].sole[:units]).to eq("11433.0")
          expect(json[:customer_usage][:charges_usage].sole[:total_aggregated_units]).to eq("11433.0")
          expect(json[:customer_usage][:total_amount_cents]).to eq(775)
        end
      end
    end

    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :percentage_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {
          rate: "5",
          fixed_amount: "1",
          free_units_per_total_aggregation: "3.0"
        }
      )

      subscription = customer.subscriptions.first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "5"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(5)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(100 + 2 * 5) # 2 units not free
      end

      travel_to(DateTime.new(2023, 2, 17)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "1"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(215 - 110)
      end
    end
  end

  describe "with sum_agg / dynamic" do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    it "creates an pay_in_advance fee" do
      ### 26 September: Create subscription.
      sept26 = Time.zone.parse("2024-09-26")

      travel_to(sept26) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :dynamic_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:
      )

      subscription = customer.subscriptions.first

      ### 28th September: Send an event.
      sept28 = Time.zone.parse("2024-09-28")

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: Time.zone.parse("2024-09-30 11:00"), properties: {amount: "9876", precise_total_amount_cents: 9875.6823759})

      travel_to(sept28) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: 5},
              precise_total_amount_cents: "1234.56"
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(5)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(1235)
      end

      travel_to(Time.zone.parse("2024-09-30")) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "1"},
              precise_total_amount_cents: "2.1"
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(1)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(2)
      end
    end
  end

  describe "with count_agg / percentage" do
    let(:aggregation_type) { "count_agg" }
    let(:field_name) { "amount" }

    describe "with free_units_per_events" do
      it "creates an pay_in_advance fee" do
        ### 24 january: Create subscription.
        jan24 = DateTime.new(2023, 1, 24)

        travel_to(jan24) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code
            }
          )
        end

        charge = create(
          :percentage_charge,
          :pay_in_advance,
          invoiceable: false,
          plan:,
          billable_metric:,
          properties: {
            rate: "1",
            fixed_amount: "1",
            free_units_per_events: 1
          }
        )

        subscription = customer.subscriptions.first

        ### 15 february: Send an event.
        feb15 = DateTime.new(2023, 2, 15)

        # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
        create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 1.second, properties: {amount: "333"})

        travel_to(feb15) do
          expect do
            create_event(
              {
                code: billable_metric.code,
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                properties: {amount: "5"}
              }
            )
          end.to change { subscription.reload.fees.count }.from(0).to(1)

          fee = subscription.fees.order(created_at: :desc).first
          expect(fee).to have_attributes(
            invoice_id: nil,
            charge_id: charge.id,
            fee_type: "charge",
            pay_in_advance: true,
            units: 1,
            events_count: 1,
            amount_cents: 0
          )
        end
      end
    end
  end

  describe "with sum_agg / graduated_percentage", :premium do
    let(:aggregation_type) { "sum_agg" }
    let(:field_name) { "amount" }

    it "creates an pay_in_advance fee" do
      ### 24 january: Create subscription.
      jan24 = DateTime.new(2023, 1, 24)

      travel_to(jan24) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      charge = create(
        :graduated_percentage_charge,
        :pay_in_advance,
        invoiceable: false,
        plan:,
        billable_metric:,
        properties: {
          graduated_percentage_ranges:
           [{"rate" => "20", "to_value" => 100, "from_value" => 0, "flat_amount" => "10"},
             {"rate" => "30", "to_value" => 200, "from_value" => 101, "flat_amount" => "7"},
             {"rate" => "40", "to_value" => nil, "from_value" => 201, "flat_amount" => "5"}]
        }
      )

      subscription = customer.subscriptions.first

      ### 15 february: Send an event.
      feb15 = DateTime.new(2023, 2, 15)

      # Create events with timestamp AFTER the current event to invoice, to ensure `event.timestamp` is used as upper bound.
      create(:event, code: billable_metric.code, organization:, subscription:, timestamp: feb15 + 5.days, properties: {amount: "333"})

      travel_to(feb15) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "50"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(0).to(1)

        fee = subscription.fees.first

        expect(fee.invoice_id).to be_nil
        expect(fee.charge_id).to eq(charge.id)
        expect(fee.pay_in_advance).to eq(true)
        expect(fee.units).to eq(50)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(50 * 20 + 1000) # flat fee = 10, which is 1000 cents
        expect(fee.amount_details).to eq(
          {"graduated_percentage_ranges" => [
            {"rate" => "20.0", "units" => "50.0", "to_value" => 100, "from_value" => 0, "flat_unit_amount" => "10.0",
             "per_unit_total_amount" => "0.4", "total_with_flat_amount" => "20.0"}
          ]}
        )
      end

      travel_to(DateTime.new(2023, 2, 17)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "100"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(1).to(2)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(100)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(50 * 20 + 50 * 30 + 700) # this transactions goes into two tiers and we are including flat fee for the second tier
        expect(fee.amount_details).to eq(
          {"graduated_percentage_ranges" => [
            {"rate" => "20.0", "units" => "50.0", "to_value" => 100, "from_value" => 0, "flat_unit_amount" => "0.0",
             "per_unit_total_amount" => "0.2", "total_with_flat_amount" => "10.0"},
            {"rate" => "30.0", "units" => "50.0", "to_value" => 200, "from_value" => 101, "flat_unit_amount" => "7.0",
             "per_unit_total_amount" => "0.44", "total_with_flat_amount" => "22.0"}
          ]}
        )
      end

      travel_to(DateTime.new(2023, 2, 19)) do
        expect do
          create_event(
            {
              code: billable_metric.code,
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              properties: {amount: "300"}
            }
          )
        end.to change { subscription.reload.fees.count }.from(2).to(3)

        fee = subscription.fees.order(created_at: :desc).first
        expect(fee.units).to eq(300)
        expect(fee.events_count).to eq(1)
        expect(fee.amount_cents).to eq(50 * 30 + 250 * 40 + 500) # this transactions goes into two tiers and we are including flat fee for the second tier
        expect(fee.amount_details).to eq(
          {"graduated_percentage_ranges" => [
            {"rate" => "20.0", "units" => "0.0", "to_value" => 100, "from_value" => 0, "flat_unit_amount" => "0.0",
             "per_unit_total_amount" => "0.0", "total_with_flat_amount" => "0.0"},
            {"rate" => "30.0", "units" => "50.0", "to_value" => 200, "from_value" => 101, "flat_unit_amount" => "0.0",
             "per_unit_total_amount" => "0.3", "total_with_flat_amount" => "15.0"},
            {"rate" => "40.0", "units" => "250.0", "to_value" => nil, "from_value" => 201, "flat_unit_amount" => "5.0",
             "per_unit_total_amount" => "0.42", "total_with_flat_amount" => "105.0"}
          ]}
        )
      end
    end
  end
end
