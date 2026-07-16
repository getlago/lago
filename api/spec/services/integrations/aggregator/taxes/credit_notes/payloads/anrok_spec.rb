# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::CreditNotes::Payloads::Anrok do
  describe "#body" do
    subject(:payload) { described_class.new(integration:, customer:, integration_customer:, credit_note:).body }

    it_behaves_like "an integration payload", :anrok do
      def build_expected_payload(mapping_codes)
        [
          {
            "id" => "cn_#{credit_note.id}",
            "issuing_date" => credit_note.issuing_date,
            "currency" => credit_note.currency,
            "contact" => {
              "external_id" => integration_customer.external_customer_id,
              "name" => customer.name,
              "address_line_1" => customer.address_line1,
              "city" => customer.city,
              "zip" => customer.zipcode,
              "country" => customer.country,
              "taxable" => false,
              "tax_number" => nil
            },
            "fees" => match_array([
              {
                "item_id" => add_on.id,
                "amount_cents" => -190,
                "item_code" => mapping_codes.dig(:add_on, :external_id)
              },
              {
                "item_id" => fixed_charge_add_on.id,
                "amount_cents" => -140,
                "item_code" => mapping_codes.dig(:fixed_charge, :external_id)
              },
              {
                "item_id" => billable_metric.id,
                "amount_cents" => -180,
                "item_code" => mapping_codes.dig(:billable_metric, :external_id)
              },
              {
                "item_id" => subscription.id,
                "amount_cents" => -170,
                "item_code" => mapping_codes.dig(:minimum_commitment, :external_id)
              },
              {
                "item_id" => subscription.id,
                "amount_cents" => -160,
                "item_code" => mapping_codes.dig(:subscription, :external_id)
              }
            ]),
            "tax_date" => credit_note.invoice.issuing_date
          }
        ]
      end
    end

    context "with precision edge case" do
      let(:integration) { create(:anrok_integration) }
      let(:customer) { create(:customer, organization: integration.organization) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
      let(:credit_note) { create(:credit_note, customer:) }
      let(:fee) { create(:charge_fee, invoice: credit_note.invoice, amount_cents: 167, precise_amount_cents: 166.666666666) }
      let(:credit_note_item) { create(:credit_note_item, credit_note:, fee:, amount_cents: 100, precise_amount_cents: 100) }
      let(:billable_metric) { fee.charge.billable_metric }
      let(:items_relation) { double }

      before do
        billable_metric
        credit_note_item
        integration_customer

        create(
          :anrok_mapping,
          integration:,
          mappable_type: "BillableMetric",
          mappable_id: billable_metric.id,
          settings: {external_id: "ext_123"}
        )

        allow(credit_note_item).to receive(:sub_total_excluding_taxes_amount_cents).and_return(99.9999)
        allow(credit_note).to receive(:items).and_return(items_relation)
        allow(items_relation).to receive(:order).with(created_at: :asc).and_return([credit_note_item])
      end

      it "rounds credit note item amounts correctly" do
        payload = described_class.new(integration:, customer:, integration_customer:, credit_note:).body

        expect(payload.first["fees"].first["amount_cents"]).to eq(-100)
      end
    end

    describe "shipping address fallback" do
      let(:integration) { create(:anrok_integration) }
      let(:customer) do
        create(
          :customer,
          organization: integration.organization,
          address_line1: "Billing 1",
          city: "Billing City",
          zipcode: "12345",
          country: "FR",
          shipping_address_line1:,
          shipping_city:,
          shipping_zipcode:,
          shipping_country:
        )
      end
      let(:integration_customer) { create(:anrok_customer, customer:, integration:) }
      let(:credit_note) { create(:credit_note, customer:) }
      let(:contact) do
        described_class.new(integration:, customer:, integration_customer:, credit_note:).body.sole["contact"]
      end

      context "when shipping fields are empty strings" do
        let(:shipping_address_line1) { "" }
        let(:shipping_city) { "" }
        let(:shipping_zipcode) { "" }
        let(:shipping_country) { "" }

        it "falls back to billing address values" do
          expect(contact).to include(
            "address_line_1" => "Billing 1",
            "city" => "Billing City",
            "zip" => "12345",
            "country" => "FR"
          )
        end
      end

      context "when shipping fields are nil" do
        let(:shipping_address_line1) { nil }
        let(:shipping_city) { nil }
        let(:shipping_zipcode) { nil }
        let(:shipping_country) { nil }

        it "falls back to billing address values" do
          expect(contact).to include(
            "address_line_1" => "Billing 1",
            "city" => "Billing City",
            "zip" => "12345",
            "country" => "FR"
          )
        end
      end

      context "when shipping fields are populated" do
        let(:shipping_address_line1) { "Shipping 1" }
        let(:shipping_city) { "Shipping City" }
        let(:shipping_zipcode) { "67890" }
        let(:shipping_country) { "US" }

        it "uses shipping values over billing" do
          expect(contact).to include(
            "address_line_1" => "Shipping 1",
            "city" => "Shipping City",
            "zip" => "67890",
            "country" => "US"
          )
        end
      end
    end
  end
end
