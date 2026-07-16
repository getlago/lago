# frozen_string_literal: true

require "rails_helper"

# This spec relies on `rspec-snapshot` gem (https://github.com/levinmr/rspec-snapshot) in order to serialize and compare
# the rendered invoice HTML.
#
# To update a snapshot, either delete it, or run the tests with `UPDATE_SNAPSHOTS=true` environment variable.

RSpec.describe "templates/invoices/v4/one_off.slim" do
  subject(:rendered_template) do
    Slim::Template.new(template, 1, pretty: true).render(invoice)
  end

  let(:template) { Rails.root.join("app/views/templates/invoices/v4/one_off.slim") }

  let(:organization) { create(:organization, :with_static_values) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, :with_static_values, organization:) }

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      number: "LAGO-202509-OO-001",
      payment_due_date: Date.parse("2025-09-15"),
      issuing_date: Date.parse("2025-09-01"),
      invoice_type: :one_off,
      total_amount_cents: 10000,
      currency: "USD",
      fees_amount_cents: 10000,
      sub_total_excluding_taxes_amount_cents: 10000,
      sub_total_including_taxes_amount_cents: 10000,
      coupons_amount_cents: 0
    )
  end

  before do
    I18n.locale = :en
  end

  context "with a single add-on fee" do
    let(:add_on) { create(:add_on, organization:, name: "Setup Fee", description: "One-time setup fee") }

    let(:add_on_fee) do
      create(
        :one_off_fee,
        invoice:,
        add_on:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 10000,
        invoice_display_name: "Setup Fee",
        description: "One-time setup fee"
      )
    end

    before { add_on_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with multiple add-on fees" do
    let(:add_on_1) { create(:add_on, organization:, name: "Setup Fee") }
    let(:add_on_2) { create(:add_on, organization:, name: "Training Fee") }

    let(:add_on_fee_1) do
      create(
        :one_off_fee,
        invoice:,
        add_on: add_on_1,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 5000,
        invoice_display_name: "Setup Fee",
        description: "Initial setup"
      )
    end

    let(:add_on_fee_2) do
      create(
        :one_off_fee,
        invoice:,
        add_on: add_on_2,
        amount_cents: 5000,
        amount_currency: "USD",
        units: 2,
        unit_amount_cents: 2500,
        invoice_display_name: "Training Session",
        description: "2 hours of training"
      )
    end

    before do
      add_on_fee_1
      add_on_fee_2
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with add-on fee with date range" do
    let(:add_on) { create(:add_on, organization:, name: "Monthly Support") }

    let(:add_on_fee) do
      create(
        :one_off_fee,
        invoice:,
        add_on:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 10000,
        invoice_display_name: "Premium Support",
        description: "Premium support package",
        properties: {
          "from_datetime" => "2025-09-01",
          "to_datetime" => "2025-09-30"
        }
      )
    end

    before { add_on_fee }

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with taxes applied" do
    let(:add_on) { create(:add_on, organization:, name: "Professional Services") }
    let(:tax) { create(:tax, organization:, name: "Sales Tax", rate: 10.0) }

    let(:add_on_fee) do
      create(
        :one_off_fee,
        invoice:,
        add_on:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 10000,
        taxes_amount_cents: 1000,
        invoice_display_name: "Professional Services"
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-OO-003",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :one_off,
        total_amount_cents: 11000,
        currency: "USD",
        fees_amount_cents: 10000,
        taxes_amount_cents: 1000,
        coupons_amount_cents: 0,
        sub_total_excluding_taxes_amount_cents: 10000,
        sub_total_including_taxes_amount_cents: 11000
      )
    end

    let(:applied_tax) do
      create(
        :invoice_applied_tax,
        invoice:,
        tax:,
        tax_name: "Sales Tax",
        tax_code: "sales_tax",
        tax_rate: 10.0,
        amount_cents: 1000,
        amount_currency: "USD",
        taxable_base_amount_cents: 10000,
        fees_amount_cents: 10000
      )
    end

    before do
      add_on_fee
      applied_tax
    end

    it "renders correctly" do
      expect(rendered_template).to match_html_snapshot
    end
  end

  context "with a purchase order number" do
    let(:add_on) { create(:add_on, organization:, name: "Setup Fee") }
    let(:add_on_fee) do
      create(
        :one_off_fee,
        invoice:,
        add_on:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 10000,
        invoice_display_name: "Setup Fee"
      )
    end

    let(:invoice) do
      create(
        :invoice,
        customer:,
        organization:,
        number: "LAGO-202509-OO-PO",
        payment_due_date: Date.parse("2025-09-15"),
        issuing_date: Date.parse("2025-09-01"),
        invoice_type: :one_off,
        total_amount_cents: 10000,
        currency: "USD",
        fees_amount_cents: 10000,
        sub_total_excluding_taxes_amount_cents: 10000,
        sub_total_including_taxes_amount_cents: 10000,
        coupons_amount_cents: 0,
        purchase_order_number: "PO-12345"
      )
    end

    before { add_on_fee }

    it "renders the purchase order number under the invoice number" do
      expect(rendered_template).to include("Purchase Order Number")
      expect(rendered_template).to include("PO-12345")
    end
  end

  context "without a purchase order number" do
    let(:add_on) { create(:add_on, organization:, name: "Setup Fee") }
    let(:add_on_fee) do
      create(
        :one_off_fee,
        invoice:,
        add_on:,
        amount_cents: 10000,
        amount_currency: "USD",
        units: 1,
        unit_amount_cents: 10000,
        invoice_display_name: "Setup Fee"
      )
    end

    before { add_on_fee }

    it "does not render the purchase order number row" do
      expect(rendered_template).not_to include("Purchase Order Number")
    end
  end
end
