# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::HubspotIntegration do
  subject(:hubspot_integration) { build(:hubspot_integration) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:connection_id) }
  it { is_expected.to validate_presence_of(:default_targeted_object) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(hubspot_integration).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "#connection_id" do
    it "assigns and retrieve a secret pair" do
      hubspot_integration.connection_id = "connection_id"
      expect(hubspot_integration.connection_id).to eq("connection_id")
    end
  end

  describe "#default_targeted_object" do
    it "assigns and retrieve a setting" do
      hubspot_integration.default_targeted_object = "companies"
      expect(hubspot_integration.default_targeted_object).to eq("companies")
    end
  end

  describe "#portal_id" do
    it "assigns and retrieve a setting" do
      hubspot_integration.portal_id = "123456789"
      expect(hubspot_integration.portal_id).to eq("123456789")
    end
  end

  describe "#sync_invoices" do
    it "assigns and retrieve a setting" do
      hubspot_integration.sync_invoices = true
      expect(hubspot_integration.sync_invoices).to eq(true)
    end
  end

  describe "#sync_subscriptions" do
    it "assigns and retrieve a setting" do
      hubspot_integration.sync_subscriptions = true
      expect(hubspot_integration.sync_subscriptions).to eq(true)
    end
  end

  describe "#subscriptions_object_type_id" do
    it "assigns and retrieve a setting" do
      hubspot_integration.subscriptions_object_type_id = "123"
      expect(hubspot_integration.subscriptions_object_type_id).to eq("123")
    end
  end

  describe "#invoices_object_type_id" do
    it "assigns and retrieve a setting" do
      hubspot_integration.invoices_object_type_id = "123"
      expect(hubspot_integration.invoices_object_type_id).to eq("123")
    end
  end

  describe "#companies_properties_version" do
    it "assigns and retrieve a setting" do
      hubspot_integration.companies_properties_version = 5
      expect(hubspot_integration.companies_properties_version).to eq(5)
    end
  end

  describe "#contacts_properties_version" do
    it "assigns and retrieve a setting" do
      hubspot_integration.contacts_properties_version = 6
      expect(hubspot_integration.contacts_properties_version).to eq(6)
    end
  end

  describe "#subscriptions_properties_version" do
    it "assigns and retrieve a setting" do
      hubspot_integration.subscriptions_properties_version = 7
      expect(hubspot_integration.subscriptions_properties_version).to eq(7)
    end
  end

  describe "#invoices_properties_version" do
    it "assigns and retrieve a setting" do
      hubspot_integration.invoices_properties_version = 8
      expect(hubspot_integration.invoices_properties_version).to eq(8)
    end
  end

  describe "#companies_object_type_id" do
    it "returns the correct object type id for companies" do
      expect(hubspot_integration.companies_object_type_id).to eq("0-2")
    end
  end

  describe "#contacts_object_type_id" do
    it "returns the correct object type id for contacts" do
      expect(hubspot_integration.contacts_object_type_id).to eq("0-1")
    end
  end
end
