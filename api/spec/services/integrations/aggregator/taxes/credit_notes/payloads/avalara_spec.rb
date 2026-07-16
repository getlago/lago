# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::CreditNotes::Payloads::Avalara do
  subject(:payload) { described_class.new(integration:, customer:, integration_customer:, credit_note:).body }

  describe "shipping address fallback" do
    let(:integration) { create(:avalara_integration) }
    let(:customer) do
      create(
        :customer,
        organization: integration.organization,
        address_line1: "Billing 1",
        city: "Billing City",
        zipcode: "12345",
        state: "Billing State",
        country: "FR",
        shipping_address_line1:,
        shipping_city:,
        shipping_zipcode:,
        shipping_state:,
        shipping_country:
      )
    end
    let(:integration_customer) { create(:avalara_customer, customer:, integration:) }
    let(:credit_note) { create(:credit_note, customer:) }
    let(:contact) do
      described_class.new(integration:, customer:, integration_customer:, credit_note:).body.sole["contact"]
    end

    context "when shipping fields are empty strings" do
      let(:shipping_address_line1) { "" }
      let(:shipping_city) { "" }
      let(:shipping_zipcode) { "" }
      let(:shipping_state) { "" }
      let(:shipping_country) { "" }

      it "falls back to billing address values" do
        expect(contact).to include(
          "address_line_1" => "Billing 1",
          "city" => "Billing City",
          "zip" => "12345",
          "region" => "Billing State",
          "country" => "FR"
        )
      end
    end

    context "when shipping fields are nil" do
      let(:shipping_address_line1) { nil }
      let(:shipping_city) { nil }
      let(:shipping_zipcode) { nil }
      let(:shipping_state) { nil }
      let(:shipping_country) { nil }

      it "falls back to billing address values" do
        expect(contact).to include(
          "address_line_1" => "Billing 1",
          "city" => "Billing City",
          "zip" => "12345",
          "region" => "Billing State",
          "country" => "FR"
        )
      end
    end

    context "when shipping fields are populated" do
      let(:shipping_address_line1) { "Shipping 1" }
      let(:shipping_city) { "Shipping City" }
      let(:shipping_zipcode) { "67890" }
      let(:shipping_state) { "Shipping State" }
      let(:shipping_country) { "US" }

      it "uses shipping values over billing" do
        expect(contact).to include(
          "address_line_1" => "Shipping 1",
          "city" => "Shipping City",
          "zip" => "67890",
          "region" => "Shipping State",
          "country" => "US"
        )
      end
    end
  end

  it_behaves_like "an integration payload", :avalara do
    def build_expected_payload(mapping_codes)
      [
        {
          "id" => "cn_#{credit_note.id}",
          "type" => "returnInvoice",
          "issuing_date" => credit_note.issuing_date,
          "currency" => credit_note.currency,
          "contact" => {
            "external_id" => integration_customer&.external_customer_id || customer.external_id,
            "name" => customer.name,
            "address_line_1" => customer.shipping_address_line1 || customer.address_line1,
            "city" => customer.shipping_city || customer.city,
            "zip" => customer.shipping_zipcode || customer.zipcode,
            "region" => customer.shipping_state || customer.state,
            "country" => customer.shipping_country || customer.country,
            "taxable" => customer.tax_identification_number.present?,
            "tax_number" => customer.tax_identification_number
          },
          "billing_entity" => {
            "address_line_1" => customer.billing_entity.address_line1,
            "city" => customer.billing_entity.city,
            "zip" => customer.billing_entity.zipcode,
            "region" => customer.billing_entity.state,
            "country" => customer.billing_entity.country
          },
          "fees" => match_array([
            {
              "item_id" => add_on.id,
              "amount" => "-1.9",
              "unit" => 2.0,
              "item_code" => mapping_codes.dig(:add_on, :external_id)
            },
            {
              "item_id" => fixed_charge_add_on.id,
              "amount" => "-1.4",
              "unit" => 6.0,
              "item_code" => mapping_codes.dig(:fixed_charge, :external_id)
            },
            {
              "item_id" => billable_metric.id,
              "amount" => "-1.8",
              "unit" => 3.0,
              "item_code" => mapping_codes.dig(:billable_metric, :external_id)
            },
            {
              "item_id" => subscription.id,
              "amount" => "-1.7",
              "unit" => 4.0,
              "item_code" => mapping_codes.dig(:minimum_commitment, :external_id)
            },
            {
              "item_id" => subscription.id,
              "amount" => "-1.6",
              "unit" => 5.0,
              "item_code" => mapping_codes.dig(:subscription, :external_id)
            }
          ])
        }
      ]
    end
  end
end
