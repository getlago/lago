# frozen_string_literal: true

require "rails_helper"

describe "Advance Charges Invoices Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:tax_rate) { 20 }
  let(:billable_metric) { create(:unique_count_billable_metric, organization:, code: "cards", recurring: true) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 49) }
  let(:plan_upgrade) { create(:plan, organization:, pay_in_advance: true, amount_cents: 259) }
  let(:external_subscription_id) { "sub_#{SecureRandom.hex}" }
  let(:bm_amount) { 30.12 }

  def send_card_event!(item_id = SecureRandom.uuid)
    api_response = create_event({
      code: billable_metric.code,
      transaction_id: "tr_#{SecureRandom.hex(10)}",
      external_customer_id: customer.external_id,
      external_subscription_id:,
      properties: {item_id:}
    })
    Fee.where(pay_in_advance_event_id: api_response.dig("event", "lago_id")).sole.id
  end

  def billing_periods_hash(invoice)
    ::V1::InvoiceSerializer.new(
      invoice,
      root_name: "invoice", includes: [:billing_periods]
    ).serialize[:billing_periods]
  end

  before do
    create(:tax, organization:, rate: tax_rate)
    create(:standard_charge, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, billable_metric:, plan:, properties: {amount: bm_amount.to_s, grouped_by: nil})
    create(:standard_charge, regroup_paid_fees: "invoice", pay_in_advance: true, invoiceable: false, prorated: true, billable_metric:, plan: plan_upgrade, properties: {amount: bm_amount.to_s, grouped_by: nil})
  end

  context "when subscription is upgraded, renewed and terminated" do
    it do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      initial_subscription = customer.subscriptions.sole
      fees = []

      # Create an event but keep it unpaid
      travel_to(DateTime.new(2024, 6, 12, 10)) do
        fees << send_card_event!("card_1")
        expect(initial_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
      end

      upgraded_subscription = nil
      # Upgrade the subscription (so previous one is terminated)
      travel_to(DateTime.new(2024, 7, 7, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan_upgrade.code
          }
        )

        upgraded_subscription = customer.subscriptions.where.not(id: initial_subscription.id).sole

        expect(initial_subscription.reload).to be_terminated
        expect(customer.invoices.count).to eq(2) # initial sub invoice + upgraded sub invoice
        expect(upgraded_subscription.fees.charge.count).to eq 0
      end

      # Create an event but keep it unpaid
      travel_to(DateTime.new(2024, 7, 22, 10)) do
        fees << send_card_event!("card_2")
        # one fee for each subscription
        expect(initial_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
        expect(upgraded_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
      end

      # In october, both fees are finally marked as paid
      travel_to(DateTime.new(2024, 10, 2, 10)) do
        fees.each do |fee_id|
          update_fee(fee_id, {payment_status: :succeeded})
        end
      end

      # In november, these fees should be added to the advance_charge invoice
      travel_to(DateTime.new(2024, 11, 1, 10)) do
        perform_billing
        invoice = customer.invoices.where(invoice_type: :advance_charges).sole
        invoice_fees = invoice.fees.order(:created_at)
        expect(invoice_fees.count).to eq(2)

        # Notice that the periods in the fees relate to the CREATION of the fees
        expect(invoice_fees.first.properties).to eq({
          "timestamp" => "2024-06-12T10:00:00.000Z",
          "to_datetime" => "2024-06-30T23:59:59.999Z",
          "from_datetime" => "2024-06-05T00:00:00.000Z",
          "charges_duration" => 30,
          "charges_to_datetime" => "2024-06-30T23:59:59.999Z",
          "charges_from_datetime" => "2024-06-05T10:00:00.000Z",
          "fixed_charges_to_datetime" => nil,
          "fixed_charges_from_datetime" => nil,
          "fixed_charges_duration" => nil
        })
        expect(invoice_fees.second.properties).to eq({
          "timestamp" => "2024-07-22T10:00:00.000Z",
          "to_datetime" => "2024-07-31T23:59:59.999Z",
          "from_datetime" => "2024-07-07T00:00:00.000Z",
          "charges_duration" => 31,
          "charges_to_datetime" => "2024-07-31T23:59:59.999Z",
          "charges_from_datetime" => "2024-07-07T10:00:00.000Z",
          "fixed_charges_to_datetime" => nil,
          "fixed_charges_from_datetime" => nil,
          "fixed_charges_duration" => nil
        })

        invoice_periods = billing_periods_hash(invoice)
        expect(invoice_periods.count).to eq(2)
        expect(invoice_periods).to all include({
          subscription_from_datetime: "2024-10-01T00:00:00Z",
          subscription_to_datetime: "2024-10-31T23:59:59Z",
          charges_from_datetime: "2024-10-01T00:00:00Z",
          charges_to_datetime: "2024-10-31T23:59:59Z",
          invoicing_reason: "in_advance_charge_periodic"
        })
      end

      # Some more events
      fees = []
      travel_to(DateTime.new(2024, 11, 18, 10)) do
        fees << send_card_event!("card_3")
        fees << send_card_event!("card_4")
      end
      travel_to(DateTime.new(2024, 12, 12, 10)) do
        fees << send_card_event!("card_5")
      end

      travel_to(DateTime.new(2025, 1, 1, 10)) do
        expect(customer.invoices.where(invoice_type: :advance_charges).count).to eq 1
        perform_billing # No new advance_charges invoice should be created
        expect(customer.invoices.where(invoice_type: :advance_charges).count).to eq 1
      end

      # Next year, the card_3 and card_5 fees are marked as paid
      travel_to(DateTime.new(2025, 1, 7, 10)) do
        update_fee(fees.first, {payment_status: :succeeded})
        update_fee(fees.last, {payment_status: :succeeded})
      end

      # The subscription is terminated. Customer have no other subscriptions
      travel_to(DateTime.new(2025, 1, 22, 10)) do
        terminate_subscription(upgraded_subscription)
        invoice = customer.invoices.where(invoice_type: :advance_charges).max_by(&:created_at)
        expect(invoice.fees.count).to eq(2)

        invoice_periods = billing_periods_hash(invoice)
        expect(invoice_periods.count).to eq(1)
        expect(invoice_periods.first).to include({
          subscription_from_datetime: "2025-01-01T00:00:00Z",
          subscription_to_datetime: "2025-01-22T10:00:00Z",
          charges_from_datetime: "2025-01-01T00:00:00Z",
          charges_to_datetime: "2025-01-22T10:00:00Z",
          invoicing_reason: "in_advance_charge_periodic"
        })
      end

      # Note: if a fee is marked as paid after the last subscription with THIS external_id was terminated
      #     it will never be attached to an invoice
    end
  end

  context "when subscription is downgraded, renewed and terminated" do
    it do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan_upgrade.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      initial_subscription = customer.subscriptions.sole
      fees = []

      # Create an event but keep it unpaid
      travel_to(DateTime.new(2024, 6, 12, 10)) do
        fees << send_card_event!("card_1")
        expect(initial_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
      end

      downgraded_subscription = nil
      # Upgrade the subscription (so previous one is terminated)
      travel_to(DateTime.new(2024, 7, 7, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )

        downgraded_subscription = customer.subscriptions.where.not(id: initial_subscription.id).sole

        expect(initial_subscription.reload).to be_active
        expect(downgraded_subscription.reload).to be_pending
        expect(customer.invoices.count).to eq(1) # initial sub invoice, nothing happens on downgrade
        expect(downgraded_subscription.fees.charge.count).to eq 0
      end

      # Create an event but keep it unpaid
      travel_to(DateTime.new(2024, 7, 22, 10)) do
        fees << send_card_event!("card_2")
        # one fee for each subscription
        expect(initial_subscription.fees.charge.where(invoice_id: nil).count).to eq(2)
        expect(downgraded_subscription.fees.charge.where(invoice_id: nil).count).to eq(0)
      end

      # It's billing day
      travel_to(DateTime.new(2024, 8, 1, 10)) do
        perform_billing

        expect(customer.invoices.count).to eq(2) # initial + renew
        expect(initial_subscription.reload).to be_terminated
        expect(downgraded_subscription.reload).to be_active
      end

      # In october, both fees are finally marked as paid
      travel_to(DateTime.new(2024, 10, 2, 10)) do
        fees.each do |fee_id|
          update_fee(fee_id, {payment_status: :succeeded})
        end
      end

      # In november, these fees should be added to the advance_charge invoice
      travel_to(DateTime.new(2024, 11, 1, 10)) do
        perform_billing
        invoice = customer.invoices.where(invoice_type: :advance_charges).sole
        invoice_fees = invoice.fees.order(:created_at)
        expect(invoice_fees.count).to eq(2)

        # Notice that the periods in the fees relate to the CREATION of the fees
        expect(invoice_fees.first.properties).to eq({
          "timestamp" => "2024-06-12T10:00:00.000Z",
          "to_datetime" => "2024-06-30T23:59:59.999Z",
          "from_datetime" => "2024-06-05T00:00:00.000Z",
          "charges_duration" => 30,
          "charges_to_datetime" => "2024-06-30T23:59:59.999Z",
          "charges_from_datetime" => "2024-06-05T10:00:00.000Z",
          "fixed_charges_to_datetime" => nil,
          "fixed_charges_from_datetime" => nil,
          "fixed_charges_duration" => nil
        })
        expect(invoice_fees.second.properties).to eq({
          "timestamp" => "2024-07-22T10:00:00.000Z",
          "to_datetime" => "2024-07-31T23:59:59.999Z",
          "from_datetime" => "2024-07-01T00:00:00.000Z",
          "charges_duration" => 31,
          "charges_to_datetime" => "2024-07-31T23:59:59.999Z",
          "charges_from_datetime" => "2024-07-01T00:00:00.000Z",
          "fixed_charges_to_datetime" => nil,
          "fixed_charges_from_datetime" => nil,
          "fixed_charges_duration" => nil
        })

        invoice_periods = billing_periods_hash(invoice)
        expect(invoice_periods.count).to eq(1) # only initial subscription had fees, so only on InvoiceSubscription
        expect(invoice_periods).to all include({
          subscription_from_datetime: "2024-10-01T00:00:00Z",
          subscription_to_datetime: "2024-10-31T23:59:59Z",
          charges_from_datetime: "2024-10-01T00:00:00Z",
          charges_to_datetime: "2024-10-31T23:59:59Z",
          invoicing_reason: "in_advance_charge_periodic"
        })
      end
    end
  end

  context "when subscription is upgraded but new sub has no events" do
    it do
      travel_to(DateTime.new(2024, 6, 5, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan.code
          }
        )
        perform_billing
        expect(customer.invoices.count).to eq(1)
      end

      initial_subscription = customer.subscriptions.sole
      fees = []

      # Create an event but keep it unpaid
      travel_to(DateTime.new(2024, 6, 12, 10)) do
        fees << send_card_event!("card_1")
        expect(initial_subscription.fees.charge.where(invoice_id: nil).count).to eq(1)
      end

      upgraded_subscription = nil
      # Upgrade the subscription (so previous one is terminated)
      travel_to(DateTime.new(2024, 7, 7, 10)) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: external_subscription_id,
            plan_code: plan_upgrade.code
          }
        )

        upgraded_subscription = customer.subscriptions.where.not(id: initial_subscription.id).sole

        expect(initial_subscription.reload).to be_terminated
        expect(customer.invoices.count).to eq(2) # initial sub invoice + upgraded sub invoice
        expect(upgraded_subscription.fees.charge.count).to eq 0
      end

      # In october, the fee from initial sub is finally marked as paid
      travel_to(DateTime.new(2024, 10, 2, 10)) do
        fees.each do |fee_id|
          update_fee(fee_id, {payment_status: :succeeded})
        end
      end

      # In november, this fee should be added to the advance_charge invoice
      travel_to(DateTime.new(2024, 11, 1, 10)) do
        perform_billing
        invoice = customer.invoices.where(invoice_type: :advance_charges).sole
        invoice_fees = invoice.fees.order(:created_at)

        # Notice that the periods in the fees relate to the CREATION of the fees
        expect(invoice_fees.first.properties).to eq({
          "timestamp" => "2024-06-12T10:00:00.000Z",
          "to_datetime" => "2024-06-30T23:59:59.999Z",
          "from_datetime" => "2024-06-05T00:00:00.000Z",
          "charges_duration" => 30,
          "charges_to_datetime" => "2024-06-30T23:59:59.999Z",
          "charges_from_datetime" => "2024-06-05T10:00:00.000Z",
          "fixed_charges_to_datetime" => nil,
          "fixed_charges_from_datetime" => nil,
          "fixed_charges_duration" => nil
        })

        invoice_periods = billing_periods_hash(invoice)
        expect(invoice_periods).to all include({
          subscription_from_datetime: "2024-10-01T00:00:00Z",
          subscription_to_datetime: "2024-10-31T23:59:59Z",
          charges_from_datetime: "2024-10-01T00:00:00Z",
          charges_to_datetime: "2024-10-31T23:59:59Z",
          invoicing_reason: "in_advance_charge_periodic"
        })
      end
    end
  end
end
