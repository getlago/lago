# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::Netsuite do
  let(:payload) { described_class.new(integration_customer:, invoice:) }
  let(:integration_customer) { create(:xero_customer, integration:, customer:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      progressive_billing_credit_amount_cents: 100,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 200,
      issuing_date: DateTime.new(2024, 7, 8)
    )
  end

  describe "#body" do
    subject(:body_call) { payload.body }

    let(:add_on) { create(:add_on, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:charge) { create(:standard_charge, billable_metric:) }
    let(:current_time) { Time.current }

    let(:integration_collection_mapping1) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :fallback_item,
        settings: {external_id: "1", external_account_code: "11", external_name: ""}
      )
    end

    let(:integration_collection_mapping2) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :coupon,
        settings: {external_id: "2", external_account_code: "22", external_name: ""}
      )
    end

    let(:integration_collection_mapping3) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :subscription_fee,
        settings: {external_id: "3", external_account_code: "33", external_name: ""}
      )
    end

    let(:integration_collection_mapping4) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :minimum_commitment,
        settings: {external_id: "4", external_account_code: "44", external_name: ""}
      )
    end

    let(:integration_collection_mapping5) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :tax,
        settings: {external_id: "5", external_account_code: "55", external_name: ""}
      )
    end

    let(:integration_collection_mapping6) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :prepaid_credit,
        settings: {external_id: "6", external_account_code: "66", external_name: ""}
      )
    end

    let(:integration_mapping_add_on) do
      create(
        :netsuite_mapping,
        integration:,
        mappable_type: "AddOn",
        mappable_id: add_on.id,
        settings: {external_id: "m1", external_account_code: "m11", external_name: ""}
      )
    end

    let(:integration_mapping_bm) do
      create(
        :netsuite_mapping,
        integration:,
        mappable_type: "BillableMetric",
        mappable_id: billable_metric.id,
        settings: {external_id: "m2", external_account_code: "m22", external_name: ""}
      )
    end

    let(:fee_sub) do
      create(
        :fee,
        invoice:,
        amount_cents: 10_000,
        taxes_amount_cents: 200,
        created_at: current_time - 3.seconds
      )
    end

    let(:minimum_commitment_fee) do
      create(
        :minimum_commitment_fee,
        invoice:,
        created_at: current_time - 2.seconds
      )
    end

    let(:charge_fee) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        units: 2,
        precise_unit_amount: 4.12121212123337777,
        created_at: current_time
      )
    end

    let(:charge_fee2) do
      create(
        :charge_fee,
        invoice:,
        charge:,
        units: 0,
        precise_unit_amount: 0.0,
        amount_cents: 0,
        created_at: current_time
      )
    end

    let(:invoice_link) do
      url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

      URI.join(url, "/#{customer.organization.slug}/customer/#{customer.id}/", "invoice/#{invoice.id}/overview").to_s
    end

    let(:due_date) { invoice.payment_due_date.strftime("%-m/%-d/%Y") }
    let(:issuing_date) { invoice.issuing_date.strftime("%-m/%-d/%Y") }

    let(:body) do
      {
        "type" => "invoice",
        "isDynamic" => true,
        "columns" => columns,
        "lines" => [
          {
            "sublistId" => "item",
            "lineItems" => [
              {
                "item" => "3",
                "account" => "33",
                "quantity" => 0.0,
                "rate" => 0.0,
                "amount" => 100.0,
                "taxdetailsreference" => fee_sub.id,
                "custcol_service_period_date_from" =>
                  fee_sub.properties["from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "custcol_service_period_date_to" => fee_sub.properties["to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "description" => fee_sub.item_name,
                "item_source" => fee_sub.item_source
              },
              {
                "item" => "4",
                "account" => "44",
                "quantity" => 0.0,
                "rate" => 0.0,
                "amount" => 2.0,
                "taxdetailsreference" => minimum_commitment_fee.id,
                "custcol_service_period_date_from" =>
                  minimum_commitment_fee.properties["from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "custcol_service_period_date_to" =>
                  minimum_commitment_fee.properties["to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "description" => minimum_commitment_fee.item_name,
                "item_source" => minimum_commitment_fee.item_source
              },
              {
                "item" => "m2",
                "account" => "m22",
                "quantity" => 2,
                "rate" => 4.1212121212334,
                "amount" => 2.0,
                "taxdetailsreference" => charge_fee.id,
                "custcol_service_period_date_from" =>
                  charge_fee.properties["charges_from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "custcol_service_period_date_to" =>
                  charge_fee.properties["charges_to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                "description" => charge_fee.item_name,
                "item_source" => charge_fee.item_source
              },
              {
                "item" => "2",
                "account" => "22",
                "quantity" => 1,
                "rate" => -20.0,
                "taxdetailsreference" => "coupon_item",
                "description" => invoice.credits.coupon_kind.map(&:item_name).join(","),
                "item_source" => "coupons"
              },
              {
                "item" => "6",
                "account" => "66",
                "quantity" => 1,
                "rate" => -40.0,
                "taxdetailsreference" => "credit_item",
                "description" => "Prepaid credits",
                "item_source" => "prepaid_credits"
              },
              {
                "item" => "6",
                "account" => "66",
                "quantity" => 1,
                "rate" => -1.0,
                "taxdetailsreference" => "credit_item_progressive_billing",
                "description" => invoice.credits.progressive_billing_invoice_kind.map(&:item_name).join(","),
                "item_source" => "progressive_billing_credits"
              },
              {
                "item" => "1", # Fallback item instead of credit note
                "account" => "11",
                "quantity" => 1,
                "rate" => -60.0,
                "taxdetailsreference" => "credit_note_item",
                "description" => invoice.credits.credit_note_kind.map(&:item_name).join(","),
                "item_source" => "credit_note_credits"
              }
            ]
          }
        ],
        "options" => {
          "ignoreMandatoryFields" => false,
          "fullInvoicePayload" => {
            "invoice_payload" => hash_including(
              lago_id: invoice.id,
              billing_entity_code: anything,
              sequential_id: invoice.sequential_id,
              number: invoice.number,
              issuing_date: invoice.issuing_date&.iso8601,
              payment_due_date: invoice.payment_due_date&.iso8601,
              net_payment_term: invoice.net_payment_term,
              invoice_type: invoice.invoice_type,
              status: invoice.status,
              payment_status: invoice.payment_status,
              currency: invoice.currency,
              fees_amount_cents: invoice.fees_amount_cents,
              taxes_amount_cents: invoice.taxes_amount_cents,
              coupons_amount_cents: invoice.coupons_amount_cents,
              credit_notes_amount_cents: invoice.credit_notes_amount_cents,
              prepaid_credit_amount_cents: invoice.prepaid_credit_amount_cents,
              total_amount_cents: invoice.total_amount_cents,
              total_due_amount_cents: invoice.total_due_amount_cents,
              version_number: invoice.version_number,
              self_billed: invoice.self_billed,
              customer: hash_including(
                lago_id: customer.id,
                external_id: customer.external_id,
                name: customer.name,
                integration_customers: anything
              ),
              fees: invoice.fees.map do |fee|
                hash_including(
                  lago_id: fee.id,
                  lago_invoice_id: fee.invoice_id,
                  lago_subscription_id: fee.subscription_id,
                  lago_customer_id: fee.customer&.id,
                  amount_cents: fee.amount_cents,
                  amount_currency: fee.amount_currency,
                  taxes_amount_cents: fee.taxes_amount_cents,
                  total_amount_cents: fee.total_amount_cents,
                  units: fee.units,
                  precise_unit_amount: fee.precise_unit_amount,
                  item: hash_including(
                    type: fee.fee_type,
                    code: fee.item_code,
                    name: fee.item_name
                  )
                )
              end,
              credits: anything,
              metadata: anything,
              applied_taxes: anything,
              billing_periods: anything
            )
          }
        }
      }
    end

    let(:column_keys_with_taxes) do
      [
        "tranid",
        "custbody_ava_disable_tax_calculation",
        "custbody_lago_invoice_link",
        "trandate",
        "duedate",
        "taxdetailsoverride",
        "custbody_lago_id",
        "entity",
        "taxregoverride",
        "lago_plan_codes"
      ]
    end

    let(:column_keys_with_taxes_with_nexus) do
      column_keys_with_taxes.insert(7, "nexus")
    end

    let(:column_keys_without_taxes_with_nexus) do
      column_keys_with_taxes.insert(8, "nexus")
    end

    before do
      integration_customer
      charge
      integration_collection_mapping1
      integration_collection_mapping2
      integration_collection_mapping3
      integration_collection_mapping4
      integration_collection_mapping6
      integration_mapping_add_on
      integration_mapping_bm
      fee_sub
      minimum_commitment_fee
      charge_fee
      charge_fee2
    end

    describe "with currency mapping" do
      context "when no currencies mapping is defined" do
        it "doesn't send the currency attribute" do
          expect(subject["columns"]).not_to have_key("currency")
        end
      end

      context "when currencies mapping is defined and has value for invoice currency" do
        it "sends the currency attribute to NetSuite" do
          create(:netsuite_currencies_mapping, integration:, settings: {
            currencies: {
              "EUR" => "312",
              "USD" => "7"
            }
          })

          expect(subject["columns"]["currency"]).to eq("312")
        end
      end

      context "when currencies mapping is defined but have an invalid value" do
        it "doesn't send the currency attribute" do
          mapping = create(:netsuite_currencies_mapping, integration:)
          settings = mapping.settings
          # NOTE: Model validation prevents this from being saved, but just in case
          settings["currencies"] = {"EUR" => "", "USD" => "7"}
          mapping.update_column(:settings, settings) # rubocop:disable Rails/SkipsModelValidations

          expect(subject["columns"]).not_to have_key("currency")
        end
      end

      context "when currencies mapping is defined but doesn't have value for invoice currency" do
        it "doesn't send the currency attribute" do
          create(:netsuite_currencies_mapping, integration:, settings: {
            currencies: {
              "USD" => "7",
              "GBP" => "312"
            }
          })

          expect(subject["columns"]).not_to have_key("currency")
        end
      end
    end

    context "when tax item is mapped" do
      before do
        integration_collection_mapping5
      end

      context "when tax nexus is not present" do
        let(:columns) do
          {
            "tranid" => invoice.number,
            "entity" => integration_customer.external_customer_id,
            "taxregoverride" => true,
            "taxdetailsoverride" => true,
            "custbody_lago_id" => invoice.id,
            "custbody_ava_disable_tax_calculation" => true,
            "custbody_lago_invoice_link" => invoice_link,
            "trandate" => issuing_date,
            "duedate" => due_date,
            "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
          }
        end

        it "returns payload body with tax columns" do
          expect(subject).to match(body)
        end

        it "has the columns keys in order" do
          expect(subject["columns"].keys).to match_array(column_keys_with_taxes)
        end
      end

      context "when tax nexus is present" do
        context "when tax item is mapped completely" do
          before do
            integration_collection_mapping5.update!(
              tax_nexus: "some_nexus",
              tax_type: "some_type",
              tax_code: "some_code"
            )

            body["taxdetails"] = taxdetails
          end

          let(:taxdetails) do
            [
              {
                "lineItems" => [
                  {
                    "taxamount" => 2.0,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => fee_sub.id,
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => 0.02,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => minimum_commitment_fee.id,
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => 0.02,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => charge_fee.id,
                    "taxrate" => 0.0, "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => -0.04,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => "coupon_item",
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => 0,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => "credit_item",
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => 0,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => "credit_item_progressive_billing",
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  },
                  {
                    "taxamount" => 0,
                    "taxbasis" => 1,
                    "taxcode" => "some_code",
                    "taxdetailsreference" => "credit_note_item",
                    "taxrate" => 0.0,
                    "taxtype" => "some_type"
                  }
                ],
                "sublistId" => "taxdetails"
              }
            ]
          end

          let(:columns) do
            {
              "tranid" => invoice.number,
              "entity" => integration_customer.external_customer_id,
              "taxregoverride" => true,
              "taxdetailsoverride" => true,
              "custbody_lago_id" => invoice.id,
              "custbody_ava_disable_tax_calculation" => true,
              "custbody_lago_invoice_link" => invoice_link,
              "trandate" => issuing_date,
              "duedate" => due_date,
              "nexus" => "some_nexus",
              "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
            }
          end

          it "returns payload body with tax columns" do
            expect(subject).to match(body)
          end

          it "has the columns keys in order" do
            expect(subject["columns"].keys).to match_array(column_keys_with_taxes_with_nexus)
          end
        end

        context "when tax item is not mapped completely" do
          before { integration_collection_mapping5.update!(tax_nexus: "some_nexus") }

          let(:columns) do
            {
              "tranid" => invoice.number,
              "entity" => integration_customer.external_customer_id,
              "taxregoverride" => true,
              "taxdetailsoverride" => true,
              "custbody_lago_id" => invoice.id,
              "custbody_ava_disable_tax_calculation" => true,
              "custbody_lago_invoice_link" => invoice_link,
              "trandate" => issuing_date,
              "duedate" => due_date,
              "nexus" => "some_nexus",
              "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
            }
          end

          it "returns payload body with tax columns" do
            expect(subject).to match(body)
          end

          it "has the columns keys in order" do
            expect(subject["columns"].keys).to match_array(column_keys_without_taxes_with_nexus)
          end
        end
      end
    end

    context "when tax item is not mapped" do
      let(:columns) do
        {
          "tranid" => invoice.number,
          "entity" => integration_customer.external_customer_id,
          "taxregoverride" => true,
          "taxdetailsoverride" => true,
          "custbody_lago_id" => invoice.id,
          "custbody_ava_disable_tax_calculation" => true,
          "custbody_lago_invoice_link" => invoice_link,
          "trandate" => issuing_date,
          "duedate" => due_date,
          "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
        }
      end

      it "returns payload body with tax columns" do
        expect(subject).to match(body)
      end

      it "has the columns keys in order" do
        expect(subject["columns"].keys).to match_array(column_keys_with_taxes)
      end

      context "when a fee has a quantity exceeding NetSuite maximum" do
        let(:charge_fee_large) do
          create(
            :charge_fee,
            invoice:,
            charge:,
            units: 20_000_000_000,
            precise_unit_amount: 1.23,
            amount_cents: 3_000,
            created_at: current_time + 1.second
          )
        end

        let(:expected_body) do
          {
            "type" => "invoice",
            "isDynamic" => true,
            "columns" => columns,
            "lines" => [
              {
                "sublistId" => "item",
                "lineItems" => [
                  {
                    "item" => "3",
                    "account" => "33",
                    "quantity" => 0.0,
                    "rate" => 0.0,
                    "amount" => 100.0,
                    "taxdetailsreference" => fee_sub.id,
                    "custcol_service_period_date_from" =>
                      fee_sub.properties["from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "custcol_service_period_date_to" =>
                      fee_sub.properties["to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "description" => fee_sub.item_name,
                    "item_source" => fee_sub.item_source
                  },
                  {
                    "item" => "4",
                    "account" => "44",
                    "quantity" => 0.0,
                    "rate" => 0.0,
                    "amount" => 2.0,
                    "taxdetailsreference" => minimum_commitment_fee.id,
                    "custcol_service_period_date_from" =>
                      minimum_commitment_fee.properties["from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "custcol_service_period_date_to" =>
                      minimum_commitment_fee.properties["to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "description" => minimum_commitment_fee.item_name,
                    "item_source" => minimum_commitment_fee.item_source
                  },
                  {
                    "item" => "m2",
                    "account" => "m22",
                    "quantity" => 2,
                    "rate" => 4.1212121212334,
                    "amount" => 2.0,
                    "taxdetailsreference" => charge_fee.id,
                    "custcol_service_period_date_from" =>
                      charge_fee.properties["charges_from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "custcol_service_period_date_to" =>
                      charge_fee.properties["charges_to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "description" => charge_fee.item_name,
                    "item_source" => charge_fee.item_source
                  },
                  {
                    "item" => "m2",
                    "account" => "m22",
                    "quantity" => 1,
                    "rate" => 30.0,
                    "amount" => 30.0,
                    "taxdetailsreference" => charge_fee_large.id,
                    "custcol_service_period_date_from" =>
                      charge_fee_large.properties["charges_from_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "custcol_service_period_date_to" =>
                      charge_fee_large.properties["charges_to_datetime"]&.to_date&.strftime("%-m/%-d/%Y"),
                    "description" => charge_fee_large.item_name,
                    "item_source" => charge_fee_large.item_source
                  },
                  {
                    "item" => "2",
                    "account" => "22",
                    "quantity" => 1,
                    "rate" => -20.0,
                    "taxdetailsreference" => "coupon_item",
                    "description" => invoice.credits.coupon_kind.map(&:item_name).join(","),
                    "item_source" => "coupons"
                  },
                  {
                    "item" => "6",
                    "account" => "66",
                    "quantity" => 1,
                    "rate" => -40.0,
                    "taxdetailsreference" => "credit_item",
                    "description" => "Prepaid credits",
                    "item_source" => "prepaid_credits"
                  },
                  {
                    "item" => "6",
                    "account" => "66",
                    "quantity" => 1,
                    "rate" => -1.0,
                    "taxdetailsreference" => "credit_item_progressive_billing",
                    "description" => invoice.credits.progressive_billing_invoice_kind.map(&:item_name).join(","),
                    "item_source" => "progressive_billing_credits"
                  },
                  {
                    "item" => "1",
                    "account" => "11",
                    "quantity" => 1,
                    "rate" => -60.0,
                    "taxdetailsreference" => "credit_note_item",
                    "description" => invoice.credits.credit_note_kind.map(&:item_name).join(","),
                    "item_source" => "credit_note_credits"
                  }
                ]
              }
            ],
            "options" => {
              "ignoreMandatoryFields" => false,
              "fullInvoicePayload" => anything
            }
          }
        end

        before do
          charge_fee_large
        end

        it "sets quantity to 1 and moves the total amount to the rate field for that line" do
          expect(subject).to match(expected_body)
        end
      end
    end

    context "when invoice has a fixed_charge fee" do
      let(:plan) { create(:plan, organization:) }
      let(:fixed_charge) { create(:fixed_charge, organization:, plan:, add_on:) }
      let(:fixed_charge_fee) do
        create(
          :fixed_charge_fee,
          invoice:,
          fixed_charge:,
          amount_cents: 5000,
          units: 1,
          precise_unit_amount: 50.0,
          created_at: current_time + 1.second
        )
      end

      before { fixed_charge_fee }

      it "includes the fixed_charge fee using the add_on mapping" do
        line_items = subject["lines"].first["lineItems"]
        fixed_charge_line = line_items.find { |item| item["taxdetailsreference"] == fixed_charge_fee.id }

        expect(fixed_charge_line).to be_present
        expect(fixed_charge_line["item"]).to eq("m1")
        expect(fixed_charge_line["account"]).to eq("m11")
        expect(fixed_charge_line["amount"]).to eq(50.0)
      end
    end
  end

  describe "#tax_item_complete?" do
    subject(:tax_item_complete_call) { payload.__send__(:tax_item_complete?) }

    let(:integration_collection_mapping) do
      create(
        :netsuite_collection_mapping,
        integration:,
        mapping_type: :tax,
        settings:
      )
    end

    let(:settings) do
      {external_id: "5", external_account_code: "55", external_name: "", tax_nexus:, tax_type:, tax_code:}
    end

    before { integration_collection_mapping }

    context "when tax_item has all required attributes" do
      let(:tax_nexus) { "some_nexus" }
      let(:tax_type) { "some_type" }
      let(:tax_code) { "some_code" }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when tax_item is missing tax_nexus" do
      let(:tax_nexus) { [nil, ""].sample }
      let(:tax_type) { "some_type" }
      let(:tax_code) { "some_code" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when tax_item is missing tax_type" do
      let(:tax_nexus) { "some_nexus" }
      let(:tax_type) { [nil, ""].sample }
      let(:tax_code) { "some_code" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when tax_item is missing tax_code" do
      let(:tax_nexus) { "some_nexus" }
      let(:tax_type) { "some_type" }
      let(:tax_code) { [nil, ""].sample }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end
end
