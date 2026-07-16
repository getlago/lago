# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ActivityLogs::ResourceObject do
  subject { described_class }

  it "has the correct graphql name" do
    expect(subject.graphql_name).to eq("ActivityLogResourceObject")
  end

  it "includes the correct possible types" do
    expect(subject.possible_types).to contain_exactly(
      Types::BillableMetrics::Object,
      Types::Plans::Object,
      Types::Customers::Object,
      Types::Invoices::Object,
      Types::CreditNotes::Object,
      Types::BillingEntities::Object,
      Types::Subscriptions::Object,
      Types::Wallets::Object,
      Types::Coupons::Object,
      Types::PaymentRequests::Object,
      Types::Entitlement::FeatureObject,
      Types::PaymentReceipts::Object
    )
  end

  describe ".resolve_type" do
    let(:billable_metric) { create(:billable_metric) }
    let(:plan) { create(:plan) }
    let(:customer) { create(:customer) }
    let(:invoice) { create(:invoice) }
    let(:credit_note) { create(:credit_note) }
    let(:billing_entity) { create(:billing_entity) }
    let(:subscription) { create(:subscription) }
    let(:wallet) { create(:wallet) }
    let(:coupon) { create(:coupon) }
    let(:payment_request) { create(:payment_request) }
    let(:feature) { create(:feature) }

    it "returns Types::BillableMetrics::Object for BillableMetric objects" do
      expect(subject.resolve_type(billable_metric, {})).to eq(Types::BillableMetrics::Object)
    end

    it "returns Types::Plans::Object for Plan objects" do
      expect(subject.resolve_type(plan, {})).to eq(Types::Plans::Object)
    end

    it "returns Types::Customers::Object for Customer objects" do
      expect(subject.resolve_type(customer, {})).to eq(Types::Customers::Object)
    end

    it "returns Types::Invoices::Object for Invoice objects" do
      expect(subject.resolve_type(invoice, {})).to eq(Types::Invoices::Object)
    end

    it "returns Types::CreditNotes::Object for CreditNote objects" do
      expect(subject.resolve_type(credit_note, {})).to eq(Types::CreditNotes::Object)
    end

    it "returns Types::BillingEntities::Object for BillingEntity objects" do
      expect(subject.resolve_type(billing_entity, {})).to eq(Types::BillingEntities::Object)
    end

    it "returns Types::Subscriptions::Object for Subscription objects" do
      expect(subject.resolve_type(subscription, {})).to eq(Types::Subscriptions::Object)
    end

    it "returns Types::Wallets::Object for Wallet objects" do
      expect(subject.resolve_type(wallet, {})).to eq(Types::Wallets::Object)
    end

    it "returns Types::Coupons::Object for Coupon objects" do
      expect(subject.resolve_type(coupon, {})).to eq(Types::Coupons::Object)
    end

    it "raises an error for unexpected types" do
      expect { subject.resolve_type("Unexpected", {}) }.to raise_error(StandardError)
    end

    it "returns Types::PaymentRequests::Object for PaymentRequest objects" do
      expect(subject.resolve_type(payment_request, {})).to eq(Types::PaymentRequests::Object)
    end

    it "returns Types::Entitlement::FeatureObject for Feature objects" do
      expect(subject.resolve_type(feature, {})).to eq(Types::Entitlement::FeatureObject)
    end
  end
end
