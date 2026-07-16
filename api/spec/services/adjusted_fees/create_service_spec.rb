# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdjustedFees::CreateService do
  subject(:create_service) { described_class.new(invoice:, params:) }

  let(:customer) { create(:customer) }
  let(:invoice) { create(:invoice, :subscription, :draft, customer:, subscriptions: [subscription], organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, plan:, customer:) }
  let(:organization) { customer.organization }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, billable_metric:, plan: subscription.plan) }
  let(:charge_filter) { create(:charge_filter, charge:) }

  let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, charge_filter:) }
  let(:code) { "tax_code" }
  let(:params) do
    {
      fee_id: fee.id,
      units: 5,
      unit_precise_amount: 12.002,
      invoice_display_name: "new-dis-name"
    }
  end

  describe "#call" do
    before do
      allow(Invoices::RefreshDraftService)
        .to receive(:call).with(invoice: invoice)
        .and_return(BaseService::Result.new)
    end

    context "when license is premium", :premium do
      it "creates an adjusted fee" do
        expect { create_service.call }.to change(AdjustedFee, :count).by(1)
      end

      it "returns adjusted fee in the result" do
        result = create_service.call
        expect(result.adjusted_fee).to be_a(AdjustedFee)
      end

      it "returns fee in the result" do
        result = create_service.call
        expect(result.fee).to be_a(Fee)
      end

      it "calls the RefreshDraft service" do
        create_service.call

        expect(Invoices::RefreshDraftService).to have_received(:call)
      end

      it "populates precise and not precise values for the created adjusted fee" do
        result = create_service.call
        expect(result.adjusted_fee).to have_attributes(
          units: 5,
          unit_amount_cents: 1200,
          unit_precise_amount_cents: 1200.2
        )
      end

      context "when invoice is NOT in draft status" do
        before { invoice.finalized! }

        it "returns forbidden status" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
          expect(result.error.code).to eq("feature_unavailable")
        end
      end

      context "when there is invalid charge model but amount is adjusted" do
        let(:percentage_charge) { create(:percentage_charge) }
        let(:fee) { create(:charge_fee, invoice:, subscription:, charge: percentage_charge) }

        it "returns success response" do
          result = create_service.call

          expect(result).to be_success
        end
      end

      context "when there is invalid charge model and display name is adjusted" do
        let(:percentage_charge) { create(:percentage_charge) }
        let(:fee) { create(:charge_fee, invoice:, subscription:, charge: percentage_charge) }
        let(:params) do
          {
            fee_id: fee.id,
            invoice_display_name: "new-dis-name"
          }
        end

        it "returns success response" do
          result = create_service.call

          expect(result).to be_success
        end
      end

      context "when there is invalid charge model and units are adjusted" do
        let(:percentage_charge) { create(:percentage_charge) }
        let(:fee) { create(:charge_fee, invoice:, subscription:, charge: percentage_charge) }
        let(:params) do
          {
            fee_id: fee.id,
            units: 5,
            invoice_display_name: "new-dis-name"
          }
        end

        it "returns error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:charge]).to eq(["invalid_charge_model"])
        end
      end

      context "when fee belongs to another invoice" do
        let(:fee) { create(:charge_fee) }

        it "returns error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("fee_not_found")
        end
      end

      context "when adjusted fee already exists" do
        let(:adjusted_fee) { create(:adjusted_fee, fee:) }

        before { adjusted_fee }

        it "returns validation error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:adjusted_fee]).to eq(["already_exists"])
        end
      end

      context "when adjusting without fee" do
        let(:fee) { nil }
        let(:params) do
          {
            units: 5,
            unit_precise_amount: 12.002,
            invoice_display_name: "new-dis-name",
            subscription_id: subscription.id,
            charge_id: charge.id,
            charge_filter_id: charge_filter.id
          }
        end

        it "creates an adjusted fee and a fee" do
          expect { create_service.call }
            .to change(AdjustedFee, :count).by(1)
            .and change(Fee, :count).by(1)
        end

        it "returns adjusted fee in the result" do
          result = create_service.call
          expect(result.adjusted_fee)
            .to be_a(AdjustedFee)
            .and have_attributes(
              fee: Fee,
              invoice:,
              subscription:,
              charge:,
              adjusted_units: false,
              adjusted_amount: true,
              invoice_display_name: "new-dis-name",
              fee_type: "charge",
              units: 5,
              unit_amount_cents: 1200,
              unit_precise_amount_cents: 1200.2,
              grouped_by: {},
              charge_filter:
            )
        end

        it "returns fee in the result" do
          result = create_service.call
          expect(result.fee)
            .to be_a(Fee)
            .and have_attributes(
              organization:,
              invoice:,
              subscription:,
              invoiceable: charge,
              charge:,
              charge_filter:,
              grouped_by: {},
              fee_type: "charge",
              payment_status: "pending",
              events_count: 0,
              amount_currency: invoice.currency,
              amount_cents: 0,
              precise_amount_cents: 0.to_d,
              unit_amount_cents: 0,
              precise_unit_amount: 0.to_d,
              taxes_amount_cents: 0,
              taxes_precise_amount_cents: 0.to_d,
              units: 0,
              total_aggregated_units: 0,
              properties: Hash,
              amount_details: {}
            )
        end

        it "calls the RefreshDraft service" do
          create_service.call

          expect(Invoices::RefreshDraftService).to have_received(:call)
        end

        context "when adjusting a dynamic charge" do
          let(:billable_metric) { create(:sum_billable_metric, organization:) }
          let(:charge) { create(:dynamic_charge, billable_metric:, plan: subscription.plan) }

          it "creates an adjusted fee and a fee" do
            expect { create_service.call }
              .to change(AdjustedFee, :count).by(1)
              .and change(Fee, :count).by(1)
          end
        end

        context "when a fee exists with the attributes" do
          let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, charge_filter:) }
          let(:params) do
            {
              units: 5,
              unit_precise_amount: 12.002,
              invoice_display_name: "new-dis-name",
              subscription_id: subscription.id,
              charge_id: fee.charge_id,
              charge_filter_id: fee.charge_filter_id
            }
          end

          it "creates an adjusted fee for the fee" do
            result = create_service.call
            expect(result.adjusted_fee)
              .to be_a(AdjustedFee)
              .and have_attributes(fee:)
          end
        end

        context "when subscription_id does not belongs to the invoice" do
          let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, charge_filter:) }
          let(:params) do
            {
              units: 5,
              unit_precise_amount: 12.002,
              invoice_display_name: "new-dis-name",
              subscription_id: "invalid_id",
              charge_id: fee.charge_id,
              charge_filter_id: fee.charge_filter_id
            }
          end

          it "returns a not found error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("subscription_not_found")
          end
        end

        context "when charge_id does not belongs to the invoice" do
          let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, charge_filter:) }
          let(:params) do
            {
              units: 5,
              unit_precise_amount: 12.002,
              invoice_display_name: "new-dis-name",
              subscription_id: subscription.id,
              charge_id: "invalid_id",
              charge_filter_id: fee.charge_filter_id
            }
          end

          it "returns a not found error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("charge_not_found")
          end
        end

        context "when charge_filter_id does not belongs to the invoice" do
          let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, charge_filter:) }
          let(:params) do
            {
              units: 5,
              unit_precise_amount: 12.002,
              invoice_display_name: "new-dis-name",
              subscription_id: subscription.id,
              charge_id: charge.id,
              charge_filter_id: "invalid_id"
            }
          end

          it "returns a not found error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("charge_filter_not_found")
          end
        end
      end

      context "when adjusting fixed charge fees" do
        let(:add_on) { create(:add_on, organization:) }
        let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }
        let(:fixed_charge_fee) { create(:fixed_charge_fee, invoice:, subscription:, fixed_charge:) }
        let(:params) do
          {
            fee_id: fixed_charge_fee.id,
            units: 10,
            unit_precise_amount: 15.5,
            invoice_display_name: "Fixed charge adjusted"
          }
        end

        it "creates an adjusted fee for fixed charge" do
          expect { create_service.call }.to change(AdjustedFee, :count).by(1)
        end

        it "returns adjusted fee with fixed_charge set" do
          result = create_service.call
          expect(result.adjusted_fee).to be_a(AdjustedFee)
          expect(result.adjusted_fee).to have_attributes(
            fixed_charge:,
            charge: nil,
            fee_type: "fixed_charge",
            units: 10,
            unit_amount_cents: 1550,
            unit_precise_amount_cents: 1550.0,
            invoice_display_name: "Fixed charge adjusted"
          )
        end

        it "returns fee in the result" do
          result = create_service.call
          expect(result.fee).to be_a(Fee)
          expect(result.fee).to have_attributes(
            fixed_charge:,
            charge: nil,
            fee_type: "fixed_charge",
            units: 0.0,
            unit_amount_cents: 0,
            precise_amount_cents: 200.0000000001,
            properties: hash_including(
              "fixed_charges_from_datetime" => fixed_charge_fee.properties["fixed_charges_from_datetime"],
              "fixed_charges_to_datetime" => fixed_charge_fee.properties["fixed_charges_to_datetime"]
            )
          )
        end

        it "calls the RefreshDraft service" do
          create_service.call

          expect(Invoices::RefreshDraftService).to have_received(:call)
        end

        context "when adjusting units only" do
          let(:params) do
            {
              fee_id: fixed_charge_fee.id,
              units: 10,
              invoice_display_name: "Fixed charge adjusted"
            }
          end

          it "sets adjusted_units to true" do
            result = create_service.call
            expect(result.adjusted_fee).to have_attributes(
              adjusted_units: true,
              adjusted_amount: false
            )
          end
        end

        context "when adjusting both units and amount" do
          it "sets adjusted_amount to true" do
            result = create_service.call
            expect(result.adjusted_fee).to have_attributes(
              adjusted_units: false,
              adjusted_amount: true
            )
          end
        end

        context "when creating fee from scratch for fixed charge" do
          let(:params) do
            {
              units: 8,
              unit_precise_amount: 20.5,
              invoice_display_name: "New fixed charge fee",
              subscription_id: subscription.id,
              fixed_charge_id: fixed_charge.id
            }
          end

          it "creates an adjusted fee and a fee" do
            expect { create_service.call }
              .to change(AdjustedFee, :count).by(1)
              .and change(Fee, :count).by(1)
          end

          it "returns adjusted fee with correct attributes" do
            result = create_service.call
            expect(result.adjusted_fee).to be_a(AdjustedFee)
            expect(result.adjusted_fee).to have_attributes(
              fixed_charge:,
              fee_type: "fixed_charge",
              units: 8,
              unit_amount_cents: 2050,
              unit_precise_amount_cents: 2050.0
            )
          end

          it "returns fee with correct attributes" do
            result = create_service.call
            expect(result.fee).to be_a(Fee)
            expect(result.fee).to have_attributes(
              fixed_charge:,
              fee_type: "fixed_charge",
              invoiceable: fixed_charge
            )
          end
        end

        context "when fixed_charge does not exist" do
          let(:params) do
            {
              units: 8,
              subscription_id: subscription.id,
              fixed_charge_id: "invalid_id"
            }
          end

          it "returns a not found error" do
            result = create_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("fixed_charge_not_found")
          end
        end

        context "when prorated graduated fixed charge with units adjustment" do
          let(:fixed_charge) do
            create(
              :fixed_charge,
              :graduated,
              plan: subscription.plan,
              add_on:,
              prorated: true,
              properties: {
                graduated_ranges: [
                  {
                    from_value: 0,
                    to_value: 10,
                    per_unit_amount: "1.5",
                    flat_amount: "15"
                  },
                  {
                    from_value: 11,
                    to_value: nil,
                    per_unit_amount: "2",
                    flat_amount: "20"
                  }
                ]
              }
            )
          end
          let(:params) do
            {
              fee_id: fixed_charge_fee.id,
              units: 20
            }
          end

          it "returns success" do
            result = create_service.call

            expect(result).to be_success
            expect(result.adjusted_fee).to be_a(AdjustedFee)
            expect(result.adjusted_fee).to have_attributes(
              adjusted_units: true,
              adjusted_amount: false,
              units: 20
            )
          end
        end

        context "when prorated graduated fixed charge with amount adjustment" do
          let(:fixed_charge) do
            create(
              :fixed_charge,
              :graduated,
              plan: subscription.plan,
              add_on:,
              prorated: true
            )
          end
          let(:params) do
            {
              fee_id: fixed_charge_fee.id,
              units: 10,
              unit_precise_amount: 15.5,
              invoice_display_name: "Fixed charge adjusted"
            }
          end

          it "returns success" do
            result = create_service.call
            expect(result).to be_success
          end
        end
      end
    end

    context "when called from Invoices::RegenerateFromVoidedService flow (with regenerating_voided: true)" do
      it "returns success without calling RefreshDraftService" do
        result = described_class.new(invoice:, params:, regenerating_voided: true).call

        expect(result).to be_success
        expect(result.fee).to be_a(Fee)
        expect(result.adjusted_fee).to be_a(AdjustedFee)
        expect(Invoices::RefreshDraftService).not_to have_received(:call)
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end

      context "when called from Invoices::RegenerateFromVoidedService flow (with regenerating_voided: true)" do
        it "skips license check" do
          result = described_class.new(invoice:, params:, regenerating_voided: true).call
          expect(result).to be_success
        end
      end
    end
  end
end
