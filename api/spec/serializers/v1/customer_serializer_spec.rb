# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CustomerSerializer do
  subject(:serializer) do
    described_class.new(customer, root_name: "customer", includes: %i[taxes integration_customers applicable_invoice_custom_sections error_details])
  end

  let(:result) { JSON.parse(serializer.to_json) }
  let(:organization) { customer.organization }
  let(:billing_entity) { customer.billing_entity }
  let(:customer) { create(:customer, :with_salesforce_integration, shipping_city: "Paris", shipping_address_line1: "test1", shipping_zipcode: "002") }
  let(:metadata) { create(:customer_metadata, customer:) }
  let(:tax) { create(:tax, organization: customer.organization) }
  let(:customer_applied_tax) { create(:customer_applied_tax, customer:, tax:) }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

  let(:error_detail) { create(:error_detail, owner: customer) }

  before do
    metadata
    customer_applied_tax
    create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section:)
    error_detail
  end

  it "serializes the object" do
    expect(result["customer"]).to include(
      "lago_id" => customer.id,
      "billing_entity_code" => customer.billing_entity.code,
      "external_id" => customer.external_id,
      "account_type" => customer.account_type,
      "name" => customer.name,
      "firstname" => customer.firstname,
      "lastname" => customer.lastname,
      "customer_type" => customer.customer_type,
      "sequential_id" => customer.sequential_id,
      "slug" => customer.slug,
      "created_at" => customer.created_at.iso8601,
      "updated_at" => customer.updated_at.iso8601,
      "country" => customer.country,
      "address_line1" => customer.address_line1,
      "address_line2" => customer.address_line2,
      "state" => customer.state,
      "zipcode" => customer.zipcode,
      "email" => customer.email,
      "city" => customer.city,
      "url" => customer.url,
      "phone" => customer.phone,
      "logo_url" => customer.logo_url,
      "legal_name" => customer.legal_name,
      "legal_number" => customer.legal_number,
      "currency" => customer.currency,
      "timezone" => customer.timezone,
      "applicable_timezone" => customer.applicable_timezone,
      "net_payment_term" => customer.net_payment_term,
      "finalize_zero_amount_invoice" => customer.finalize_zero_amount_invoice,
      "tax_identification_number" => customer.tax_identification_number,
      "taxes" => customer.taxes.map { hash_including("lago_id" => it.id) },
      "integration_customers" => customer.integration_customers.map { hash_including("lago_id" => it.id) },
      "applicable_invoice_custom_sections" => customer.applicable_invoice_custom_sections.map do
        hash_including("lago_id" => it.id)
      end,
      "skip_invoice_custom_sections" => false,
      "billing_configuration" => {
        "payment_provider" => customer.payment_provider,
        "payment_provider_code" => customer.payment_provider_code,
        "invoice_grace_period" => customer.invoice_grace_period,
        "document_locale" => customer.document_locale,
        "subscription_invoice_issuing_date_anchor" => customer.subscription_invoice_issuing_date_anchor,
        "subscription_invoice_issuing_date_adjustment" => customer.subscription_invoice_issuing_date_adjustment
      },
      "shipping_address" => {
        "address_line1" => "test1",
        "address_line2" => nil,
        "city" => "Paris",
        "zipcode" => "002",
        "state" => nil,
        "country" => nil
      },
      "metadata" => [{
        "lago_id" => metadata.id,
        "key" => metadata.key,
        "value" => metadata.value,
        "display_in_invoice" => metadata.display_in_invoice,
        "created_at" => metadata.created_at.iso8601
      }],
      "error_details" => [
        {
          "lago_id" => error_detail.id,
          "error_code" => error_detail.error_code,
          "details" => error_detail.details
        }
      ]
    )
  end

  context "with a stripe customer" do
    let(:stripe_customer) { create(:stripe_customer, customer:) }

    before do
      stripe_customer
      customer.update!(payment_provider: "stripe")
    end

    it "serializes the object" do
      expect(result["customer"]["billing_configuration"]["provider_customer_id"]).to eq(stripe_customer.provider_customer_id)
      expect(result["customer"]["billing_configuration"]["provider_payment_methods"]).to eq(stripe_customer.provider_payment_methods)
    end
  end

  context "with a VIES check" do
    subject(:serializer) { described_class.new(customer, root_name: "customer", includes: %i[vies_check], vies_check: {custom_hash: "yes"}) }

    let(:customer) { create(:customer, :with_salesforce_integration, tax_identification_number: "IT12345678901") }

    it "adds vies_check to customer" do
      expect(result["customer"]["vies_check"]).to eq({"custom_hash" => "yes"})
    end
  end
end
