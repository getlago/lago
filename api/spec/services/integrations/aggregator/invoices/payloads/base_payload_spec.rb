# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::BasePayload do
  let(:payload) { described_class.new(integration_customer:, invoice:) }
  let(:integration_customer) { create(:xero_customer, integration:, customer:) }
  let(:integration) { create(:xero_integration, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  describe "#fees" do
    subject(:fees_call) { payload.__send__(:fees) }

    context "when there are fees with positive amount_cents" do
      let(:fee1) { create(:fee, invoice:, amount_cents: 1000, created_at: 1.day.ago) }
      let(:fee2) { create(:fee, invoice:, amount_cents: 2000, created_at: 2.days.ago) }

      before do
        fee1
        fee2
      end

      it "returns fees with positive amount_cents ordered by created_at" do
        expect(fees_call).to eq([fee2, fee1])
      end
    end

    context "when there are no fees with positive amount_cents" do
      let(:fee1) { create(:fee, invoice:, amount_cents: 0, created_at: 1.day.ago) }
      let(:fee2) { create(:fee, invoice:, amount_cents: -1000, created_at: 2.days.ago) }

      before do
        fee1
        fee2
      end

      it "returns all fees ordered by created_at" do
        expect(fees_call).to eq([fee2, fee1])
      end
    end

    context "when there are fees with positive and zero amount_cents" do
      let(:fee2) { create(:fee, invoice:, amount_cents: 100, created_at: 2.days.ago) }
      let(:fee3) { create(:fee, invoice:, amount_cents: 200, created_at: 3.days.ago) }

      before do
        create(:fee, invoice:, amount_cents: 0, created_at: 1.day.ago)
        fee2
        fee3
      end

      it "returns only positive fees ordered by created_at" do
        expect(fees_call).to eq([fee3, fee2])
      end
    end
  end
end
