# frozen_string_literal: true

require "rails_helper"

RSpec.describe DunningCampaigns::ProcessAttemptService do
  subject(:result) { described_class.call(customer:, dunning_campaign_threshold:, billing_entity:) }

  let(:customer) { create :customer, organization:, currency:, billing_entity: }
  let(:organization) { create :organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:currency) { "EUR" }
  let(:dunning_campaign) { create :dunning_campaign, organization: }
  let(:dunning_campaign_threshold) do
    create :dunning_campaign_threshold, dunning_campaign:, currency:, amount_cents: 99_00
  end

  let(:payment_request) { create :payment_request, organization: }

  let(:payment_request_result) do
    BaseService::Result.new.tap do |result|
      result.payment_request = payment_request
      result.customer = customer
    end
  end

  before do
    billing_entity.update!(applied_dunning_campaign: dunning_campaign)
    allow(PaymentRequests::CreateService)
      .to receive(:call)
      .and_return(payment_request_result)
  end

  context "when premium features are enabled", :premium do
    let(:organization) { create :organization, premium_integrations: %w[auto_dunning] }

    let(:invoice_1) { create :invoice, organization:, customer:, currency:, payment_overdue: false }
    let(:invoice_2) { create :invoice, organization:, customer:, currency:, payment_overdue: true, total_amount_cents: 99_00 }
    let(:invoice_3) { create :invoice, organization:, customer:, currency: "USD", payment_overdue: true }
    let(:invoice_4) { create :invoice, currency:, payment_overdue: true }

    before do
      invoice_1
      invoice_2
      invoice_3
      invoice_4
    end

    it "returns a successful result with customer and payment request object" do
      expect(result).to be_success
      expect(result.customer).to eq customer
      expect(result.payment_request).to eq payment_request
    end

    it "creates a payment request with customer overdue invoices" do
      result

      expect(PaymentRequests::CreateService)
        .to have_received(:call)
        .with(
          organization:,
          params: {
            external_customer_id: customer.external_id,
            lago_invoice_ids: [invoice_2.id]
          },
          dunning_campaign:
        )
    end

    it "does not update customer dunning attempt counters" do
      expect { result && customer.reload }
        .to not_change(customer, :last_dunning_campaign_attempt)
        .and not_change { customer.dunning_currency_attempts }
    end

    context "when the campaign threshold is not reached" do
      let(:dunning_campaign_threshold) do
        create :dunning_campaign_threshold, dunning_campaign:, currency:, amount_cents: 99_01
      end

      it "does nothing" do
        result
        expect(PaymentRequests::CreateService).not_to have_received(:call)
      end
    end

    context "when the campaign is not applicable anymore" do
      let(:customer) do
        create :customer, organization:, currency:, applied_dunning_campaign:
      end

      let(:applied_dunning_campaign) { create :dunning_campaign, organization: }
      let(:applied_dunning_campaign_threshold) do
        create(
          :dunning_campaign_threshold,
          dunning_campaign: applied_dunning_campaign,
          currency:,
          amount_cents: 10_00
        )
      end

      it "does nothing" do
        result
        expect(PaymentRequests::CreateService).not_to have_received(:call)
      end
    end

    context "when the customer is excluded from auto dunning" do
      let(:customer) do
        create :customer, organization:, currency:, exclude_from_dunning_campaign: true
      end

      it "does nothing" do
        result
        expect(PaymentRequests::CreateService).not_to have_received(:call)
      end
    end

    context "when payment request creation fails" do
      before do
        payment_request_result.service_failure!(code: "error", message: "failure")
      end

      it "raises an error" do
        expect { result }.to raise_error(BaseService::ServiceFailure)
      end
    end

    context "when customer has overdue invoices in multiple currencies" do
      let(:usd_invoice) do
        create :invoice, organization:, customer:, currency: "USD", payment_overdue: true, total_amount_cents: 200_00
      end

      let(:eur_invoice) do
        create :invoice, organization:, customer:, currency:, payment_overdue: true, total_amount_cents: 150_00
      end

      let(:dunning_campaign_threshold) do
        create :dunning_campaign_threshold, dunning_campaign:, currency:, amount_cents: 100_00
      end

      before do
        usd_invoice
        eur_invoice
      end

      it "creates a payment request with only invoices matching the threshold currency" do
        result
        expect(PaymentRequests::CreateService).to have_received(:call) do |args|
          expect(args[:organization]).to eq(organization)
          expect(args[:dunning_campaign]).to eq(dunning_campaign)
          expect(args[:params][:external_customer_id]).to eq(customer.external_id)
          expect(args[:params][:lago_invoice_ids]).to include(eur_invoice.id)
          expect(args[:params][:lago_invoice_ids]).not_to include(usd_invoice.id)
        end
      end
    end

    context "when the customer has overdue invoices across multiple billing entities" do
      let(:other_billing_entity) { create :billing_entity, organization: }

      let(:matching_invoice) do
        create :invoice, organization:, customer:, billing_entity:, currency:,
          payment_overdue: true, total_amount_cents: 99_00
      end
      let(:other_entity_invoice) do
        create :invoice, organization:, customer:, billing_entity: other_billing_entity, currency:,
          payment_overdue: true, total_amount_cents: 99_00
      end

      before do
        matching_invoice
        other_entity_invoice
      end

      it "scopes the payment request invoices to the provided billing entity" do
        result

        expect(PaymentRequests::CreateService).to have_received(:call) do |args|
          expect(args[:params][:lago_invoice_ids]).to include(matching_invoice.id)
          expect(args[:params][:lago_invoice_ids]).not_to include(other_entity_invoice.id)
        end
      end
    end

    context "when a customer has invoices that are not ready for payment processing" do
      let(:invoice_5) { create :invoice, organization:, customer:, currency:, payment_overdue: true, ready_for_payment_processing: false, total_amount_cents: 99_00 }

      before { invoice_5 }

      it "creates payment only for ready_for_processing invoice" do
        expect(result.payment_request).to eq payment_request
        expect(PaymentRequests::CreateService).to have_received(:call)
          .with(organization:,
            params: {
              external_customer_id: customer.external_id,
              lago_invoice_ids: [invoice_2.id]
            },
            dunning_campaign:)
      end
    end
  end

  it "does nothing" do
    result
    expect(PaymentRequests::CreateService).not_to have_received(:call)
  end
end
