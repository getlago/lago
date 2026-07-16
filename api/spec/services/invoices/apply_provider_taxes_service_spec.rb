# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ApplyProviderTaxesService do
  subject(:apply_service) { described_class.new(invoice:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      fees_amount_cents:,
      coupons_amount_cents:,
      sub_total_excluding_taxes_amount_cents: fees_amount_cents - coupons_amount_cents
    )
  end
  let(:fees_amount_cents) { 3000 }
  let(:coupons_amount_cents) { 0 }
  let(:result) { BaseService::Result.new }

  let(:fee_taxes) do
    [
      OpenStruct.new(
        tax_breakdown: [
          OpenStruct.new(name: "tax 1", type: "type1", rate: "0.10")
        ]
      ),
      OpenStruct.new(
        tax_breakdown: [
          OpenStruct.new(name: "tax 1", type: "type1", rate: "0.10"),
          OpenStruct.new(name: "tax 2", type: "type2", rate: "0.12")
        ]
      )
    ]
  end

  describe "call" do
    context "when applying taxes for non-draft invoice" do
      before do
        result.fees = fee_taxes
        allow(Integrations::Aggregator::Taxes::Invoices::CreateService).to receive(:call)
          .with(invoice:)
          .and_return(result)
      end

      context "with non zero fees amount" do
        context "with non-zero taxes" do
          let(:fee1) do
            create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0)
          end
          let(:fee1_applied_tax1) do
            create(
              :fee_applied_tax,
              fee: fee1,
              amount_cents: 100,
              tax_name: "tax 1",
              tax_code: "tax_1",
              tax_rate: 10.0,
              tax_description: "type1"
            )
          end
          let(:fee2) do
            create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0)
          end
          let(:fee2_applied_tax_1) do
            create(
              :fee_applied_tax,
              fee: fee2,
              amount_cents: 200,
              tax_name: "tax 1",
              tax_code: "tax_1",
              tax_rate: 10.0,
              tax_description: "type1"
            )
          end
          let(:fee2_applied_tax_2) do
            create(
              :fee_applied_tax,
              fee: fee2,
              amount_cents: 240,
              tax_name: "tax 2",
              tax_code: "tax_2",
              tax_rate: 12.0,
              tax_description: "type2"
            )
          end

          before do
            fee1
            fee1_applied_tax1
            fee2
            fee2_applied_tax_1
            fee2_applied_tax_2
          end

          it "creates applied taxes" do
            result = apply_service.call

            expect(result).to be_success

            applied_taxes = result.applied_taxes
            expect(applied_taxes.count).to eq(2)

            expect(applied_taxes.find { |item| item.tax_code == "tax_1" }).to have_attributes(
              invoice:,
              tax_description: "type1",
              tax_code: "tax_1",
              tax_name: "tax 1",
              tax_rate: 10,
              amount_currency: invoice.currency,
              amount_cents: 300,
              fees_amount_cents: 3000,
              taxable_base_amount_cents: 3000
            )

            expect(applied_taxes.find { |item| item.tax_code == "tax_2" }).to have_attributes(
              invoice:,
              tax_description: "type2",
              tax_code: "tax_2",
              tax_name: "tax 2",
              tax_rate: 12,
              amount_currency: invoice.currency,
              amount_cents: 240,
              fees_amount_cents: 2000,
              taxable_base_amount_cents: 2000
            )

            expect(invoice).to have_attributes(
              taxes_amount_cents: 540,
              taxes_rate: 18,
              fees_amount_cents: 3000
            )
          end

          context "when there is tax deduction" do
            let(:fee1) do
              create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0, taxes_base_rate: 0.8)
            end
            let(:fee1_applied_tax1) do
              create(
                :fee_applied_tax,
                fee: fee1,
                amount_cents: 80,
                tax_name: "tax 1",
                tax_code: "tax_1",
                tax_rate: 10.0,
                tax_description: "type1"
              )
            end
            let(:fee2) do
              create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0, taxes_base_rate: 0.8)
            end
            let(:fee2_applied_tax_1) do
              create(
                :fee_applied_tax,
                fee: fee2,
                amount_cents: 160,
                tax_name: "tax 1",
                tax_code: "tax_1",
                tax_rate: 10.0,
                tax_description: "type1"
              )
            end
            let(:fee2_applied_tax_2) do
              create(
                :fee_applied_tax,
                fee: fee2,
                amount_cents: 192,
                tax_name: "tax 2",
                tax_code: "tax_2",
                tax_rate: 12.0,
                tax_description: "type2"
              )
            end

            it "creates applied taxes" do
              result = apply_service.call

              expect(result).to be_success

              applied_taxes = result.applied_taxes
              expect(applied_taxes.count).to eq(2)

              expect(applied_taxes.find { |item| item.tax_code == "tax_1" }).to have_attributes(
                invoice:,
                tax_description: "type1",
                tax_code: "tax_1",
                tax_name: "tax 1",
                tax_rate: 10,
                amount_currency: invoice.currency,
                amount_cents: 240,
                fees_amount_cents: 3000,
                taxable_base_amount_cents: 2400
              )

              expect(applied_taxes.find { |item| item.tax_code == "tax_2" }).to have_attributes(
                invoice:,
                tax_description: "type2",
                tax_code: "tax_2",
                tax_name: "tax 2",
                tax_rate: 12,
                amount_currency: invoice.currency,
                amount_cents: 192,
                fees_amount_cents: 2000,
                taxable_base_amount_cents: 1600
              )

              expect(invoice).to have_attributes(
                taxes_amount_cents: 432,
                taxes_rate: 18,
                fees_amount_cents: 3000
              )
            end
          end
        end

        context "with special provider rules" do
          special_rules =
            [
              {received_type: "notCollecting", expected_name: "Not collecting", tax_code: "not_collecting"},
              {received_type: "productNotTaxed", expected_name: "Product not taxed", tax_code: "product_not_taxed"},
              {received_type: "jurisNotTaxed", expected_name: "Juris not taxed", tax_code: "juris_not_taxed"}
            ]
          special_rules.each do |applied_rule|
            context "when tax provider returned specific rule applied to fees - #{applied_rule[:expected_name]}" do
              let(:fee_taxes) do
                [
                  OpenStruct.new(
                    tax_amount_cents: 0,
                    tax_breakdown: [
                      OpenStruct.new(name: applied_rule[:expected_name], type: applied_rule[:received_type],
                        rate: "0.00", tax_amount: 0)
                    ]
                  ),
                  OpenStruct.new(
                    tax_amount_cents: 0,
                    tax_breakdown: [
                      OpenStruct.new(name: applied_rule[:expected_name], type: applied_rule[:received_type],
                        rate: "0.00", tax_amount: 0)
                    ]
                  )
                ]
              end
              let(:fee1) { create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0) }
              let(:fee2) { create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0) }
              let(:fee1_applied_tax) do
                create(:fee_applied_tax, fee: fee1, amount_cents: 0, tax_name: applied_rule[:expected_name],
                  tax_code: applied_rule[:tax_code], tax_rate: 0.0, tax_description: applied_rule[:received_type])
              end
              let(:fee2_applied_tax) do
                create(:fee_applied_tax, fee: fee2, amount_cents: 0, tax_name: applied_rule[:expected_name],
                  tax_code: applied_rule[:tax_code], tax_rate: 0.0, tax_description: applied_rule[:received_type])
              end

              before do
                fee1_applied_tax
                fee2_applied_tax
              end

              it "creates applied taxes with #{applied_rule[:expected_name]} params" do
                result = apply_service.call

                expect(result).to be_success

                applied_taxes = result.applied_taxes
                expect(applied_taxes.count).to eq(1)
                applied_taxes.each do |applied_tax|
                  expect(applied_tax.tax_description).to eq(applied_rule[:received_type])
                  expect(applied_tax.tax_code).to eq(applied_rule[:tax_code])
                  expect(applied_tax.tax_name).to eq(applied_rule[:expected_name])
                  expect(applied_tax.tax_rate).to eq(0.0)
                end
              end
            end
          end
        end

        context "with seller paying taxes" do
          let(:fee_taxes) do
            [
              OpenStruct.new(
                tax_amount_cents: 0,
                tax_breakdown: [OpenStruct.new(name: "Tax", type: "tax", rate: "0.00", tax_amount: 0)]
              ),
              OpenStruct.new(
                tax_amount_cents: 0,
                tax_breakdown: [OpenStruct.new(name: "Tax", type: "tax", rate: "0.00", tax_amount: 0)]
              )
            ]
          end
          let(:fee1) { create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0) }
          let(:fee2) { create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0) }
          let(:fee1_applied_tax) do
            create(:fee_applied_tax, fee: fee1, amount_cents: 0, tax_name: "Tax", tax_code: "tax", tax_rate: 0.0, tax_description: "tax")
          end
          let(:fee2_applied_tax) do
            create(:fee_applied_tax, fee: fee2, amount_cents: 0, tax_name: "Tax", tax_code: "tax", tax_rate: 0.0, tax_description: "tax")
          end

          before do
            fee1_applied_tax
            fee2_applied_tax
          end

          it "does creates zero-tax" do
            result = apply_service.call

            expect(result).to be_success

            applied_taxes = result.applied_taxes
            expect(applied_taxes.count).to eq(1)
            expect(applied_taxes.find { |item| item.tax_code == "tax" }).to have_attributes(
              invoice:,
              tax_description: "tax",
              tax_code: "tax",
              tax_name: "Tax",
              tax_rate: 0,
              amount_currency: invoice.currency,
              amount_cents: 0,
              fees_amount_cents: 3000
            )
          end
        end
      end
    end

    context "when applying taxes for draft invoice" do
      let(:invoice) do
        create(
          :invoice,
          :draft,
          organization:,
          customer:,
          fees_amount_cents:,
          coupons_amount_cents:,
          sub_total_excluding_taxes_amount_cents: fees_amount_cents - coupons_amount_cents
        )
      end

      before do
        result.fees = fee_taxes
        allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to receive(:call)
          .with(invoice:)
          .and_return(result)
      end

      context "with non zero fees amount" do
        before do
          fee1 = create(:fee, invoice:, amount_cents: 1000, precise_coupons_amount_cents: 0)
          create(
            :fee_applied_tax,
            fee: fee1,
            amount_cents: 100,
            tax_name: "tax 1",
            tax_code: "tax_1",
            tax_rate: 10.0,
            tax_description: "type1"
          )

          fee2 = create(:fee, invoice:, amount_cents: 2000, precise_coupons_amount_cents: 0)

          create(
            :fee_applied_tax,
            fee: fee2,
            amount_cents: 200,
            tax_name: "tax 1",
            tax_code: "tax_1",
            tax_rate: 10.0,
            tax_description: "type1"
          )
          create(
            :fee_applied_tax,
            fee: fee2,
            amount_cents: 240,
            tax_name: "tax 2",
            tax_code: "tax_2",
            tax_rate: 12.0,
            tax_description: "type2"
          )
        end

        it "creates applied taxes" do
          result = apply_service.call

          expect(result).to be_success

          applied_taxes = result.applied_taxes
          expect(applied_taxes.count).to eq(2)

          expect(applied_taxes.find { |item| item.tax_code == "tax_1" }).to have_attributes(
            invoice:,
            tax_description: "type1",
            tax_code: "tax_1",
            tax_name: "tax 1",
            tax_rate: 10,
            amount_currency: invoice.currency,
            amount_cents: 300,
            fees_amount_cents: 3000
          )

          expect(applied_taxes.find { |item| item.tax_code == "tax_2" }).to have_attributes(
            invoice:,
            tax_description: "type2",
            tax_code: "tax_2",
            tax_name: "tax 2",
            tax_rate: 12,
            amount_currency: invoice.currency,
            amount_cents: 240,
            fees_amount_cents: 2000
          )

          expect(invoice).to have_attributes(
            taxes_amount_cents: 540,
            taxes_rate: 18,
            fees_amount_cents: 3000
          )
          expect(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to have_received(:call)
        end
      end
    end
  end
end
