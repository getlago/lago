# frozen_string_literal: true

require "rails_helper"

describe "Invoices Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: []) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }

  before { tax }

  context "when pay in advance subscription with free trial used on several subscriptions" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 3500, pay_in_advance: true, trial_period: 7) }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2024-03-04T21:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first
      expect(subscription.invoices.count).to eq(0)

      travel_to(Time.zone.parse("2024-03-11T22:00:00")) do
        perform_billing
      end

      invoice = subscription.invoices.first
      expect(invoice.total_amount_cents).to eq(2371) # (31 - 3 - 7) * 35 / 31

      travel_to(Time.zone.parse("2024-03-11T23:00:00")) do
        terminate_subscription(subscription)
      end

      term_invoice = subscription.invoices.order(created_at: :desc).first
      expect(term_invoice.total_amount_cents).to eq(0)

      expect(invoice.reload.credit_notes.count).to eq(1)

      credit_note = invoice.credit_notes.first
      expect(credit_note).to have_attributes(
        sub_total_excluding_taxes_amount_cents: 23_71,
        taxes_amount_cents: 0,
        total_amount_cents: 23_71
      )

      travel_to(Time.zone.parse("2024-03-11T23:05:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        subscription = customer.subscriptions.active.first
        invoice = subscription.invoices.first
        expect(invoice.fees_amount_cents).to eq(2371) # (31 - 4 - 6) * 35 / 31
      end
    end
  end

  context "when timezone is negative and not the same day as UTC" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:, timezone: "America/Denver") } # UTC-6
    let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: true, interval: "weekly") }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2023-06-16T05:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        subscription = customer.subscriptions.first
        invoice = subscription.invoices.first
        expect(invoice.total_amount_cents).to eq(400) # 4 days
      end
    end
  end

  context "when timezone is negative but same day as UTC" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:, timezone: "America/Halifax") } # UTC-3
    let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: true, interval: "weekly") }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2023-06-16T05:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        subscription = customer.subscriptions.first
        invoice = subscription.invoices.first
        expect(invoice.total_amount_cents).to eq(300) # 3 days
      end
    end
  end

  context "when timezone is positive but same day as UTC" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:, timezone: "Europe/Paris") } # UTC+2
    let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: true, interval: "weekly") }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2023-06-16T20:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        subscription = customer.subscriptions.first
        invoice = subscription.invoices.first
        expect(invoice.total_amount_cents).to eq(300) # 3 days
      end
    end
  end

  context "when timezone is positive and not the same day as UTC" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:, timezone: "Asia/Karachi") } # UTC+5
    let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: true, interval: "weekly") }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2023-06-16T20:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        subscription = customer.subscriptions.first
        invoice = subscription.invoices.first
        expect(invoice.total_amount_cents).to eq(200) # 2 days
      end
    end
  end

  context "when invoice boundaries should cover leap month february" do
    let(:organization) { create(:organization, webhook_url: nil) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 700, pay_in_advance: true, interval: "monthly") }

    it "creates an invoice for the expected period" do
      travel_to(Time.zone.parse("2023-06-16T05:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-02-01T12:12:00")) do
        perform_billing

        invoice = subscription.invoices.order(created_at: :desc).first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice_subscription.from_datetime.iso8601).to eq("2024-02-01T00:00:00Z")
        expect(invoice_subscription.to_datetime.iso8601).to eq("2024-02-29T23:59:59Z")
        expect(invoice_subscription.charges_from_datetime.iso8601).to eq("2024-01-01T00:00:00Z")
        expect(invoice_subscription.charges_to_datetime.iso8601).to eq("2024-01-31T23:59:59Z")

        expect(invoice.total_amount_cents).to eq(700)
      end
    end
  end

  context "when subscription is upgraded without grace period" do
    let(:customer) { create(:customer, organization:, invoice_grace_period: 0) }
    let(:plan) { create(:plan, organization:, amount_cents: 0) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 2000) }
    let(:metric) { create(:latest_billable_metric, organization:) }

    it "creates invoices with correctly attached amounts and reasons" do
      ### 24 Apr: Create subscription + charge.
      apr24_10 = Time.zone.parse("2024-04-24T10:00:00")

      travel_to(apr24_10) do
        create(
          :package_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          invoiceable: true,
          properties: {
            amount: "2",
            free_units: 1000,
            package_size: 1000
          }
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.active.first

      ### 24 Apr: Upgrade subscription
      apr24_11 = Time.zone.parse("2024-04-24T11:00:00")

      travel_to(apr24_11) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code
            }
          )
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice.status).to eq("finalized")
        expect(invoice.total_amount_cents).to eq(0)
        expect(invoice_subscription.invoicing_reason).to eq("subscription_terminating")
        expect(invoice_subscription.from_datetime.iso8601).to eq("2024-04-24T00:00:00Z")
        expect(invoice_subscription.to_datetime.iso8601).to eq("2024-04-24T11:00:00Z")
        expect(invoice_subscription.charges_from_datetime.iso8601).to eq("2024-04-24T10:00:00Z")
        expect(invoice_subscription.charges_to_datetime.iso8601).to eq("2024-04-24T11:00:00Z")
      end

      latest_subscription = customer.subscriptions.active.order(created_at: :desc).first

      ### 26 Apr: Terminate subscription
      apr26_11 = Time.zone.parse("2024-04-26T11:00:00")

      travel_to(apr26_11) do
        expect {
          terminate_subscription(latest_subscription)
        }.to change { latest_subscription.reload.status }.from("active").to("terminated")
          .and change { latest_subscription.invoices.count }.from(0).to(1)

        invoice = latest_subscription.invoices.first
        invoice_subscription = invoice.invoice_subscriptions.first

        expect(invoice.status).to eq("finalized")
        expect(invoice.total_amount_cents).to eq(240) # (2000/30) x 3 + tax
        expect(invoice_subscription.invoicing_reason).to eq("subscription_terminating")
        expect(invoice_subscription.from_datetime.iso8601).to eq("2024-04-24T00:00:00Z")
        expect(invoice_subscription.to_datetime.iso8601).to eq("2024-04-26T11:00:00Z")
        expect(invoice_subscription.charges_from_datetime.iso8601).to eq("2024-04-24T11:00:00Z")
        expect(invoice_subscription.charges_to_datetime.iso8601).to eq("2024-04-26T11:00:00Z")
      end
    end
  end

  context "when subscription is terminated with a grace period" do
    let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:metric) { create(:billable_metric, organization:) }

    it "does not update the invoice amount on refresh" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "3"})
      end

      subscription = customer.subscriptions.first

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20T06:00:00")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.total_amount_cents).to eq(233) # 12 / 31 * 6

        # Refresh invoice
        expect {
          refresh_invoice(invoice)
        }.not_to change { invoice.reload.total_amount_cents }
      end
    end
  end

  context "when pay in arrear subscription with recurring charges is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "does bill the charges" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "3"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      travel_to(Time.zone.parse("2022-12-16T10:12")) do
        create_event(
          {
            external_subscription_id: customer.external_id,
            transaction_id: SecureRandom.uuid,
            code: metric.code,
            timestamp: Time.current.to_i,
            properties: {metric.field_name => 0}
          }
        )
      end

      subscription = customer.subscriptions.first

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.charge.count).to eq(1)
      end
    end
  end

  context "when pay in arrear subscription with recurring and prorated charges is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "does bill the charges", transaction: true do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "3"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2022-12-16T10:12")) do
        create_event(
          {
            external_subscription_id: customer.external_id,
            transaction_id: SecureRandom.uuid,
            code: metric.code,
            timestamp: Time.current.to_i,
            properties: {metric.field_name => 10}
          }
        )
        # we need to commit the transaction, so the event will also be visible with ActiveRecord::Base.connection
        EventsRecord.connection.commit_db_transaction
      end

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.charge.count).to eq(1)
        expect(invoice.fees.charge.first.amount_cents).to eq(484)
      end
    end
  end

  context "when pay in arrear subscription with no charges is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000, interval: "yearly") }

    it "creates subscription fee and adds it to the invoice" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.subscription.count).to eq(1)
      end
    end
  end

  context "when pay in arrear subscription with recurring charges is upgraded and new plan does not contain same BM" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 2000) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "does bill the charges" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "3"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2022-12-16T10:12")) do
        create_event(
          {
            external_subscription_id: customer.external_id,
            transaction_id: SecureRandom.uuid,
            code: metric.code,
            timestamp: Time.current.to_i,
            properties: {metric.field_name => 0}
          }
        )
      end

      ### 20 Dec: Upgrade subscription
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code
            }
          )
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.charge.count).to eq(1)
      end
    end
  end

  context "when pay in arrear subscription with recurring charges is upgraded and new plan contains same BM" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 2000) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "does not bill the charges" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "3"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      ### 20 Dec: Upgrade subscription
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "3"}
        )

        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code
            }
          )
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.charge.count).to eq(0)
      end
    end
  end

  context "when pay in advance subscription with recurring and prorated charges is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "does not bill the charges" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: true,
          prorated: true,
          properties: {amount: "3"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )
      end

      subscription = customer.subscriptions.first

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20 06:00:00")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription.invoices.count }.from(0).to(1)

        invoice = subscription.invoices.first
        expect(invoice.fees.charge.count).to eq(0)
      end
    end
  end

  context "when pay in advance subscription is upgraded" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: true) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 29_000, pay_in_advance: true) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "bills fees correctly", transaction: false do
      travel_to(Time.zone.parse("2024-01-01T00:00:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-01-02T00:00:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "5"}
          }
        )
      end

      travel_to(Time.zone.parse("2024-02-01T00:00:00")) do
        perform_billing
      end

      travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code,
              billing_time: "calendar"
            }
          )
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(2).to(3)

        invoice = customer.subscriptions.active.first.invoices.order(created_at: :desc).first
        credit_note = customer.credit_notes.first

        expect(credit_note.credit_amount_cents).to eq(1_800)
        expect(invoice.total_amount_cents).to eq(18_000 + 190 - 1_800) # 11/29 x 500 = 172
      end

      travel_to(Time.zone.parse("2024-03-01T12:12:00")) do
        perform_billing

        invoice = customer.subscriptions.active.first.invoices.order(created_at: :desc).first

        expect(invoice.total_amount_cents).to eq((29_000 + (18.fdiv(29) * 500)).round)
      end
    end
  end

  context "when pay in arrear subscription is upgraded" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: false) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 29_000, pay_in_advance: false) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "bills fees correctly", transaction: false do
      travel_to(Time.zone.parse("2024-01-01T00:00:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-01-02T00:00:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "5"}
          }
        )
      end

      travel_to(Time.zone.parse("2024-02-01T00:00:00")) do
        perform_billing
      end

      travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code,
              billing_time: "calendar"
            }
          )
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(1).to(2)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first

        expect(terminated_invoice.total_amount_cents).to eq((1_100 + (11.fdiv(29) * 500)).round) # 11 + 10/29 x 5
      end

      travel_to(Time.zone.parse("2024-03-01T12:12:00")) do
        perform_billing

        invoice = customer.subscriptions.active.first.invoices.order(created_at: :desc).first

        expect(invoice.total_amount_cents).to eq((18_000 + (18.fdiv(29) * 500)).round)
      end
    end
  end

  context "when pay in arrear plan events are ingested on the plan change date" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 0, pay_in_advance: false) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: false, field_name: "amount")
    end

    it "bills fees correctly" do
      travel_to(Time.zone.parse("2024-01-10T06:20:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "0"}
        )

        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: false,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-01-10T08:20:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "10"}
          }
        )

        fetch_current_usage(customer:, subscription:)
        expect(json[:customer_usage][:amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10.0")
      end

      travel_to(Time.zone.parse("2024-01-10T08:30:00")) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan_new.code,
              billing_time: "anniversary"
            }
          )
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(0).to(1)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first
        active_subscription = customer.reload.subscriptions.active.order(created_at: :desc).first

        expect(terminated_invoice.total_amount_cents).to eq(0)

        fetch_current_usage(customer:, subscription: active_subscription)
        expect(json[:customer_usage][:amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
      end

      active_subscription = customer.subscriptions.active.first

      travel_to(Time.zone.parse("2024-01-10T08:35:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: active_subscription.external_id,
            properties: {amount: "10000"}
          }
        )

        fetch_current_usage(customer:, subscription:)
        expect(json[:customer_usage][:amount_cents].round(2)).to eq(1_000_000)
        expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(1_000_000)
        expect(json[:customer_usage][:charges_usage][0][:units]).to eq("10000.0")
      end

      travel_to(Time.zone.parse("2024-01-10T08:40:00")) do
        expect {
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary"
            }
          )
          perform_all_enqueued_jobs
        }.to change { active_subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(1).to(2)

        terminated_invoice = active_subscription.invoices.order(created_at: :desc).first
        active_subscription = customer.reload.subscriptions.active.order(created_at: :desc).first

        expect(terminated_invoice.total_amount_cents).to eq(1_000_000)

        fetch_current_usage(customer:, subscription: active_subscription)
        expect(json[:customer_usage][:amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:total_amount_cents].round(2)).to eq(0)
        expect(json[:customer_usage][:charges_usage][0][:units]).to eq("0.0")
      end
    end
  end

  context "when pay in advance subscription is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: true) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 29_000, pay_in_advance: true) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "bills fees correctly", transaction: false do
      travel_to(Time.zone.parse("2024-01-01T00:00:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-01-02T00:00:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "5"}
          }
        )
      end

      travel_to(Time.zone.parse("2024-02-01T00:00:00")) do
        perform_billing
      end

      travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
        expect {
          terminate_subscription(subscription)
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(2).to(3)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first
        credit_note = customer.credit_notes.first

        expect(credit_note.credit_amount_cents).to eq(1_700)
        expect(terminated_invoice.total_amount_cents).to eq(0) # 12/29 x 500 = 207 - 207(CN)
        expect(terminated_invoice.fees_amount_cents).to eq(207)
        expect(terminated_invoice.credit_notes_amount_cents).to eq(207)
      end
    end
  end

  context "when pay in advance subscription is terminated on the same day" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: true) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) { create(:billable_metric, organization:) }

    it "bills fees correctly" do
      travel_to(Time.zone.parse("2024-02-01T03:00:00")) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first
      first_invoice = subscription.invoices.first

      travel_to(Time.zone.parse("2024-02-01T18:00:00")) do
        expect {
          terminate_subscription(subscription)
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(1).to(2)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first
        credit_note = customer.credit_notes.first

        expect(first_invoice.reload.credit_notes.count).to eq(1)
        expect(credit_note.credit_amount_cents).to eq(2_800) # Only one day is billed
        expect(terminated_invoice.total_amount_cents).to eq(0) # There are no charges
      end
    end

    context "with usage events" do
      it "bills the usage correctly" do
        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "12"})

        travel_to(Time.zone.parse("2024-02-01 03:00:00")) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            }
          )
        end
        subscription = customer.subscriptions.first
        first_invoice = subscription.invoices.first

        travel_to(Time.zone.parse("2024-02-01 10:00:00")) do
          create_event(
            {
              code: metric.code,
              transaction_id: SecureRandom.uuid,
              organization_id: organization.id,
              external_subscription_id: subscription.external_id
            }
          )
        end

        travel_to(Time.zone.parse("2024-02-01 18:00:00")) do
          expect {
            terminate_subscription(subscription)
            perform_all_enqueued_jobs
          }.to change { subscription.reload.status }.from("active").to("terminated")
            .and change { customer.invoices.count }.from(1).to(2)

          terminated_invoice = subscription.invoices.order(created_at: :desc).first
          credit_note = customer.credit_notes.sole

          expect(first_invoice.reload.credit_notes.count).to eq(1)
          expect(credit_note.credit_amount_cents).to eq(2_800) # Only one day is billed
          expect(terminated_invoice.fees.charge.sole.total_amount_cents).to eq(1200)
        end
      end
    end
  end

  context "when pay in advance subscription with grace period is terminated", :premium do
    let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: true) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end
    let(:adjusted_fee_params) do
      {
        unit_precise_amount: "5.00",
        units: 3
      }
    end

    it "bills fees correctly", transaction: false do
      travel_to(Time.zone.parse("2024-01-01T00:00:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      first_invoice = customer.invoices.draft.first
      subscription = customer.subscriptions.first

      finalize_invoice(first_invoice)

      travel_to(Time.zone.parse("2024-01-02T00:00:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "5"}
          }
        )
      end

      travel_to(Time.zone.parse("2024-02-01T00:00:00")) do
        perform_billing

        finalize_invoice(subscription.invoices.order(created_at: :desc).first)
      end

      travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
        expect {
          terminate_subscription(subscription)
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(2).to(3)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first
        credit_note = customer.credit_notes.first

        # credit notes are not applied on draft invoice
        expect(credit_note.credit_amount_cents).to eq(1_700)
        expect(credit_note.balance_amount_cents).to eq(1_700)
        expect(terminated_invoice.total_amount_cents).to eq(207) # 12/29 x 500 = 207
        expect(terminated_invoice.fees_amount_cents).to eq(207)
        expect(terminated_invoice.credit_notes_amount_cents).to eq(0)

        # In terminated invoice there is only one fee that is charge kind
        fee = terminated_invoice.fees.charge.first

        AdjustedFees::CreateService.call(invoice: terminated_invoice, params: adjusted_fee_params.merge(fee_id: fee.id))
        credit_note = credit_note.reload
        terminated_invoice = terminated_invoice.reload

        expect(credit_note.credit_amount_cents).to eq(1_700)
        expect(credit_note.balance_amount_cents).to eq(1_700)
        expect(terminated_invoice.total_amount_cents).to eq(1_500)
        expect(terminated_invoice.fees_amount_cents).to eq(1_500)
        expect(terminated_invoice.credit_notes_amount_cents).to eq(0)

        finalize_invoice(terminated_invoice)
        credit_note = credit_note.reload
        terminated_invoice = terminated_invoice.reload

        # after finalizing draft invoice, credit notes got applied
        expect(credit_note.credit_amount_cents).to eq(1_700)
        expect(credit_note.balance_amount_cents).to eq(200)
        expect(terminated_invoice.total_amount_cents).to eq(0) # 1500 - 1500(CN)
        expect(terminated_invoice.fees_amount_cents).to eq(1_500)
        expect(terminated_invoice.credit_notes_amount_cents).to eq(1_500)
      end
    end

    context "with updated fee with attached credit note" do
      let(:adjusted_fee_params) do
        {
          unit_precise_amount: "0.50",
          units: 18 # 50 x 18 = 900
        }
      end

      it "bills fees correctly" do
        travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
          create(
            :standard_charge,
            plan:,
            billable_metric: metric,
            pay_in_advance: false,
            prorated: true,
            properties: {amount: "1"}
          )

          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            }
          )
        end

        first_invoice = customer.invoices.draft.first

        expect(customer.credit_notes.count).to eq(0)
        expect(first_invoice.total_amount_cents).to eq(1_800)
        expect(first_invoice.fees_amount_cents).to eq(1_800)

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-12T21:00:00")) do
          expect {
            terminate_subscription(subscription)
            perform_all_enqueued_jobs
          }.to change { subscription.reload.status }.from("active").to("terminated")
            .and change { customer.invoices.count }.from(1).to(2)

          first_invoice = first_invoice.reload

          expect(customer.credit_notes.count).to eq(1)
          credit_note = customer.credit_notes.first

          expect(credit_note.credit_amount_cents).to eq(1_700)
          expect(credit_note.balance_amount_cents).to eq(1_700)
          expect(first_invoice.total_amount_cents).to eq(1_800)
          expect(first_invoice.fees_amount_cents).to eq(1_800)
          expect(first_invoice.credit_notes_amount_cents).to eq(0)

          # There is only one fee that is subscription kind
          fee = first_invoice.fees.subscription.first

          AdjustedFees::CreateService.call(invoice: first_invoice, params: adjusted_fee_params.merge(fee_id: fee.id))
          credit_note = credit_note.reload
          first_invoice = first_invoice.reload

          expect(credit_note.credit_amount_cents).to eq(850)
          expect(credit_note.balance_amount_cents).to eq(850)
          expect(first_invoice.total_amount_cents).to eq(900)
          expect(first_invoice.fees_amount_cents).to eq(900)
          expect(first_invoice.credit_notes_amount_cents).to eq(0)

          terminated_invoice = subscription.invoices.order(created_at: :desc).first
          credit_note = customer.credit_notes.first

          # credit notes are not applied on draft invoice
          expect(credit_note.credit_amount_cents).to eq(850)
          expect(credit_note.balance_amount_cents).to eq(850)
          expect(terminated_invoice.total_amount_cents).to eq(0) # There are no charges in a period
          expect(terminated_invoice.fees_amount_cents).to eq(0)
          expect(terminated_invoice.credit_notes_amount_cents).to eq(0)
        end
      end
    end

    context "with updated fee equal to zero" do
      let(:adjusted_fee_params) do
        {
          unit_precise_amount: 0,
          units: 1
        }
      end

      it "bills fees correctly" do
        travel_to(Time.zone.parse("2024-02-12 06:00:00")) do
          create(
            :standard_charge,
            plan:,
            billable_metric: metric,
            pay_in_advance: false,
            prorated: true,
            properties: {amount: "1"}
          )

          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar"
            }
          )
        end

        first_invoice = customer.invoices.draft.first

        expect(customer.credit_notes.count).to eq(0)
        expect(first_invoice.total_amount_cents).to eq(1_800)
        expect(first_invoice.fees_amount_cents).to eq(1_800)

        subscription = customer.subscriptions.first

        travel_to(Time.zone.parse("2024-02-12T21:00:00")) do
          expect {
            terminate_subscription(subscription)
            perform_all_enqueued_jobs
          }.to change { subscription.reload.status }.from("active").to("terminated")
            .and change { customer.invoices.count }.from(1).to(2)

          first_invoice = first_invoice.reload

          expect(customer.credit_notes.count).to eq(1)
          credit_note = customer.credit_notes.first

          expect(credit_note.credit_amount_cents).to eq(1_700)
          expect(credit_note.balance_amount_cents).to eq(1_700)
          expect(first_invoice.total_amount_cents).to eq(1_800)
          expect(first_invoice.fees_amount_cents).to eq(1_800)
          expect(first_invoice.credit_notes_amount_cents).to eq(0)

          # There is only one fee that is subscription kind
          fee = first_invoice.fees.subscription.first

          AdjustedFees::CreateService.call(invoice: first_invoice, params: adjusted_fee_params.merge(fee_id: fee.id))
          credit_note = credit_note.reload
          first_invoice = first_invoice.reload

          expect(credit_note.credit_amount_cents).to eq(0)
          expect(credit_note.balance_amount_cents).to eq(0)
          expect(first_invoice.total_amount_cents).to eq(0)
          expect(first_invoice.fees_amount_cents).to eq(0)
          expect(first_invoice.credit_notes_amount_cents).to eq(0)

          terminated_invoice = subscription.invoices.order(created_at: :desc).first
          credit_note = customer.credit_notes.first

          # credit notes are not applied on draft invoice
          expect(credit_note.credit_amount_cents).to eq(0)
          expect(credit_note.balance_amount_cents).to eq(0)
          expect(terminated_invoice.total_amount_cents).to eq(0) # There are no charges in a period
          expect(terminated_invoice.fees_amount_cents).to eq(0)
          expect(terminated_invoice.credit_notes_amount_cents).to eq(0)
        end
      end
    end
  end

  context "when pay in arrear subscription is terminated" do
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:, amount_cents: 2_900, pay_in_advance: false) }
    let(:plan_new) { create(:plan, organization:, amount_cents: 29_000, pay_in_advance: false) }
    let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 0) }
    let(:metric) do
      create(:billable_metric, organization:, aggregation_type: "sum_agg", recurring: true, field_name: "amount")
    end

    it "bills fees correctly", transaction: false do
      travel_to(Time.zone.parse("2024-01-01T00:00:00")) do
        create(
          :standard_charge,
          plan:,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create(
          :standard_charge,
          plan: plan_new,
          billable_metric: metric,
          pay_in_advance: false,
          prorated: true,
          properties: {amount: "1"}
        )

        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      subscription = customer.subscriptions.first

      travel_to(Time.zone.parse("2024-01-02T00:00:00")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            properties: {amount: "5"}
          }
        )
      end

      travel_to(Time.zone.parse("2024-02-12T06:00:00")) do
        expect {
          terminate_subscription(subscription)
          perform_all_enqueued_jobs
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { customer.invoices.count }.from(0).to(1)

        terminated_invoice = subscription.invoices.order(created_at: :desc).first

        expect(terminated_invoice.total_amount_cents).to eq((1_200 + (12.fdiv(29) * 500)).round) # 12 + 12/29 x 5
      end
    end
  end

  context "when invoice is paid in advance and grace period" do
    let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
    let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 1000) }
    let(:metric) { create(:billable_metric, organization:) }

    it "terminates the pay in advance subscription with credit note lesser than amount" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "3"})
      end

      subscription_invoice = Invoice.draft.first
      subscription = subscription_invoice.subscriptions.first
      expect(subscription_invoice.total_amount_cents).to eq(658) # 17 days - From 15th Dec. to 31st Dec.

      ### 17 Dec: Create event + refresh.
      travel_to(Time.zone.parse("2022-12-17")) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: metric.code
        )
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: metric.code
        )

        expect {
          refresh_invoice(subscription_invoice)
        }.not_to change { subscription_invoice.reload.total_amount_cents }
      end

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription_invoice.reload.credit_notes.count }.from(0).to(1)
          .and change { subscription.invoices.count }.from(1).to(2)

        # Draft credit note is created (31 - 20) * 548 / 17.0 * 1.2 = 425.5 rounded at 426
        credit_note = subscription_invoice.credit_notes.first
        expect(credit_note).to be_draft
        expect(credit_note.credit_amount_cents).to eq(426)
        expect(credit_note.balance_amount_cents).to eq(426)
        expect(credit_note.total_amount_cents).to eq(426)

        # Invoice for termination is created
        termination_invoice = subscription.invoices.order(created_at: :desc).first

        # Total amount does not reflect the credit note as it's not finalized.
        expect(termination_invoice.total_amount_cents).to eq(720)
        expect(termination_invoice.credits.count).to eq(0)
        expect(termination_invoice.credit_notes.count).to eq(0)

        # Refresh pay in advance invoice
        expect {
          refresh_invoice(subscription_invoice)
        }.not_to change { subscription_invoice.reload.total_amount_cents }
        expect(credit_note.reload.total_amount_cents).to eq(426)

        # Refresh termination invoice
        expect {
          refresh_invoice(termination_invoice)
        }.not_to change { termination_invoice.reload.total_amount_cents }

        # Finalize pay in advance invoice
        expect {
          finalize_invoice(subscription_invoice)
        }.to change { subscription_invoice.reload.status }.from("draft").to("finalized")
          .and change { credit_note.reload.status }.from("draft").to("finalized")

        expect(subscription_invoice.total_amount_cents).to eq(658)

        # Finalize termination invoice
        expect {
          finalize_invoice(termination_invoice)
        }.to change { termination_invoice.reload.status }.from("draft").to("finalized")

        # Total amount should reflect the credit note 720 - 426
        expect(termination_invoice.total_amount_cents).to eq(294)
      end
    end

    it "terminates the pay in advance subscription with credit note greater than amount" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            customer:
          }
        )

        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "1"})
      end

      subscription_invoice = Invoice.draft.first
      subscription = subscription_invoice.subscriptions.sole
      expect(subscription_invoice.total_amount_cents).to eq(658) # 17 days - From 15th Dec. to 31st Dec.

      ### 17 Dec: Create event + refresh.
      travel_to(Time.zone.parse("2022-12-17")) do
        create(
          :event,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: metric.code
        )

        expect {
          refresh_invoice(subscription_invoice)
        }.not_to change { subscription_invoice.reload.total_amount_cents }
      end

      ### 20 Dec: Terminate subscription + refresh.
      dec20 = Time.zone.parse("2022-12-20")

      travel_to(dec20) do
        expect {
          terminate_subscription(subscription)
        }.to change { subscription.reload.status }.from("active").to("terminated")
          .and change { subscription_invoice.reload.credit_notes.count }.from(0).to(1)
          .and change { subscription.invoices.count }.from(1).to(2)

        # Credit note is created (31 - 20) * 548 / 17.0 * 1.2 = 425.5 rounded at 426
        credit_note = subscription_invoice.reload.credit_notes.first
        expect(credit_note.credit_amount_cents).to eq(426)
        expect(credit_note.balance_amount_cents).to eq(426)
        expect(credit_note.total_amount_cents).to eq(426)

        # Invoice for termination is created
        termination_invoice = subscription.invoices.order(created_at: :desc).first

        # Total amount does not reflect the credit note as it's not finalized.
        expect(termination_invoice.total_amount_cents).to eq(120)
        expect(termination_invoice.credits.count).to eq(0)
        expect(termination_invoice.credit_notes.count).to eq(0)

        # Refresh pay in advance invoice
        expect {
          refresh_invoice(subscription_invoice)
        }.not_to change { subscription_invoice.reload.total_amount_cents }
        expect(credit_note.reload.credit_amount_cents).to eq(426)

        # Refresh termination invoice
        expect {
          refresh_invoice(termination_invoice)
        }.not_to change { termination_invoice.reload.total_amount_cents }

        # Finalize pay in advance invoice
        expect {
          finalize_invoice(subscription_invoice)
        }.to change { subscription_invoice.reload.status }.from("draft").to("finalized")
          .and change { credit_note.reload.status }.from("draft").to("finalized")

        expect(subscription_invoice.total_amount_cents).to eq(658)

        # Finalize termination invoice
        expect {
          finalize_invoice(termination_invoice)
        }.to change { termination_invoice.reload.status }.from("draft").to("finalized")

        # Total amount should reflect the credit note (120 - 425)
        expect(termination_invoice.total_amount_cents).to eq(0)
      end
    end

    it "refreshes and finalizes invoices" do
      ### 15 Dec: Create subscription + charge.
      dec15 = Time.zone.parse("2022-12-15")

      travel_to(dec15) do
        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "1"})
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            customer:
          }
        )
      end

      invoice = Invoice.draft.first
      subscription = invoice.subscriptions.first
      expect(invoice.total_amount_cents).to eq(658) # 17 days - From 15th Dec. to 31st Dec.

      ### 16 Dec: Create event + refresh.
      travel_to(Time.zone.parse("2022-12-16")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id
          }
        )

        # Paid in advance invoice amount does not change.
        expect {
          refresh_invoice(invoice)
        }.not_to change { invoice.reload.total_amount_cents }
      end

      ### 17 Dec: Create event + refresh.
      travel_to(Time.zone.parse("2022-12-17")) do
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id
          }
        )

        # Paid in advance invoice amount does not change.
        expect {
          refresh_invoice(invoice)
        }.not_to change { invoice.reload.total_amount_cents }
      end

      ### 1 Jan: Billing + refresh + finalize.
      travel_to(Time.zone.parse("2023-01-01")) do
        perform_billing

        expect(subscription.invoices.count).to eq(2)
        new_invoice = subscription.invoices.order(created_at: :desc).first
        expect(new_invoice.total_amount_cents).to eq(1440) # (1000 + 200) * 1.2

        # Create event for Dec 18.
        create_event(
          {
            code: metric.code,
            transaction_id: SecureRandom.uuid,
            timestamp: Time.zone.parse("2022-12-18").to_i,
            organization_id: organization.id,
            external_subscription_id: subscription.external_id
          }
        )

        # Paid in advance invoice amount does not change.
        expect {
          refresh_invoice(invoice)
        }.not_to change { invoice.reload.total_amount_cents }

        # Usage invoice amount is updated.
        expect {
          refresh_invoice(new_invoice)
        }.to change { new_invoice.reload.total_amount_cents }.from(1440).to(1560) # (1000 + 200 + 100) * 1.2

        # Finalize invoices.
        expect {
          finalize_invoice(invoice)
        }.to change { invoice.reload.status }.from("draft").to("finalized")

        expect {
          finalize_invoice(new_invoice)
        }.to change { new_invoice.reload.status }.from("draft").to("finalized")

        expect(invoice.total_amount_cents).to eq(658)
        expect(new_invoice.total_amount_cents).to eq(1560)
      end
    end

    context "when upgrading from pay in arrear to pay in advance plan" do
      let(:pay_in_arrear_plan) { create(:plan, organization:, amount_cents: 1000) }
      let(:pay_in_advance_plan) { create(:plan, organization:, pay_in_advance: true, amount_cents: 1000) }

      it "creates two draft invoices" do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: pay_in_arrear_plan.code
          }
        )

        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "1"})

        # Upgrade to pay in advance plan
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: pay_in_advance_plan.code
          }
        )

        expect(customer.invoices.draft.count).to eq(1)

        pay_in_arrear_subscription = customer.subscriptions.terminated.first
        pay_in_arrear_invoice = pay_in_arrear_subscription.invoices.first

        # Paid in advance invoice amount does not change.
        expect {
          refresh_invoice(pay_in_arrear_invoice)
        }.not_to change { pay_in_arrear_invoice.reload.total_amount_cents }
      end
    end

    context "when invoice grace period is removed", :premium do
      let(:organization) { create(:organization, webhook_url: nil, invoice_grace_period: 3) }
      let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 1000) }

      it "finalizes draft invoices" do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code
          }
        )

        create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "1"})

        invoice = Invoice.draft.first

        params = {
          external_id: customer.external_id,
          billing_configuration: {invoice_grace_period: 0}
        }

        expect {
          create_or_update_customer(params)
        }.to change { customer.reload.invoice_grace_period }.from(3).to(0)
          .and change { invoice.reload.status }.from("draft").to("finalized")
      end
    end
  end
end
