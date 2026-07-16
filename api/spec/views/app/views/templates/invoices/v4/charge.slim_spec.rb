# frozen_string_literal: true

require "rails_helper"

RSpec.describe "templates/invoices/v4/charge.slim" do
  subject(:rendered_template) do
    Slim::Template.new(template, 1, pretty: true).render(invoice)
  end

  let(:template) { Rails.root.join("app/views/templates/invoices/v4/charge.slim") }

  let(:organization) { create(:organization, :with_static_values) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, :with_static_values, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }

  let(:plan) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      pay_in_advance: false,
      invoice_display_name: "Monthly Plan"
    )
  end

  let(:subscription) do
    create(
      :subscription,
      customer:,
      plan:,
      status: "active",
      started_at: Time.zone.parse("2025-09-01 00:00:00"),
      subscription_at: Time.zone.parse("2025-09-01 00:00:00"),
      billing_time: :calendar
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      number: "LAGO-202509-CH-001",
      payment_due_date: Date.parse("2025-09-15"),
      issuing_date: Date.parse("2025-09-01"),
      invoice_type: :subscription,
      total_amount_cents: 10000,
      currency: "USD",
      fees_amount_cents: 10000,
      sub_total_excluding_taxes_amount_cents: 10000,
      sub_total_including_taxes_amount_cents: 10000,
      coupons_amount_cents: 0
    )
  end

  let(:invoice_subscription) do
    create(
      :invoice_subscription,
      invoice:,
      subscription:,
      from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
      to_datetime: Time.zone.parse("2025-09-30 23:59:59"),
      charges_from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
      charges_to_datetime: Time.zone.parse("2025-09-30 23:59:59"),
      timestamp: Time.zone.parse("2025-09-01 00:00:00")
    )
  end

  before do
    I18n.locale = :en
    invoice_subscription
  end

  context "with a single standard charge fee" do
    let(:charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "API Calls",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { charge_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with multiple charge fees" do
    let(:charge_1) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_2) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_fee_1) do
      create(
        :charge_fee,
        invoice:,
        charge: charge_1,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "API Calls",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    let(:charge_fee_2) do
      create(
        :charge_fee,
        invoice:,
        charge: charge_2,
        subscription:,
        pay_in_advance: true,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 5,
        unit_amount_cents: 600,
        precise_unit_amount: 6.00,
        invoice_display_name: "Storage GB",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before do
      charge_fee_1
      charge_fee_2
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with percentage charge with basic rate" do
    let(:percentage_charge) do
      create(:percentage_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:percentage_fee) do
      create(
        :charge_fee,
        invoice:,
        charge: percentage_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5550,
        amount_currency: "USD",
        units: 100,
        unit_amount_cents: 55,
        precise_unit_amount: 0.555,
        invoice_display_name: "Transaction Fee",
        amount_details: {
          "paid_units" => "100",
          "rate" => "5.55",
          "per_unit_total_amount" => "55.50"
        },
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { percentage_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with percentage charge with detailed breakdown" do
    let(:percentage_charge) do
      create(:percentage_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:percentage_fee) do
      create(
        :charge_fee,
        invoice:,
        charge: percentage_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 7550,
        amount_currency: "USD",
        units: 100,
        events_count: 50,
        invoice_display_name: "Payment Processing Fee",
        amount_details: {
          "paid_units" => "100",
          "rate" => "5.55",
          "per_unit_total_amount" => "55.50",
          "fixed_fee_unit_amount" => "0.20",
          "fixed_fee_total_amount" => "20.00",
          "min_max_adjustment_total_amount" => "0.00",
          "per_transaction_min_amount" => "0.00",
          "per_transaction_max_amount" => "0.00"
        },
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { percentage_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with prorated charge" do
    let(:recurring_billable_metric) { create(:unique_count_billable_metric, :recurring, organization:) }

    let(:prorated_charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric: recurring_billable_metric, prorated: true)
    end

    let(:pay_in_advance_event) do
      create(
        :event,
        organization:,
        subscription:,
        customer:,
        code: recurring_billable_metric.code,
        timestamp: Time.zone.parse("2025-09-15 10:00:00")
      )
    end

    let(:prorated_fee) do
      create(
        :charge_fee,
        invoice:,
        charge: prorated_charge,
        subscription:,
        pay_in_advance: true,
        pay_in_advance_event_id: pay_in_advance_event.id,
        amount_cents: 2500,
        amount_currency: "USD",
        units: 5,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "Prorated Seats",
        properties: {
          "from_datetime" => "2025-09-15 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-15 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { prorated_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with non-invoiceable charge" do
    let(:non_invoiceable_charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:, invoiceable: false)
    end

    let(:non_invoiceable_fee) do
      create(
        :charge_fee,
        invoice:,
        charge: non_invoiceable_charge,
        subscription:,
        pay_in_advance: true,
        succeeded_at: Time.zone.parse("2025-09-05 10:30:00"),
        amount_cents: 1000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 1000,
        precise_unit_amount: 10.00,
        invoice_display_name: "One-time Setup",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { non_invoiceable_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with charge filter" do
    let(:charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_filter) do
      create(:charge_filter, charge:)
    end

    let(:filtered_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        charge_filter:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 2000,
        amount_currency: "USD",
        units: 4,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "Filtered Charge",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before { filtered_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with coupon applied" do
    let(:charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "Charge with Coupon",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    let(:coupon) { create(:coupon, organization:, name: "20% Discount") }
    let(:applied_coupon) { create(:applied_coupon, coupon:, customer:) }
    let(:credit) do
      create(
        :credit,
        invoice:,
        applied_coupon:,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-CH-002",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 4000,
        currency: "USD",
        fees_amount_cents: 5000,
        coupons_amount_cents: 1000,
        sub_total_excluding_taxes_amount_cents: 4000,
        sub_total_including_taxes_amount_cents: 4000
      )
    end

    before do
      charge_fee
      credit
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with taxes applied" do
    let(:charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:tax) { create(:tax, organization:, name: "VAT", rate: 20.0) }

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        taxes_amount_cents: 1000,
        invoice_display_name: "Taxable Charge",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-CH-003",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 6000,
        currency: "USD",
        fees_amount_cents: 5000,
        taxes_amount_cents: 1000,
        coupons_amount_cents: 0,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 6000
      )
    end

    let(:applied_tax) do
      create(
        :invoice_applied_tax,
        invoice:,
        tax:,
        tax_name: "VAT",
        tax_code: "vat",
        tax_rate: 20.0,
        amount_cents: 1000,
        amount_currency: "USD",
        taxable_base_amount_cents: 5000,
        fees_amount_cents: 5000
      )
    end

    before do
      charge_fee
      applied_tax
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with presentation breakdowns" do
    let(:charge) do
      create(
        :standard_charge,
        :pay_in_advance,
        plan:,
        billable_metric:,
        invoice_display_name: "API Calls",
        properties: {
          "amount" => "100",
          "presentation_group_keys" => [
            {"value" => "region", "options" => {"display_in_invoice" => true}},
            {"value" => "env", "options" => {"display_in_invoice" => true}}
          ]
        }
      )
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 100,
        unit_amount_cents: 100,
        precise_unit_amount: 1.00,
        invoice_display_name: "API Calls",
        grouped_by: {},
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    before do
      charge_fee
      create(:presentation_breakdown, fee: charge_fee, units: 60, presentation_by: {"region" => "us", "env" => "prod"})
      create(:presentation_breakdown, fee: charge_fee, units: 40, presentation_by: {"region" => "eu", "env" => "prod"})
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with prepaid credits" do
    let(:charge) do
      create(:standard_charge, :pay_in_advance, plan:, billable_metric:)
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 10,
        unit_amount_cents: 500,
        precise_unit_amount: 5.00,
        invoice_display_name: "API Calls",
        properties: {
          "from_datetime" => "2025-09-01 00:00:00",
          "to_datetime" => "2025-09-30 23:59:59",
          "charges_from_datetime" => "2025-09-01 00:00:00",
          "charges_to_datetime" => "2025-09-30 23:59:59"
        }
      )
    end

    let(:wallet) { create(:wallet, customer:) }
    let(:wallet_transaction) do
      create(:wallet_transaction, wallet:, invoice:, amount: 10, credit_amount: 10)
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-CH-004",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 4000,
        currency: "USD",
        fees_amount_cents: 5000,
        coupons_amount_cents: 0,
        sub_total_excluding_taxes_amount_cents: 5000,
        sub_total_including_taxes_amount_cents: 5000,
        prepaid_credit_amount_cents: 1000,
        prepaid_granted_credit_amount_cents: 400,
        prepaid_purchased_credit_amount_cents: 600
      )
    end

    before do
      charge_fee
      wallet_transaction
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end
end
