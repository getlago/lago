# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::XeroIntegration do
  subject(:xero_integration) { build(:xero_integration) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:connection_id) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(xero_integration).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe ".connection_id" do
    it "assigns and retrieve a secret pair" do
      xero_integration.connection_id = "connection_id"
      expect(xero_integration.connection_id).to eq("connection_id")
    end
  end

  describe "#sync_credit_notes" do
    it "assigns and retrieve a setting" do
      xero_integration.sync_credit_notes = true
      expect(xero_integration.sync_credit_notes).to eq(true)
    end
  end

  describe "#sync_invoices" do
    it "assigns and retrieve a setting" do
      xero_integration.sync_invoices = true
      expect(xero_integration.sync_invoices).to eq(true)
    end
  end

  describe "#sync_payments" do
    it "assigns and retrieve a setting" do
      xero_integration.sync_payments = true
      expect(xero_integration.sync_payments).to eq(true)
    end
  end

  describe "#external_id_key" do
    it "returns item_code" do
      expect(xero_integration.external_id_key).to eq("item_code")
    end
  end
end
