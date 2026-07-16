# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::Anrok do
  describe "#body" do
    subject(:payload) { described_class.new(integration_customer:, invoice:).body }

    it_behaves_like "an integration payload", :anrok do
      def build_expected_payload(mapping_codes)
        [
          {
            "external_contact_id" => integration_customer.external_customer_id,
            "status" => "AUTHORISED",
            "issuing_date" => "2024-07-08T00:00:00Z",
            "payment_due_date" => "2024-07-08T00:00:00Z",
            "number" => invoice.number,
            "currency" => "EUR",
            "type" => "ACCREC",
            "fees" =>
            [
              {
                "account_code" => mapping_codes.dig(:add_on, :external_account_code),
                "description" => "Add-on Fee",
                "external_id" => mapping_codes.dig(:add_on, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.2e1
              },
              {
                "account_code" => mapping_codes.dig(:fixed_charge, :external_account_code),
                "description" => "Fixed Charge Fee",
                "external_id" => mapping_codes.dig(:fixed_charge, :external_id),
                "precise_unit_amount" => 25.0,
                "taxes_amount_cents" => 2,
                "units" => 0.6e1
              },
              {
                "account_code" => mapping_codes.dig(:billable_metric, :external_account_code),
                "description" => "Standard Charge Fee",
                "external_id" => mapping_codes.dig(:billable_metric, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.3e1
              },
              {
                "account_code" => mapping_codes.dig(:minimum_commitment, :external_account_code),
                "description" => "Minimum Commitment Fee",
                "external_id" => mapping_codes.dig(:minimum_commitment, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.4e1
              },
              {
                "account_code" => mapping_codes.dig(:subscription, :external_account_code),
                "description" => "Subscription",
                "external_id" => mapping_codes.dig(:subscription, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.5e1
              },
              {
                "account_code" => mapping_codes.dig(:coupon, :external_account_code),
                "description" => "Coupons",
                "external_id" => mapping_codes.dig(:coupon, :external_id),
                "precise_unit_amount" => -2.0,
                "taxes_amount_cents" => -290,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:prepaid_credit, :external_account_code),
                "description" => "Prepaid credit",
                "external_id" => mapping_codes.dig(:prepaid_credit, :external_id),
                "precise_unit_amount" => -3.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:prepaid_credit, :external_account_code),
                "description" => "Usage already billed",
                "external_id" => mapping_codes.dig(:prepaid_credit, :external_id),
                "precise_unit_amount" => -1.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:credit_note, :external_account_code),
                "description" => "Credit note",
                "external_id" => mapping_codes.dig(:credit_note, :external_id),
                "precise_unit_amount" => -5.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              }
            ]
          }
        ]
      end
    end
  end
end
