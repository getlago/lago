# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::BillingEntitySerializer do
  subject(:serializer) { described_class.new(billing_entity, root_name: "billing_entity", includes: includes_options) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:, phone: "+49 30 1234567") }
  let(:result) { JSON.parse(serializer.to_json) }
  let(:includes_options) { nil }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

  before do
    create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section:)
  end

  it "serializes the billing entity" do
    billing_entity_serialized = result["billing_entity"]

    expect(billing_entity_serialized.fetch("lago_id")).to eq(billing_entity.id)
    expect(billing_entity_serialized.fetch("code")).to eq(billing_entity.code)
    expect(billing_entity_serialized.fetch("name")).to eq(billing_entity.name)
    expect(billing_entity_serialized.fetch("default_currency")).to eq(billing_entity.default_currency)
    expect(billing_entity_serialized.fetch("created_at")).to eq(billing_entity.created_at.iso8601)
    expect(billing_entity_serialized.fetch("updated_at")).to eq(billing_entity.updated_at.iso8601)
    expect(billing_entity_serialized.fetch("country")).to eq(billing_entity.country)
    expect(billing_entity_serialized.fetch("address_line1")).to eq(billing_entity.address_line1)
    expect(billing_entity_serialized.fetch("address_line2")).to eq(billing_entity.address_line2)
    expect(billing_entity_serialized.fetch("phone")).to eq(billing_entity.phone)
    expect(billing_entity_serialized.fetch("city")).to eq(billing_entity.city)
    expect(billing_entity_serialized.fetch("state")).to eq(billing_entity.state)
    expect(billing_entity_serialized.fetch("zipcode")).to eq(billing_entity.zipcode)
    expect(billing_entity_serialized.fetch("email")).to eq(billing_entity.email)
    expect(billing_entity_serialized.fetch("einvoicing")).to eq(billing_entity.einvoicing)
    expect(billing_entity_serialized.fetch("legal_name")).to eq(billing_entity.legal_name)
    expect(billing_entity_serialized.fetch("legal_number")).to eq(billing_entity.legal_number)
    expect(billing_entity_serialized.fetch("timezone")).to eq(billing_entity.timezone)
    expect(billing_entity_serialized.fetch("net_payment_term")).to eq(billing_entity.net_payment_term)
    expect(billing_entity_serialized.fetch("email_settings")).to eq(billing_entity.email_settings)
    expect(billing_entity_serialized.fetch("document_numbering")).to eq(billing_entity.document_numbering)
    expect(billing_entity_serialized.fetch("document_number_prefix")).to eq(billing_entity.document_number_prefix)
    expect(billing_entity_serialized.fetch("tax_identification_number")).to eq(billing_entity.tax_identification_number)
    expect(billing_entity_serialized.fetch("finalize_zero_amount_invoice")).to eq(billing_entity.finalize_zero_amount_invoice)
    expect(billing_entity_serialized.fetch("invoice_footer")).to eq(billing_entity.invoice_footer)
    expect(billing_entity_serialized.fetch("invoice_grace_period")).to eq(billing_entity.invoice_grace_period)
    expect(billing_entity_serialized.fetch("subscription_invoice_issuing_date_adjustment")).to eq(billing_entity.subscription_invoice_issuing_date_adjustment)
    expect(billing_entity_serialized.fetch("subscription_invoice_issuing_date_anchor")).to eq(billing_entity.subscription_invoice_issuing_date_anchor)
    expect(billing_entity_serialized.fetch("document_locale")).to eq(billing_entity.document_locale)
    expect(billing_entity_serialized.fetch("is_default")).to eq(billing_entity.organization.default_billing_entity.id == billing_entity.id)
    expect(billing_entity_serialized.fetch("eu_tax_management")).to eq(billing_entity.eu_tax_management)
    expect(billing_entity_serialized.fetch("logo_url")).to eq(billing_entity.logo_url)
    expect(billing_entity_serialized["taxes"]).to be_nil
    expect(billing_entity_serialized["selected_invoice_custom_sections"]).to be_nil
  end

  context "when including invoice custom sections" do
    let(:includes_options) { [:selected_invoice_custom_sections] }

    it "serializes the applicable invoice custom sections" do
      billing_entity_serialized = result["billing_entity"]
      expect(billing_entity_serialized["selected_invoice_custom_sections"].count).to eq(1)
      expect(billing_entity_serialized["selected_invoice_custom_sections"].first.fetch("lago_id")).to eq(invoice_custom_section.id)
    end
  end

  context "when including taxes" do
    let(:includes_options) { [:taxes] }

    it "serializes the taxes" do
      billing_entity_serialized = result["billing_entity"]
      expect(billing_entity_serialized.fetch("taxes")).to be_empty
    end

    context "when billing entity has applied taxes" do
      let(:tax) { create(:tax) }
      let(:applied_tax) { create(:billing_entity_applied_tax, billing_entity:, tax:) }

      before { applied_tax }

      it "serializes the applied taxes" do
        billing_entity_serialized = result["billing_entity"]
        expect(billing_entity_serialized.fetch("taxes").count).to eq(1)

        serialized_tax = billing_entity_serialized.fetch("taxes").first
        expect(serialized_tax.fetch("lago_id")).to eq(tax.id)
        expect(serialized_tax.fetch("code")).to eq(tax.code)
        expect(serialized_tax.fetch("name")).to eq(tax.name)
        expect(serialized_tax.fetch("rate")).to eq(tax.rate)
        expect(serialized_tax.fetch("description")).to eq(tax.description)
        expect(serialized_tax.fetch("created_at")).to eq(tax.created_at.iso8601)
      end
    end
  end
end
