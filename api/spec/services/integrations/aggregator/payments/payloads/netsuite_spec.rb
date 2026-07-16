# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Payments::Payloads::Netsuite do
  let(:payload) { described_class.new(integration:, payment:) }
  let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:payment) { create(:payment, payable: invoice, amount_cents: 100) }
  let(:integration_invoice) { create(:integration_resource, integration:, syncable: invoice) }

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 200,
      issuing_date: DateTime.new(2024, 7, 8)
    )
  end

  let(:body) do
    {
      "isDynamic" => true,
      "columns" => {
        "customer" => integration_customer.external_customer_id,
        "payment" => payment.amount_cents.div(100).to_f
      },
      "options" => {
        "ignoreMandatoryFields" => false
      },
      "type" => "customerpayment",
      "lines" => [
        {
          "lineItems" => [
            {
              "amount" => payment.amount_cents.div(100).to_f,
              "apply" => true,
              "doc" => integration_invoice.external_id
            }
          ],
          "sublistId" => "apply"
        }
      ]
    }
  end

  before do
    integration_customer
    integration_invoice
  end

  describe "#body" do
    subject(:body_call) { payload.body }

    it "returns payload body" do
      expect(subject).to eq(body)
    end
  end
end
