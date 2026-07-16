# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::Xero do
  describe "#body" do
    subject(:payload) { described_class.new(integration_customer:, invoice:).body }

    it_behaves_like "an integration payload", :xero do
      let(:invoice) do
        invoice = create(
          :invoice,
          customer:,
          organization:,
          billing_entity:,
          coupons_amount_cents: 200,
          prepaid_credit_amount_cents: 300,
          progressive_billing_credit_amount_cents: 100,
          credit_notes_amount_cents: 500,
          taxes_amount_cents: 300,
          purchase_order_number: "PO-123",
          issuing_date: DateTime.new(2024, 7, 8)
        )
        create(:invoice_subscription, invoice:, subscription:)
        invoice
      end

      def build_expected_payload(mapping_codes)
        [
          {
            "external_contact_id" => integration_customer.external_customer_id,
            "status" => "AUTHORISED",
            "issuing_date" => "2024-07-08T00:00:00Z",
            "payment_due_date" => "2024-07-08T00:00:00Z",
            "number" => invoice.number,
            "reference" => "PO-123",
            "currency" => "EUR",
            "type" => "ACCREC",
            "fees" => [
              {
                "account_code" => mapping_codes.dig(:add_on, :external_account_code),
                "description" => "Add-on Fee",
                "item_code" => mapping_codes.dig(:add_on, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.2e1
              },
              {
                "account_code" => mapping_codes.dig(:fixed_charge, :external_account_code),
                "description" => "Fixed Charge Fee",
                "item_code" => mapping_codes.dig(:fixed_charge, :external_id),
                "precise_unit_amount" => 25.0,
                "taxes_amount_cents" => 2,
                "units" => 0.6e1
              },
              {
                "account_code" => mapping_codes.dig(:billable_metric, :external_account_code),
                "description" => "Standard Charge Fee",
                "item_code" => mapping_codes.dig(:billable_metric, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.3e1
              },
              {
                "account_code" => mapping_codes.dig(:minimum_commitment, :external_account_code),
                "description" => "Minimum Commitment Fee",
                "item_code" => mapping_codes.dig(:minimum_commitment, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.4e1
              },
              {
                "account_code" => mapping_codes.dig(:subscription, :external_account_code),
                "description" => "Subscription",
                "item_code" => mapping_codes.dig(:subscription, :external_id),
                "precise_unit_amount" => 100.0,
                "taxes_amount_cents" => 2,
                "units" => 0.5e1
              },
              {
                "account_code" => mapping_codes.dig(:coupon, :external_account_code),
                "description" => "Coupons",
                "item_code" => mapping_codes.dig(:coupon, :external_id),
                "precise_unit_amount" => -2.0,
                "taxes_amount_cents" => -290,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:prepaid_credit, :external_account_code),
                "description" => "Prepaid credit",
                "item_code" => mapping_codes.dig(:prepaid_credit, :external_id),
                "precise_unit_amount" => -3.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:prepaid_credit, :external_account_code),
                "description" => "Usage already billed",
                "item_code" => mapping_codes.dig(:prepaid_credit, :external_id),
                "precise_unit_amount" => -1.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              },
              {
                "account_code" => mapping_codes.dig(:credit_note, :external_account_code),
                "description" => "Credit note",
                "item_code" => mapping_codes.dig(:credit_note, :external_id),
                "precise_unit_amount" => -5.0,
                "taxes_amount_cents" => 0,
                "units" => 1
              }
            ]
          }
        ]
      end
    end

    context "with a single billable metric charge" do
      let(:organization) { create(:organization) }
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:integration) { create(:xero_integration, organization:) }
      let(:customer) { create(:customer, organization:, billing_entity:) }
      let(:integration_customer) { create(:xero_customer, customer:, integration:) }
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:plan) { create(:plan, organization:) }
      let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
      let(:subscription) { create(:subscription, organization:, plan:) }

      let(:invoice) do
        invoice = create(
          :invoice,
          customer:,
          organization:,
          billing_entity:,
          coupons_amount_cents: 0,
          prepaid_credit_amount_cents: 0,
          progressive_billing_credit_amount_cents: 0,
          credit_notes_amount_cents: 0,
          taxes_amount_cents: 0,
          issuing_date: DateTime.new(2024, 7, 8)
        )
        create(:invoice_subscription, invoice:, subscription:)
        invoice
      end

      let(:billable_metric_mapping) do
        create(
          :xero_mapping,
          integration:,
          mappable_type: "BillableMetric",
          mappable_id: billable_metric.id,
          billing_entity:,
          settings: {external_id: "metric_ext_id", external_account_code: "100", external_name: "metric"}
        )
      end

      before { billable_metric_mapping }

      context "when a fee has precise_unit_amount with more than 2 decimal places" do
        let(:high_precision_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 74_759_000,
            amount_cents: 89_566,
            precise_unit_amount: 0.000018,
            taxes_amount_cents: 0
          )
        end

        before { high_precision_fee }

        it "sends precise_unit_amount as the total amount in currency units instead of amount_cents" do
          fee_item = payload.first["fees"].first

          expect(fee_item).to include(
            "units" => 1,
            "precise_unit_amount" => 895.66
          )
          expect(fee_item).not_to have_key("amount_cents")
        end
      end

      context "when a charge fee has a single grouped_by pricing group key value" do
        let(:grouped_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 10,
            amount_cents: 1000,
            precise_unit_amount: 100.0,
            taxes_amount_cents: 0,
            invoice_display_name: "Storage usage",
            grouped_by: {"deployment_name" => "green"}
          )
        end

        before { grouped_fee }

        it "appends the grouped_by value to the line item description" do
          fee_item = payload.first["fees"].first

          expect(fee_item["description"]).to eq("Storage usage • green")
        end
      end

      context "when a charge fee has multiple grouped_by pricing group key values" do
        let(:grouped_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 10,
            amount_cents: 1000,
            precise_unit_amount: 100.0,
            taxes_amount_cents: 0,
            invoice_display_name: "Storage usage",
            grouped_by: {"region" => "eu", "tier" => "gold"}
          )
        end

        before { grouped_fee }

        it "joins the grouped_by values into the line item description with a ' • ' separator" do
          fee_item = payload.first["fees"].first

          # JSONB does not preserve insertion order, so accept either ordering
          # of the two grouped_by values — we only lock in the separator format.
          expect(fee_item["description"]).to match(/\AStorage usage • (eu • gold|gold • eu)\z/)
        end
      end

      context "when a charge fee has no grouped_by values" do
        let(:plain_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 10,
            amount_cents: 1000,
            precise_unit_amount: 100.0,
            taxes_amount_cents: 0,
            invoice_display_name: "Storage usage"
          )
        end

        before { plain_fee }

        it "leaves the line item description unchanged" do
          fee_item = payload.first["fees"].first

          expect(fee_item["description"]).to eq("Storage usage")
        end
      end

      context "when the invoice has a mix of $0 and positive amount fees" do
        let(:positive_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 2,
            amount_cents: 200,
            precise_unit_amount: 100.0,
            taxes_amount_cents: 0,
            invoice_display_name: "Paid usage",
            created_at: 2.minutes.ago
          )
        end

        let(:zero_amount_fee) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            billable_metric:,
            units: 5,
            amount_cents: 0,
            precise_unit_amount: 0.0,
            taxes_amount_cents: 0,
            invoice_display_name: "Free usage",
            created_at: 1.minute.ago
          )
        end

        before do
          positive_fee
          zero_amount_fee
        end

        # The base payload drops $0 fees when a positive fee exists; Xero keeps
        # them. This mix is the scenario where Xero's behavior diverges from the
        # base, so it is the meaningful guard for the override.
        it "includes the $0 fee line item alongside the positive fee, preserving creation order" do
          fees = payload.first["fees"]

          expect(fees.size).to eq(2)
          expect(fees.map { |f| f["description"] }).to eq(["Paid usage", "Free usage"])

          zero_item = fees.last
          expect(zero_item["units"]).to eq(5)
          expect(zero_item["precise_unit_amount"]).to eq(0.0)
        end
      end
    end
  end
end
