# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Payables::Object do
  subject { described_class }

  it "has the correct graphql name" do
    expect(subject.graphql_name).to eq("Payable")
  end

  it "includes the correct possible types" do
    expect(subject.possible_types).to include(Types::Invoices::Object, Types::PaymentRequests::Object)
  end

  describe ".resolve_type" do
    let(:invoice) { create(:invoice) }
    let(:payment_request) { create(:payment_request) }

    it "returns Types::Invoices::Object for Invoice objects" do
      expect(subject.resolve_type(invoice, {})).to eq(Types::Invoices::Object)
    end

    it "returns Types::PaymentRequests::Object for PaymentRequest objects" do
      expect(subject.resolve_type(payment_request, {})).to eq(Types::PaymentRequests::Object)
    end

    it "raises an error for unexpected types" do
      expect { subject.resolve_type("Unexpected", {}) }.to raise_error(StandardError)
    end
  end
end
