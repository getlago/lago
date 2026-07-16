# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Hubspot do
  let(:integration) { integration_customer.integration }
  let(:integration_customer) { FactoryBot.create(:hubspot_customer, customer:) }
  let(:customer) { create(:customer, customer_type: "individual") }
  let(:payload) { described_class.new(integration:, customer:, integration_customer:) }
  let(:customer_link) { payload.__send__(:customer_url) }
  let(:website) { payload.__send__(:clean_url, customer.url) }

  describe "#create_body" do
    subject(:create_body_call) { payload.create_body }

    let(:payload_body) do
      {
        "properties" => {
          "email" => customer.email,
          "firstname" => customer.firstname,
          "lastname" => customer.lastname,
          "phone" => customer.phone,
          "company" => customer.legal_name,
          "website" => website,
          "lago_customer_id" => customer.id,
          "lago_customer_external_id" => customer.external_id,
          "lago_billing_email" => customer.email,
          "lago_customer_link" => customer_link
        }
      }
    end

    it "returns the payload body" do
      expect(subject).to eq payload_body
    end
  end

  describe "#update_body" do
    subject(:update_body_call) { payload.update_body }

    let(:payload_body) do
      {
        "contactId" => integration_customer.external_customer_id,
        "input" => {
          "properties" => {
            "email" => customer.email,
            "firstname" => customer.firstname,
            "lastname" => customer.lastname,
            "phone" => customer.phone,
            "company" => customer.legal_name,
            "website" => website
          }
        }
      }
    end

    it "returns the payload body" do
      expect(subject).to eq payload_body
    end

    context "when customer fields are blank" do
      let(:customer) { create(:customer, customer_type: "individual", phone: nil, url: nil) }

      it "excludes blank fields from properties" do
        properties = subject.dig("input", "properties")
        expect(properties).not_to have_key("phone")
        expect(properties).not_to have_key("website")
      end
    end
  end
end
