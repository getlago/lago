# frozen_string_literal: true

require "rails_helper"
describe "Billing Monthly Scenarios with all charges types" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:) }
  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 5_000_000,
      interval: "monthly",
      pay_in_advance: false
    )
  end
  let(:billable_metric_metered) do
    create(
      :billable_metric,
      organization:,
      name: "Metered in arrears",
      code: "metered",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: false
    )
  end
  let(:billable_metric_recurring) do
    create(
      :billable_metric,
      organization:,
      name: "Recurring",
      code: "recurring",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: true
    )
  end
  let(:charge_metered_not_prorated_in_arrears) do
    create(
      :package_charge,
      plan:,
      billable_metric: billable_metric_metered,
      properties: {amount: "100", package_size: 10, free_units: 0},
      prorated: false,
      pay_in_advance: false
    )
  end
  let(:charge_metered_not_prorated_in_advance) do
    create(
      :package_charge,
      plan:,
      billable_metric: billable_metric_metered,
      properties: {amount: "1000", package_size: 10, free_units: 2},
      prorated: false,
      pay_in_advance: true
    )
  end
  let(:charge_recurring_prorated_in_arrears) do
    create(
      :charge,
      plan:,
      billable_metric: billable_metric_recurring,
      properties: {amount: "5000"},
      prorated: true,
      pay_in_advance: false
    )
  end
  let(:charge_recurring_prorated_in_advance) do
    create(
      :charge,
      plan:,
      billable_metric: billable_metric_recurring,
      properties: {amount: "50000"},
      prorated: false,
      pay_in_advance: true
    )
  end
  let(:add_on) { create(:add_on) }
  let(:fixed_charge_not_prorated_in_arrears) { create(:fixed_charge, plan:, add_on:, units: 10, properties: {amount: "200"}, prorated: false, pay_in_advance: false) }
  let(:fixed_charge_not_prorated_in_advance) { create(:fixed_charge, plan:, add_on:, units: 10, properties: {amount: "200"}, prorated: false, pay_in_advance: true) }
  let(:fixed_charge_prorated_in_arrears) { create(:fixed_charge, plan:, add_on:, units: 10, properties: {amount: "200"}, prorated: true, pay_in_advance: false) }
  let(:fixed_charge_prorated_in_advance) { create(:fixed_charge, plan:, add_on:, units: 10, properties: {amount: "200"}, prorated: true, pay_in_advance: true) }

  before do
    charge_metered_not_prorated_in_arrears
    charge_metered_not_prorated_in_advance
    charge_recurring_prorated_in_arrears
    charge_recurring_prorated_in_advance
    fixed_charge_not_prorated_in_arrears
    fixed_charge_not_prorated_in_advance
    fixed_charge_prorated_in_arrears
    fixed_charge_prorated_in_advance
  end

  context "with calendar billing" do
    # let's also have here a spec for boundaries that we have on invoice_subscriptions
    let(:billing_time) { "calendar" }
    # february leap year!
    let(:subscription_time) { DateTime.new(2024, 2, 4) }

    it "work the whole year", transaction: false do
      subscription_date = DateTime.new(2024, 2, 4)
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time:
          }
        )
      end
      subscription = customer.subscriptions.first
      travel_to subscription_date + 10.minutes do
        perform_all_enqueued_jobs
      end
      # it immediately creates invoice with pay_in_advance fixed_charges
      expect(subscription.reload.invoices.count).to eq(1)
      pay_in_advance_fixed_charges_invoice = subscription.invoices.first
      expect(pay_in_advance_fixed_charges_invoice.fees.count).to eq(2)
      # check fixed_charge fees
      expect(pay_in_advance_fixed_charges_invoice.fees.fixed_charge.count).to eq(2)
      # fixed_charge_not_prorated_in_advance: 200 * 100 * 10, fixed_charge_prorated_in_advance: 2000 * 100 * 10 * 26/29
      expect(pay_in_advance_fixed_charges_invoice.fees.fixed_charge.map(&:amount_cents).sort).to match_array([179_310, 200_000])
      # check invoice_subscription boundaries
      invoice_subscription = pay_in_advance_fixed_charges_invoice.invoice_subscriptions.first
      expect(invoice_subscription).to have_attributes(
        from_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        to_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        charges_from_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        charges_to_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        fixed_charges_from_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        fixed_charges_to_datetime: DateTime.parse("2024-02-04T00:00:00Z"),
        timestamp: DateTime.parse("2024-02-04T00:00:01Z")
      )
      # check pay_in_advance fixed_charge_fees boundaries
      pay_in_advance_fixed_charge_fee = pay_in_advance_fixed_charges_invoice.fees.fixed_charge.where(fixed_charge_id: [fixed_charge_not_prorated_in_advance.id, fixed_charge_prorated_in_advance.id]).sample
      expect(pay_in_advance_fixed_charge_fee.properties).to include(
        "charges_from_datetime" => nil,
        "charges_to_datetime" => nil,
        "charges_duration" => nil,
        "fixed_charges_from_datetime" => "2024-02-04T00:00:00.000Z",
        "fixed_charges_to_datetime" => "2024-02-29T23:59:59.999Z",
        "fixed_charges_duration" => 29
      )
      # 28th of Feb - before billing, no usage sent for usage charges
      time = DateTime.new(2024, 2, 28)
      travel_to(time) do
        perform_billing
      end
      # old invoice
      expect(subscription.reload.invoices.count).to eq(1)

      time = DateTime.new(2024, 3, 1)
      travel_to(time) do
        perform_billing
      end
      expect(subscription.reload.invoices.count).to eq(2)
      last_invoice = subscription.invoices.order(:created_at).last

      expect(last_invoice.fees.fixed_charge.count).to eq(4)
      # we have in arrears prorated, in arrears prorated, 2 in advance (sp we're charging full amount)
      expect(last_invoice.fees.fixed_charge.map(&:amount_cents).sort).to match_array([179_310, 200_000, 200_000, 200_000])
      expect(last_invoice.fees.charge.count).to eq(0)
      expect(last_invoice.fees.subscription.count).to eq(1)
      subscription_fee_amount = (26.0 / 29 * 5_000_000).ceil
      fixed_charges_amount = 179_310 + 200_000 + 200_000 + 200_000
      expect(last_invoice.total_amount_cents).to eq(subscription_fee_amount + fixed_charges_amount)

      # check invoice_subscription boundaries
      last_invoice_inv_sub = last_invoice.invoice_subscriptions.first
      expect(last_invoice_inv_sub).to have_attributes(
        from_datetime: match_datetime("2024-02-04T00:00:00Z"),
        to_datetime: match_datetime("2024-02-29T23:59:59Z"),
        charges_from_datetime: match_datetime("2024-02-04T00:00:00Z"),
        charges_to_datetime: match_datetime("2024-02-29T23:59:59Z"),
        fixed_charges_from_datetime: match_datetime("2024-02-04T00:00:00Z"),
        fixed_charges_to_datetime: match_datetime("2024-02-29T23:59:59Z"),
        timestamp: match_datetime("2024-03-01T00:00:00Z")
      )

      # check pay_in_advance fixed_charge_fees boundaries
      pay_in_advance_fixed_charge_fees = last_invoice.fees.fixed_charge.where(fixed_charge_id: [fixed_charge_not_prorated_in_advance.id, fixed_charge_prorated_in_advance.id]).sample
      expect(pay_in_advance_fixed_charge_fees.properties).to include(
        "charges_from_datetime" => nil,
        "charges_to_datetime" => nil,
        "charges_duration" => nil,
        "fixed_charges_from_datetime" => match_datetime("2024-03-01T00:00:00Z"),
        "fixed_charges_to_datetime" => match_datetime("2024-03-31T23:59:59Z"),
        "fixed_charges_duration" => 31
      )

      # check pay_in_arrears fixed_charge_fees boundaries
      pay_in_arrears_fixed_charge_fees = last_invoice.fees.fixed_charge.where(fixed_charge_id: [fixed_charge_not_prorated_in_arrears.id, fixed_charge_prorated_in_arrears.id]).sample
      expect(pay_in_arrears_fixed_charge_fees.properties).to include(
        "charges_from_datetime" => nil,
        "charges_to_datetime" => nil,
        "charges_duration" => nil,
        "fixed_charges_from_datetime" => "2024-02-04T00:00:00.000Z",
        "fixed_charges_to_datetime" => "2024-02-29T23:59:59.999Z",
        "fixed_charges_duration" => 29
      )

      # travel to the middle of month and create events per each charge:
      events_date = DateTime.new(2024, 3, 15)
      travel_to(events_date) do
        [billable_metric_metered, billable_metric_recurring].each do |billable_metric|
          create_event(
            {
              transaction_id: SecureRandom.uuid,
              external_subscription_id: subscription.external_id,
              code: billable_metric.code,
              properties: {
                billable_metric.field_name => 10
              }
            }
          )
        end
        perform_all_enqueued_jobs
      end
      # we should create invoices for received pay_in_advance charges:
      expect(subscription.reload.invoices.count).to eq(4)
      last_invoices = subscription.invoices.order(:created_at).last(2)
      expected_invoices_data = [
        {
          charge_count: 1,
          charge_ids: [charge_metered_not_prorated_in_advance.id],
          total_amount_cents: 100_000
        },
        {
          charge_count: 1,
          charge_ids: [charge_recurring_prorated_in_advance.id],
          total_amount_cents: 50_000_000
        }
      ]

      actual_invoices_data = last_invoices.map do |invoice|
        {
          charge_count: invoice.fees.charge.count,
          charge_ids: invoice.fees.charge.pluck(:charge_id),
          total_amount_cents: invoice.total_amount_cents
        }
      end

      expect(actual_invoices_data).to match_array(expected_invoices_data)

      billing_time = DateTime.new(2024, 4, 1)
      travel_to(billing_time) do
        EventsRecord.connection.commit_db_transaction
        perform_billing
      end
      expect(subscription.reload.invoices.count).to eq(5)
      last_invoice = subscription.invoices.order(:created_at).last
      expect(last_invoice.fees.fixed_charge.count).to eq(4)
      expect(last_invoice.fees.fixed_charge.map(&:amount_cents).sort).to match_array([200_000, 200_000, 200_000, 200_000])
      fixed_charge_fees_sum = 4 * 200_000
      # note that charge_recurring_prorated_in_advance should be included, because since it's recurring, it has usage,
      # which we're charging in_advance
      expect(last_invoice.fees.charge.count).to eq(3)
      expect(last_invoice.fees.charge.map(&:charge_id)).to match_array([charge_metered_not_prorated_in_arrears.id, charge_recurring_prorated_in_arrears.id, charge_recurring_prorated_in_advance.id])

      # Note: prorated_fee_amount should be 500000 * 10 * 17/31,
      # prorated_fee_amount = 2_741_935 - this is math correct, but service returns 2_741_940 because of rounding (10 * 17 / 31).
      prorated_fee_amount = 2_741_940
      expected_charge_fees = [
        {charge_id: charge_metered_not_prorated_in_arrears.id, amount_cents: 10_000},
        {charge_id: charge_recurring_prorated_in_arrears.id, amount_cents: prorated_fee_amount},
        {charge_id: charge_recurring_prorated_in_advance.id, amount_cents: 50_000_000}
      ]
      actual_charge_fees = last_invoice.fees.charge.map do |fee|
        {
          charge_id: fee.charge_id,
          amount_cents: fee.amount_cents
        }
      end
      expect(actual_charge_fees).to match_array(expected_charge_fees)
      expect(last_invoice.fees.subscription.count).to eq(1)
      expect(last_invoice.fees.subscription.map(&:amount_cents)).to match_array([5_000_000])
      expect(last_invoice.total_amount_cents).to eq(5_000_000 + 50_000_000 + 10_000 + prorated_fee_amount + fixed_charge_fees_sum)

      # check boundaries
      invoice_subscription = last_invoice.invoice_subscriptions.first
      expect(invoice_subscription).to have_attributes(
        from_datetime: match_datetime("2024-03-01T00:00:00Z"),
        to_datetime: match_datetime("2024-03-31T23:59:59Z"),
        charges_from_datetime: match_datetime("2024-03-01T00:00:00Z"),
        charges_to_datetime: match_datetime("2024-03-31T23:59:59Z"),
        fixed_charges_from_datetime: match_datetime("2024-03-01T00:00:00Z"),
        fixed_charges_to_datetime: match_datetime("2024-03-31T23:59:59Z"),
        timestamp: match_datetime("2024-04-01T00:00:00Z")
      )
      # check pay_in_advance fixed_charge_fees boundaries
      pay_in_advance_fixed_charge_fees = last_invoice.fees.fixed_charge.where(fixed_charge_id: [fixed_charge_not_prorated_in_advance.id, fixed_charge_prorated_in_advance.id]).sample
      expect(pay_in_advance_fixed_charge_fees.properties).to include(
        "charges_from_datetime" => nil,
        "charges_to_datetime" => nil,
        "charges_duration" => nil,
        "fixed_charges_from_datetime" => "2024-04-01T00:00:00.000Z",
        "fixed_charges_to_datetime" => "2024-04-30T23:59:59.999Z",
        "fixed_charges_duration" => 30
      )
      # check pay_in_arrears fixed_charge_fees boundaries
      pay_in_arrears_fixed_charge_fees = last_invoice.fees.fixed_charge.where(fixed_charge_id: [fixed_charge_not_prorated_in_arrears.id, fixed_charge_prorated_in_arrears.id]).sample
      expect(pay_in_arrears_fixed_charge_fees.properties).to include(
        "charges_from_datetime" => nil,
        "charges_to_datetime" => nil,
        "charges_duration" => nil,
        "fixed_charges_from_datetime" => match_datetime("2024-03-01T00:00:00Z"),
        "fixed_charges_to_datetime" => match_datetime("2024-03-31T23:59:59Z"),
        "fixed_charges_duration" => 31
      )

      # check charge fees boundaries
      charge_fees = last_invoice.fees.charge.where(charge_id: [charge_metered_not_prorated_in_arrears.id, charge_recurring_prorated_in_arrears.id, charge_recurring_prorated_in_advance.id]).sample
      expect(charge_fees.properties).to include(
        "charges_from_datetime" => "2024-03-01T00:00:00.000Z",
        "charges_to_datetime" => "2024-03-31T23:59:59.999Z",
        "charges_duration" => 31,
        "fixed_charges_from_datetime" => nil,
        "fixed_charges_to_datetime" => nil,
        "fixed_charges_duration" => nil
      )

      # travel to several dates in the next month and send usages
      [DateTime.new(2024, 4, 10), DateTime.new(2024, 4, 30)].each do |date|
        travel_to(date) do
          [billable_metric_recurring, billable_metric_metered].each do |billable_metric|
            create_event(
              {
                transaction_id: SecureRandom.uuid,
                external_subscription_id: subscription.external_id,
                code: billable_metric.code,
                properties: {
                  billable_metric.field_name => 20
                }
              }
            )
          end
          perform_all_enqueued_jobs
        end
      end

      # we should create invoices for received pay_in_advance charges:
      expect(subscription.reload.invoices.count).to eq(9)
      last_invoices = subscription.invoices.order(:created_at).last(4)
      expected_invoices_data = [
        {
          charge_count: 1,
          charge_ids: [charge_metered_not_prorated_in_advance.id],
          total_amount_cents: 200_000
        },
        {
          charge_count: 1,
          charge_ids: [charge_recurring_prorated_in_advance.id],
          total_amount_cents: 100_000_000
        },
        {
          charge_count: 1,
          charge_ids: [charge_metered_not_prorated_in_advance.id],
          total_amount_cents: 200_000
        },
        {
          charge_count: 1,
          charge_ids: [charge_recurring_prorated_in_advance.id],
          total_amount_cents: 100_000_000
        }
      ]

      actual_invoices_data = last_invoices.map do |invoice|
        {
          charge_count: invoice.fees.charge.count,
          charge_ids: invoice.fees.charge.pluck(:charge_id),
          total_amount_cents: invoice.total_amount_cents
        }
      end

      expect(actual_invoices_data).to match_array(expected_invoices_data)

      billing_time = DateTime.new(2024, 5, 1)
      travel_to(billing_time) do
        perform_billing
      end
      expect(subscription.reload.invoices.count).to eq(10)
      last_invoice = subscription.invoices.order(:created_at).last
      expect(last_invoice.fees.fixed_charge.count).to eq(4)
      expect(last_invoice.fees.fixed_charge.map(&:amount_cents).sort).to match_array([200_000, 200_000, 200_000, 200_000])
      fixed_charge_fees_sum = 4 * 200_000
      # note that charge_recurring_prorated_in_advance should be included, because since it's recurring, it has usage,
      # which we're charging in_advance
      expect(last_invoice.fees.charge.count).to eq(3)
      expect(last_invoice.fees.charge.map(&:charge_id)).to match_array([charge_metered_not_prorated_in_arrears.id, charge_recurring_prorated_in_arrears.id, charge_recurring_prorated_in_advance.id])

      # check amounts by charges
      # prorated amount is: current usage: 500000 * 20 * 21/30 + 500000 * 20 * 1/30 + persisted usage:  500000 * 10
      prorated_fee_amount = 7_333_335 + 5000000 # 12_333_333

      expected_charge_fees = [
        {charge_id: charge_metered_not_prorated_in_arrears.id, amount_cents: 40_000},
        {charge_id: charge_recurring_prorated_in_arrears.id, amount_cents: prorated_fee_amount},
        # 200_000_000 new usage + 50_000_000 accumulatedfrom previous month
        {charge_id: charge_recurring_prorated_in_advance.id, amount_cents: 250_000_000}
      ]

      actual_charge_fees = last_invoice.fees.charge.map do |fee|
        {
          charge_id: fee.charge_id,
          amount_cents: fee.amount_cents
        }
      end

      expect(actual_charge_fees).to match_array(expected_charge_fees)

      expect(last_invoice.fees.subscription.count).to eq(1)
      expect(last_invoice.fees.subscription.map(&:amount_cents)).to match_array([5_000_000])
      expect(last_invoice.total_amount_cents).to eq(5_000_000 + 250_000_000 + 40_000 + prorated_fee_amount + fixed_charge_fees_sum)

      # month without any events
      billing_time = DateTime.new(2024, 6, 1)
      travel_to(billing_time) do
        perform_billing
      end
      expect(subscription.reload.invoices.count).to eq(11)
      last_invoice = subscription.invoices.order(:created_at).last
      expect(last_invoice.fees.fixed_charge.count).to eq(4)
      expect(last_invoice.fees.fixed_charge.map(&:amount_cents).sort).to match_array([200_000, 200_000, 200_000, 200_000])
      fixed_charge_fees_sum = 4 * 200_000
      # note that charge_recurring_prorated_in_advance should be included, because since it's recurring, it has usage,
      # which we're charging in_advance
      expect(last_invoice.fees.charge.count).to eq(2)
      expect(last_invoice.fees.charge.map(&:charge_id)).to match_array([charge_recurring_prorated_in_arrears.id, charge_recurring_prorated_in_advance.id])

      # check amounts by charges
      expected_charge_fees = [
        {
          charge_id: charge_recurring_prorated_in_arrears.id,
          # 50_000 * (10 + 20 + 20) = 25_000_000
          amount_cents: 25_000_000
        },
        {
          charge_id: charge_recurring_prorated_in_advance.id,
          # 200_000_000 new usage + 50_000_000 accumulated from previous month
          amount_cents: 250_000_000
        }
      ]

      actual_charge_fees = last_invoice.fees.charge.map do |fee|
        {
          charge_id: fee.charge_id,
          amount_cents: fee.amount_cents
        }
      end

      expect(actual_charge_fees).to match_array(expected_charge_fees)

      expect(last_invoice.fees.subscription.count).to eq(1)
      expect(last_invoice.fees.subscription.map(&:amount_cents)).to match_array([5_000_000])
      expect(last_invoice.total_amount_cents).to eq(5_000_000 + 250_000_000 + 25_000_000 + fixed_charge_fees_sum)
    end
  end
end
