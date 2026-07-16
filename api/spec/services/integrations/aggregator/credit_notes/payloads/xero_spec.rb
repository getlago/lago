# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::CreditNotes::Payloads::Xero do
  describe "#body" do
    subject(:payload) { described_class.new(integration_customer:, credit_note:).body }

    it_behaves_like "an integration payload", :xero do
      def build_expected_payload(mapping_codes)
        [
          {
            "currency" => "EUR",
            "external_contact_id" => integration_customer.external_customer_id,
            "fees" =>
           [
             {
               "account_code" => mapping_codes.dig(:add_on, :external_account_code),
               "description" => "Add-on Fee",
               "item_code" => mapping_codes.dig(:add_on, :external_id),
               "precise_unit_amount" => 1.9,
               "taxes_amount_cents" => 0.0,
               "units" => 1
             },
             {
               "account_code" => mapping_codes.dig(:fixed_charge, :external_account_code),
               "description" => "Fixed Charge Fee",
               "item_code" => mapping_codes.dig(:fixed_charge, :external_id),
               "precise_unit_amount" => 1.4,
               "taxes_amount_cents" => 0.0,
               "units" => 1
             },
             {
               "account_code" => mapping_codes.dig(:billable_metric, :external_account_code),
               "description" => "Standard Charge Fee",
               "item_code" => mapping_codes.dig(:billable_metric, :external_id),
               "precise_unit_amount" => 1.8,
               "taxes_amount_cents" => 0.0,
               "units" => 1
             },
             {
               "account_code" => mapping_codes.dig(:minimum_commitment, :external_account_code),
               "description" => "Minimum Commitment Fee",
               "item_code" => mapping_codes.dig(:minimum_commitment, :external_id),
               "precise_unit_amount" => 1.7,
               "taxes_amount_cents" => 0.0,
               "units" => 1
             },
             {
               "account_code" => mapping_codes.dig(:subscription, :external_account_code),
               "description" => "Subscription",
               "item_code" => mapping_codes.dig(:subscription, :external_id),
               "precise_unit_amount" => 1.6,
               "taxes_amount_cents" => 0.0,
               "units" => 1
             }
           ],
            "issuing_date" => "2024-07-08T00:00:00Z",
            "number" => credit_note.number,
            "status" => "AUTHORISED",
            "type" => "ACCRECCREDIT"
          }
        ]
      end

      context "when there are coupons" do
        let(:credit_note) { create(:credit_note, customer:, invoice:, issuing_date: DateTime.new(2024, 7, 8), coupons_adjustment_amount_cents: 50) }

        it "returns coupons with item_code instead of external_id" do
          expect(payload.first["fees"]).to include(
            {
              "account_code" => default_mapping_codes.dig(:coupon, :external_account_code),
              "description" => "Coupons",
              "item_code" => default_mapping_codes.dig(:coupon, :external_id),
              "precise_unit_amount" => -0.5,
              "taxes_amount_cents" => 0,
              "units" => 1
            }
          )
        end
      end
    end
  end
end
