# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Payments::Payloads::Xero do
  let(:payload) { described_class.new(integration:, payment:).body }

  describe "#body" do
    it_behaves_like "an integration payload", :xero do
      let!(:integration_invoice) { create(:integration_resource, syncable: invoice, integration:) }

      before { integration_invoice }

      def build_expected_payload(mapping_codes)
        [
          {
            "invoice_id" => integration_invoice.external_id,
            "account_code" => mapping_codes.dig(:account, :external_account_code),
            "date" => payment.created_at.utc.iso8601,
            "amount_cents" => payment.amount_cents
          }
        ]
      end
    end
  end
end
