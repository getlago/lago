# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Xero do
  let(:integration) { integration_customer.integration }
  let(:integration_customer) { FactoryBot.create(:xero_customer, customer:) }
  let(:customer) { create(:customer, firstname:, lastname:) }
  let(:payload) { described_class.new(integration:, customer:, integration_customer:) }
  let(:customer_link) { payload.__send__(:customer_url) }
  let(:contact_names) { {"firstname" => firstname, "lastname" => lastname}.compact_blank }

  describe "#create_body" do
    subject(:create_body_call) { payload.create_body }

    let(:payload_body) do
      [
        {
          "name" => customer.name,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "email" => customer.email,
          "phone" => customer.phone
        }.merge(contact_names)
      ]
    end

    context "when firstname and lastname are blank" do
      let(:firstname) { [nil, ""].sample }
      let(:lastname) { [nil, ""].sample }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when both firstname and lastname are present" do
      let(:firstname) { Faker::Name.first_name }
      let(:lastname) { Faker::Name.last_name }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when firstname is present" do
      let(:firstname) { Faker::Name.first_name }
      let(:lastname) { [nil, ""].sample }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when lastname is present" do
      let(:firstname) { [nil, ""].sample }
      let(:lastname) { Faker::Name.last_name }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end
  end

  describe "#update_body" do
    subject(:update_body_call) { payload.update_body }

    let(:payload_body) do
      [
        {
          "id" => integration_customer.external_customer_id,
          "name" => customer.name,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "state" => customer.state,
          "email" => customer.email,
          "phone" => customer.phone
        }.merge(contact_names)
      ]
    end

    context "when firstname and lastname are blank" do
      let(:firstname) { [nil, ""].sample }
      let(:lastname) { [nil, ""].sample }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when both firstname and lastname are present" do
      let(:firstname) { Faker::Name.first_name }
      let(:lastname) { Faker::Name.last_name }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when firstname is present" do
      let(:firstname) { Faker::Name.first_name }
      let(:lastname) { [nil, ""].sample }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end

    context "when lastname is present" do
      let(:firstname) { [nil, ""].sample }
      let(:lastname) { Faker::Name.last_name }

      it "returns the payload body" do
        expect(subject).to eq payload_body
      end
    end
  end
end
