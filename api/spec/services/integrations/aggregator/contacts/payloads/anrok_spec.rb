# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Anrok do
  let(:integration) { integration_customer.integration }
  let(:integration_customer) { FactoryBot.create(:anrok_customer, customer:) }
  let(:customer) { create(:customer) }
  let(:payload) { described_class.new(integration:, customer:, integration_customer:) }
  let(:customer_link) { payload.__send__(:customer_url) }

  describe "#create_body" do
    subject(:create_body_call) { payload.create_body }

    let(:payload_body) do
      [
        {
          "name" => customer.display_name(prefer_legal_name: false),
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "email" => customer.email,
          "phone" => customer.phone
        }
      ]
    end

    it "returns the payload body" do
      expect(subject).to eq payload_body
    end
  end

  describe "#update_body" do
    subject(:update_body_call) { payload.update_body }

    let(:payload_body) do
      [
        {
          "id" => integration_customer.external_customer_id,
          "name" => customer.display_name(prefer_legal_name: false),
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "email" => customer.email,
          "phone" => customer.phone
        }
      ]
    end

    it "returns the payload body" do
      expect(subject).to eq payload_body
    end
  end
end
