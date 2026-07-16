# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Avalara do
  let(:integration) { create(:avalara_integration, company_id: "12345") }
  let(:integration_customer) { create(:avalara_customer, customer:, integration:, external_customer_id: "abc-12345") }
  let(:payload) { described_class.new(integration:, customer:, integration_customer:) }
  let(:name) { "#{firstname} #{lastname}" }
  let(:customer_name) { nil }
  let(:customer) do
    create(
      :customer,
      firstname:,
      lastname:,
      name: customer_name,
      shipping_address_line1: "123 Main St",
      address_line1: "456 Elm St",
      city: "Springfield",
      zipcode: "12345",
      country: "US",
      state: "IL",
      tax_identification_number: "123456789"
    )
  end

  describe "#create_body" do
    subject(:create_body_call) { payload.create_body }

    let(:payload_body) do
      [
        {
          "company_id" => integration.company_id.to_i,
          "external_id" => customer.id,
          "name" => name,
          "address_line_1" => customer.shipping_address_line1,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "tax_number" => customer.tax_identification_number
        }
      ]
    end

    context "when name, firstname and lastname are present" do
      let(:firstname) { "John" }
      let(:lastname) { "Doe" }
      let(:customer_name) { "Mark Doe" }
      let(:name) { customer.name }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when firstname and lastname are present" do
      let(:firstname) { "John" }
      let(:lastname) { "Doe" }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when both firstname and lastname are empty" do
      let(:firstname) { "" }
      let(:lastname) { "" }
      let(:name) { "" }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when lastname is blank" do
      let(:firstname) { "John" }
      let(:lastname) { "" }
      let(:name) { "John" }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    describe "shipping address fallback" do
      let(:firstname) { "John" }
      let(:lastname) { "Doe" }
      let(:customer) do
        create(
          :customer,
          firstname:,
          lastname:,
          address_line1: "Billing 1",
          city: "Billing City",
          zipcode: "12345",
          state: "Billing State",
          country: "FR",
          shipping_address_line1:,
          shipping_city:,
          shipping_zipcode:,
          shipping_state:,
          shipping_country:,
          tax_identification_number: "123456789"
        )
      end

      context "when shipping fields are empty strings" do
        let(:shipping_address_line1) { "" }
        let(:shipping_city) { "" }
        let(:shipping_zipcode) { "" }
        let(:shipping_state) { "" }
        let(:shipping_country) { "" }

        it "falls back to billing address values" do
          expect(subject.sole).to include(
            "address_line_1" => "Billing 1",
            "city" => "Billing City",
            "zip" => "12345",
            "state" => "Billing State",
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
          expect(subject.sole).to include(
            "address_line_1" => "Billing 1",
            "city" => "Billing City",
            "zip" => "12345",
            "state" => "Billing State",
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
          expect(subject.sole).to include(
            "address_line_1" => "Shipping 1",
            "city" => "Shipping City",
            "zip" => "67890",
            "state" => "Shipping State",
            "country" => "US"
          )
        end
      end
    end
  end

  describe "#update_body" do
    subject(:update_body_call) { payload.update_body }

    let(:payload_body) do
      [
        {
          "company_id" => integration.company_id.to_i,
          "external_id" => customer.id,
          "name" => name,
          "address_line_1" => customer.shipping_address_line1,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "tax_number" => customer.tax_identification_number
        }
      ]
    end

    context "when firstname and lastname are present" do
      let(:firstname) { "John" }
      let(:lastname) { "Doe" }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end
  end
end
