# frozen_string_literal: true

require "rails_helper"

RSpec.describe "templates/invoices/v4/fixed_charge.slim" do
  subject(:rendered_template) do
    Slim::Template.new(template, 1, pretty: true).render(invoice)
  end

  let(:template) { Rails.root.join("app/views/templates/invoices/v4/fixed_charge.slim") }

  let(:organization) { create(:organization, :with_static_values) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, :with_static_values, organization:) }
  let(:add_on) { create(:add_on, organization:) }

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
    create(:subscription, customer:, plan:, status: "active")
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      number: "LAGO-202509-FC-001",
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
      fixed_charges_from_datetime: Time.zone.parse("2025-09-01 00:00:00"),
      fixed_charges_to_datetime: Time.zone.parse("2025-09-30 23:59:59"),
      timestamp: Time.zone.parse("2025-09-01 00:00:00")
    )
  end

  before do
    I18n.locale = :en
    invoice_subscription
  end

  context "with a single fixed charge fee" do
    let(:fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Standard Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    before { fixed_charge_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with multiple fixed charge fees in different billing periods" do
    let(:fixed_charge_1) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_2) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:september_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: fixed_charge_1,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "September Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:october_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: fixed_charge_2,
        subscription:,
        pay_in_advance: true,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 3000,
        precise_unit_amount: 30.00,
        invoice_display_name: "October Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-10-01 00:00:00",
          fixed_charges_to_datetime: "2025-10-31 23:59:59"
        }
      )
    end

    before do
      september_fee
      october_fee
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with multiple fixed charge fees in the same billing period" do
    let(:fixed_charge_1) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_2) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_fee_1) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: fixed_charge_1,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Fixed Charge A",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:fixed_charge_fee_2) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: fixed_charge_2,
        subscription:,
        pay_in_advance: true,
        amount_cents: 3000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 3000,
        precise_unit_amount: 30.00,
        invoice_display_name: "Fixed Charge B",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    before do
      fixed_charge_fee_1
      fixed_charge_fee_2
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with graduated charge model" do
    let(:graduated_fixed_charge) do
      create(:fixed_charge, :graduated, :pay_in_advance, plan:, add_on:)
    end

    let(:graduated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: graduated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 55500,
        amount_currency: "USD",
        units: 15,
        unit_amount_cents: 3700,
        precise_unit_amount: 37.00,
        invoice_display_name: "Graduated Fixed Charge",
        amount_details: {
          "graduated_ranges" => [
            {
              "from_value" => 0,
              "to_value" => 10,
              "units" => 10.0,
              "per_unit_amount" => "5.0",
              "per_unit_total_amount" => "50.0",
              "flat_unit_amount" => "200.0"
            },
            {
              "from_value" => 11,
              "to_value" => nil,
              "units" => 5.0,
              "per_unit_amount" => "1.0",
              "per_unit_total_amount" => "5.0",
              "flat_unit_amount" => "300.0"
            }
          ]
        },
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    before { graduated_fixed_charge_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with prorated fixed charge" do
    let(:prorated_fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:, prorated: true)
    end

    let(:prorated_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: prorated_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 2500,
        amount_currency: "USD",
        units: 0.5,
        unit_amount_cents: 5000,
        precise_unit_amount: 50.00,
        invoice_display_name: "Prorated Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    before { prorated_fixed_charge_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end

    it "displays the proration caption without referring to usage" do
      expect(rendered_template).to include("The fee is prorated for the period; the displayed unit price is an average")
      expect(rendered_template).not_to include("prorated on days of usage")
    end
  end

  context "with zero amount fee" do
    let(:zero_fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:zero_fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge: zero_fixed_charge,
        subscription:,
        pay_in_advance: true,
        amount_cents: 0,
        amount_currency: "USD",
        units: 0,
        unit_amount_cents: 0,
        precise_unit_amount: 0.00,
        invoice_display_name: "Zero Amount Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    before { zero_fixed_charge_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with coupon applied" do
    let(:fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Fixed Charge with Coupon",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
        }
      )
    end

    let(:coupon) { create(:coupon, organization:, name: "10% Off Coupon") }
    let(:applied_coupon) { create(:applied_coupon, coupon:, customer:) }
    let(:credit) do
      create(
        :credit,
        invoice:,
        applied_coupon:,
        amount_cents: 500,
        amount_currency: "USD"
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-FC-002",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :subscription,
        total_amount_cents: 4500,
        currency: "USD",
        fees_amount_cents: 5000,
        coupons_amount_cents: 500,
        sub_total_excluding_taxes_amount_cents: 4500,
        sub_total_including_taxes_amount_cents: 4500
      )
    end

    before do
      fixed_charge_fee
      credit
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with prepaid credits" do
    let(:fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:)
    end

    let(:fixed_charge_fee) do
      create(
        :fixed_charge_fee,
        invoice:,
        fixed_charge:,
        subscription:,
        pay_in_advance: true,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        precise_unit_amount: 25.00,
        invoice_display_name: "Fixed Charge",
        properties: {
          fixed_charges_from_datetime: "2025-09-01 00:00:00",
          fixed_charges_to_datetime: "2025-09-30 23:59:59"
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
        number: "LAGO-202509-FC-003",
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
      fixed_charge_fee
      wallet_transaction
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end
end
