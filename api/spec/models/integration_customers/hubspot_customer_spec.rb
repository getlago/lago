# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::HubspotCustomer do
  subject(:hubspot_customer) { build(:hubspot_customer) }

  describe "#targeted_object" do
    let(:targeted_object) { Integrations::HubspotIntegration::TARGETED_OBJECTS.sample }

    it "assigns and retrieve a setting" do
      hubspot_customer.targeted_object = targeted_object
      expect(hubspot_customer.targeted_object).to eq(targeted_object)
    end
  end

  describe "#email" do
    let(:email) { Faker::Internet.email }

    it "assigns and retrieve a setting" do
      hubspot_customer.email = email
      expect(hubspot_customer.email).to eq(email)
    end
  end
end
