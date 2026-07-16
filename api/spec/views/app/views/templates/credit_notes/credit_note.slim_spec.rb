# frozen_string_literal: true

require "rails_helper"

# This spec relies on `rspec-snapshot` gem (https://github.com/levinmr/rspec-snapshot) in order to serialize and compare
# the rendered invoice HTML.
#
# To update a snapshot, either delete it, or run the tests with `UPDATE_SNAPSHOTS=true` environment variable.

RSpec.describe "templates/credit_notes/credit_note.slim" do
  subject(:rendered_template) do
    Slim::Template.new(template, 1, pretty: true).render(credit_note)
  end

  let(:template) { Rails.root.join("app/views/templates/credit_notes/credit_note.slim") }

  let(:organization) { build_stubbed(:organization, :with_static_values) }
  let(:billing_entity) { build_stubbed(:billing_entity, :with_static_values, organization:) }
  let(:customer) { build_stubbed(:customer, :with_static_values, organization:) }

  let(:invoice) do
    build_stubbed(
      :invoice,
      organization:,
      billing_entity:,
      customer:,
      number: "LAGO-202509-001"
    )
  end

  let(:plan) { build_stubbed(:plan, organization:, name: "Premium Plan") }

  let(:subscription) do
    build_stubbed(
      :subscription,
      organization:,
      customer:,
      plan:,
      name: "Premium Plan"
    )
  end

  before do
    I18n.locale = :en

    # Stub through association (credit_note.billing_entity goes through invoice)
    allow(credit_note).to receive(:billing_entity).and_return(billing_entity)

    # Stub direct Subscription.find_by call in template
    allow(Subscription).to receive(:find_by).with(id: subscription.id).and_return(subscription)
  end

  context "with subscription fee, fixed charge fee, and charge fee" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-001",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 3000,
        taxes_amount_cents: 0,
        credit_amount_currency: "USD",
        credit_amount_cents: 3000,
        items: [subscription_fee_item, fixed_charge_item, charge_item]
      )
    end

    let(:subscription_fee_item) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: subscription_fee,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:subscription_fee) do
      build_stubbed(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:fixed_charge_item) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Setup Fee"
      )
    end

    let(:fixed_charge_fee) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge:,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:charge_item) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: charge_fee,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:charge) do
      build_stubbed(
        :standard_charge,
        plan:,
        invoice_display_name: "API Calls"
      )
    end

    let(:charge_fee) do
      build_stubbed(
        :charge_fee,
        invoice:,
        subscription:,
        charge:,
        amount_cents: 1000,
        amount_currency: "USD",
        units: 100
      )
    end

    before do
      # Stub subscription-related queries
      allow(credit_note).to receive(:subscription_ids).and_return([subscription.id])
      allow(credit_note).to receive(:subscription_item).with(subscription.id).and_return(subscription_fee_item)
      allow(credit_note).to receive(:subscription_fixed_charge_items).with(subscription.id).and_return([fixed_charge_item])

      # Create a mock relation for charge items that responds to .where()
      charge_items_relation = instance_double(ActiveRecord::Relation)
      allow(charge_items_relation).to receive(:where).and_return([charge_item])
      allow(credit_note).to receive(:subscription_charge_items).with(subscription.id).and_return(charge_items_relation)

      allow(credit_note).to receive(:add_on_items).and_return(CreditNoteItem.none)

      # Stub invoice_name methods (computed methods, not attributes)
      allow(fixed_charge_fee).to receive(:invoice_name).and_return("Setup Fee")
      allow(charge_fee).to receive(:invoice_name).and_return("API Calls")

      # Stub sub_total_excluding_taxes_amount (computed from items)
      allow(credit_note).to receive(:sub_total_excluding_taxes_amount).and_return(Money.new(3000, "USD"))
    end

    it "renders all fee types correctly" do
      expect(rendered_template).to match_html_snapshot("with_all_fee_types")
    end
  end

  context "with only fixed charge fees" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-002",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 2200,
        taxes_amount_cents: 200,
        credit_amount_currency: "USD",
        credit_amount_cents: 2200,
        items: [fixed_charge_item1, fixed_charge_item2]
      )
    end

    let(:fixed_charge_item1) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee1,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge_item2) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee2,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge1) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Setup Fee"
      )
    end

    let(:fixed_charge2) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Installation Fee"
      )
    end

    let(:fixed_charge_fee1) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge1,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:fixed_charge_fee2) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge2,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:tax) do
      build_stubbed(
        :tax,
        organization:,
        rate: 10.0,
        name: "VAT"
      )
    end

    let(:applied_tax) do
      build_stubbed(
        :credit_note_applied_tax,
        credit_note:,
        tax:,
        tax_name: "VAT",
        tax_code: "vat",
        tax_rate: 10.0,
        amount_cents: 200,
        amount_currency: "USD",
        base_amount_cents: 2000
      )
    end

    before do
      # Stub subscription-related queries
      allow(credit_note).to receive(:subscription_ids).and_return([subscription.id])
      allow(credit_note).to receive(:subscription_item).with(subscription.id).and_return(
        build_stubbed(:fee, amount_cents: 0, amount_currency: "USD")
      )
      allow(credit_note).to receive(:subscription_fixed_charge_items).with(subscription.id).and_return([fixed_charge_item1, fixed_charge_item2])
      allow(credit_note).to receive(:subscription_charge_items).with(subscription.id).and_return(CreditNoteItem.none)
      allow(credit_note).to receive(:add_on_items).and_return(CreditNoteItem.none)

      # Stub invoice_name methods
      allow(fixed_charge_fee1).to receive(:invoice_name).and_return("Setup Fee")
      allow(fixed_charge_fee2).to receive(:invoice_name).and_return("Installation Fee")

      # Stub applied_taxes for the credit note and items
      # The TaxHelper calls item.applied_taxes which calls credit_note.applied_taxes.where(...)
      # Then it calls .order().pluck() on the result
      item_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(item_applied_taxes).to receive(:order).with(tax_rate: :desc).and_return(item_applied_taxes)
      allow(item_applied_taxes).to receive(:pluck).with(:tax_rate).and_return([10.0])
      allow(item_applied_taxes).to receive(:present?).and_return(true)

      applied_taxes_relation = instance_double(ActiveRecord::Relation)
      allow(applied_taxes_relation).to receive(:where).and_return(item_applied_taxes)
      allow(applied_taxes_relation).to receive(:order).with(tax_rate: :desc).and_return([applied_tax])
      allow(applied_taxes_relation).to receive(:present?).and_return(true)
      allow(credit_note).to receive(:applied_taxes).and_return(applied_taxes_relation)

      # Stub applied_taxes on fees (returns empty for the select query)
      fee_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(fee_applied_taxes).to receive(:select).and_return([])
      allow(fixed_charge_fee1).to receive(:applied_taxes).and_return(fee_applied_taxes)
      allow(fixed_charge_fee2).to receive(:applied_taxes).and_return(fee_applied_taxes)

      # Stub sub_total_excluding_taxes_amount
      allow(credit_note).to receive(:sub_total_excluding_taxes_amount).and_return(Money.new(2000, "USD"))
    end

    it "renders each fixed charge fee separately" do
      expect(rendered_template).to match_html_snapshot("with_only_fixed_charges")
    end
  end

  context "with fixed charges having different tax rates" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-004",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 2300,
        taxes_amount_cents: 300,
        credit_amount_currency: "USD",
        credit_amount_cents: 2300,
        items: [fixed_charge_item1, fixed_charge_item2]
      )
    end

    let(:fixed_charge_item1) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee1,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge_item2) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee2,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge1) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Setup Fee"
      )
    end

    let(:fixed_charge2) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Installation Fee"
      )
    end

    let(:fixed_charge_fee1) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge1,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:fixed_charge_fee2) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge2,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:tax1) do
      build_stubbed(
        :tax,
        organization:,
        rate: 10.0,
        name: "VAT"
      )
    end

    let(:tax2) do
      build_stubbed(
        :tax,
        organization:,
        rate: 20.0,
        name: "Sales Tax"
      )
    end

    let(:applied_tax1) do
      build_stubbed(
        :credit_note_applied_tax,
        credit_note:,
        tax: tax1,
        tax_name: "VAT",
        tax_code: "vat",
        tax_rate: 10.0,
        amount_cents: 100,
        amount_currency: "USD",
        base_amount_cents: 1000
      )
    end

    let(:applied_tax2) do
      build_stubbed(
        :credit_note_applied_tax,
        credit_note:,
        tax: tax2,
        tax_name: "Sales Tax",
        tax_code: "sales_tax",
        tax_rate: 20.0,
        amount_cents: 200,
        amount_currency: "USD",
        base_amount_cents: 1000
      )
    end

    before do
      # Stub subscription-related queries
      allow(credit_note).to receive(:subscription_ids).and_return([subscription.id])
      allow(credit_note).to receive(:subscription_item).with(subscription.id).and_return(
        build_stubbed(:fee, amount_cents: 0, amount_currency: "USD")
      )
      allow(credit_note).to receive(:subscription_fixed_charge_items).with(subscription.id).and_return([fixed_charge_item1, fixed_charge_item2])
      allow(credit_note).to receive(:subscription_charge_items).with(subscription.id).and_return(CreditNoteItem.none)
      allow(credit_note).to receive(:add_on_items).and_return(CreditNoteItem.none)

      # Stub invoice_name methods
      allow(fixed_charge_fee1).to receive(:invoice_name).and_return("Setup Fee")
      allow(fixed_charge_fee2).to receive(:invoice_name).and_return("Installation Fee")

      # Stub applied_taxes for items with different tax rates
      # Item 1 has 10% tax
      item1_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(item1_applied_taxes).to receive(:order).with(tax_rate: :desc).and_return(item1_applied_taxes)
      allow(item1_applied_taxes).to receive(:pluck).with(:tax_rate).and_return([10.0])
      allow(item1_applied_taxes).to receive(:present?).and_return(true)

      # Item 2 has 20% tax
      item2_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(item2_applied_taxes).to receive(:order).with(tax_rate: :desc).and_return(item2_applied_taxes)
      allow(item2_applied_taxes).to receive(:pluck).with(:tax_rate).and_return([20.0])
      allow(item2_applied_taxes).to receive(:present?).and_return(true)

      # Credit note applied_taxes returns different results based on item
      applied_taxes_relation = instance_double(ActiveRecord::Relation)
      allow(applied_taxes_relation).to receive(:where).and_return(item1_applied_taxes, item2_applied_taxes)
      allow(applied_taxes_relation).to receive(:order).with(tax_rate: :desc).and_return([applied_tax2, applied_tax1]) # Descending order: 20%, 10%
      allow(applied_taxes_relation).to receive(:present?).and_return(true)
      allow(credit_note).to receive(:applied_taxes).and_return(applied_taxes_relation)

      # Stub applied_taxes on fees
      fee_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(fee_applied_taxes).to receive(:select).and_return([])
      allow(fixed_charge_fee1).to receive(:applied_taxes).and_return(fee_applied_taxes)
      allow(fixed_charge_fee2).to receive(:applied_taxes).and_return(fee_applied_taxes)

      # Stub sub_total_excluding_taxes_amount
      allow(credit_note).to receive(:sub_total_excluding_taxes_amount).and_return(Money.new(2000, "USD"))
    end

    it "renders fixed charges with multiple tax rates in descending order" do
      expect(rendered_template).to match_html_snapshot("with_multiple_tax_rates")
    end
  end

  context "with fixed charges and coupon adjustment" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-005",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 1500,
        taxes_amount_cents: 0,
        credit_amount_currency: "USD",
        credit_amount_cents: 1500,
        coupons_adjustment_amount_cents: 500,
        items: [fixed_charge_item1, fixed_charge_item2]
      )
    end

    let(:fixed_charge_item1) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee1,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge_item2) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: fixed_charge_fee2,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:fixed_charge1) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Setup Fee"
      )
    end

    let(:fixed_charge2) do
      build_stubbed(
        :fixed_charge,
        plan:,
        invoice_display_name: "Onboarding Fee"
      )
    end

    let(:fixed_charge_fee1) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge1,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    let(:fixed_charge_fee2) do
      build_stubbed(
        :fixed_charge_fee,
        invoice:,
        subscription:,
        fixed_charge: fixed_charge2,
        amount_cents: 1000,
        amount_currency: "USD"
      )
    end

    before do
      # Stub subscription-related queries
      allow(credit_note).to receive(:subscription_ids).and_return([subscription.id])
      allow(credit_note).to receive(:subscription_item).with(subscription.id).and_return(
        build_stubbed(:fee, amount_cents: 0, amount_currency: "USD")
      )
      allow(credit_note).to receive(:subscription_fixed_charge_items).with(subscription.id).and_return([fixed_charge_item1, fixed_charge_item2])
      allow(credit_note).to receive(:subscription_charge_items).with(subscription.id).and_return(CreditNoteItem.none)
      allow(credit_note).to receive(:add_on_items).and_return(CreditNoteItem.none)

      # Stub invoice_name methods
      allow(fixed_charge_fee1).to receive(:invoice_name).and_return("Setup Fee")
      allow(fixed_charge_fee2).to receive(:invoice_name).and_return("Onboarding Fee")

      # Stub applied_taxes (no taxes in this scenario)
      item_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(item_applied_taxes).to receive(:order).with(tax_rate: :desc).and_return(item_applied_taxes)
      allow(item_applied_taxes).to receive(:pluck).with(:tax_rate).and_return([0.0])
      allow(item_applied_taxes).to receive(:present?).and_return(false)

      applied_taxes_relation = instance_double(ActiveRecord::Relation)
      allow(applied_taxes_relation).to receive(:where).and_return(item_applied_taxes)
      allow(applied_taxes_relation).to receive(:present?).and_return(false)
      allow(credit_note).to receive(:applied_taxes).and_return(applied_taxes_relation)

      # Stub applied_taxes on fees
      fee_applied_taxes = instance_double(ActiveRecord::Relation)
      allow(fee_applied_taxes).to receive(:select).and_return([])
      allow(fixed_charge_fee1).to receive(:applied_taxes).and_return(fee_applied_taxes)
      allow(fixed_charge_fee2).to receive(:applied_taxes).and_return(fee_applied_taxes)

      # Stub coupons_adjustment_amount for display
      allow(credit_note).to receive(:coupons_adjustment_amount).and_return(Money.new(500, "USD"))

      # Stub sub_total_excluding_taxes_amount (after coupon: $20 - $5 = $15)
      allow(credit_note).to receive(:sub_total_excluding_taxes_amount).and_return(Money.new(1500, "USD"))
    end

    it "renders fixed charges with coupon adjustment in totals" do
      expect(rendered_template).to match_html_snapshot("with_coupon_adjustment")
    end
  end

  context "with only charge fees" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-003",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 2500,
        taxes_amount_cents: 0,
        credit_amount_currency: "USD",
        credit_amount_cents: 2500,
        items: [charge_item1, charge_item2]
      )
    end

    let(:charge_item1) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: charge_fee1,
        amount_cents: 1500,
        amount_currency: "USD",
        precise_amount_cents: 1500
      )
    end

    let(:charge_item2) do
      build_stubbed(
        :credit_note_item,
        organization:,
        fee: charge_fee2,
        amount_cents: 1000,
        amount_currency: "USD",
        precise_amount_cents: 1000
      )
    end

    let(:charge1) do
      build_stubbed(
        :standard_charge,
        plan:,
        invoice_display_name: "API Calls"
      )
    end

    let(:charge2) do
      build_stubbed(
        :standard_charge,
        plan:,
        invoice_display_name: "Storage"
      )
    end

    let(:charge_fee1) do
      build_stubbed(
        :charge_fee,
        invoice:,
        subscription:,
        charge: charge1,
        fixed_charge: nil,
        amount_cents: 1500,
        amount_currency: "USD",
        units: 150
      )
    end

    let(:charge_fee2) do
      build_stubbed(
        :charge_fee,
        invoice:,
        subscription:,
        charge: charge2,
        fixed_charge: nil,
        amount_cents: 1000,
        amount_currency: "USD",
        units: 100
      )
    end

    before do
      # Stub subscription-related queries
      allow(credit_note).to receive(:subscription_ids).and_return([subscription.id])
      allow(credit_note).to receive(:subscription_item).with(subscription.id).and_return(
        build_stubbed(:fee, amount_cents: 0, amount_currency: "USD")
      )
      allow(credit_note).to receive(:subscription_fixed_charge_items).with(subscription.id).and_return([])

      # Create a mock relation for charge items that responds to .where()
      charge_items_relation = instance_double(ActiveRecord::Relation)
      allow(charge_items_relation).to receive(:where).and_return([charge_item1, charge_item2])
      allow(credit_note).to receive(:subscription_charge_items).with(subscription.id).and_return(charge_items_relation)

      allow(credit_note).to receive(:add_on_items).and_return(CreditNoteItem.none)

      # Stub invoice_name methods
      allow(charge_fee1).to receive(:invoice_name).and_return("API Calls")
      allow(charge_fee2).to receive(:invoice_name).and_return("Storage")

      # Stub sub_total_excluding_taxes_amount
      allow(credit_note).to receive(:sub_total_excluding_taxes_amount).and_return(Money.new(2500, "USD"))
    end

    it "renders each charge fee correctly" do
      expect(rendered_template).to match_html_snapshot("with_only_charges")
    end
  end

  context "with the inherited purchase order number" do
    let(:credit_note) do
      build_stubbed(
        :credit_note,
        organization:,
        customer:,
        invoice:,
        number: "CN-202510-099",
        issuing_date: Date.parse("2025-10-05"),
        total_amount_currency: "USD",
        total_amount_cents: 1000,
        taxes_amount_cents: 0,
        credit_amount_currency: "USD",
        credit_amount_cents: 1000,
        items: []
      )
    end

    context "when the invoice has a purchase order number" do
      let(:invoice) do
        build_stubbed(:invoice, organization:, billing_entity:, customer:, number: "LAGO-202509-001", purchase_order_number: "PO-12345")
      end

      it "renders the purchase order number from the invoice" do
        expect(rendered_template).to include(I18n.t("credit_note.purchase_order_number"))
        expect(rendered_template).to include("PO-12345")
      end
    end

    context "when the invoice has no purchase order number" do
      it "does not render the purchase order number row" do
        expect(rendered_template).not_to include(I18n.t("credit_note.purchase_order_number"))
      end
    end
  end
end
