# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ComputeTaxesAndTotalsService do
  subject(:totals_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    let(:invoice) do
      create(
        :invoice,
        :finalized,
        :with_subscriptions,
        customer:,
        organization:,
        subscriptions: [subscription],
        currency: "EUR",
        issuing_date: Time.zone.at(timestamp).to_date
      )
    end

    let(:subscription) do
      create(
        :subscription,
        plan:,
        subscription_at: started_at,
        started_at:,
        created_at: started_at
      )
    end

    let(:timestamp) { Time.zone.now - 1.year }
    let(:started_at) { Time.zone.now - 2.years }
    let(:plan) { create(:plan, organization:, interval: "monthly") }
    let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
    let(:charge) { create(:standard_charge, plan: subscription.plan, charge_model: "standard", billable_metric:) }

    let(:fee_subscription) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 2_000
      )
    end
    let(:fee_charge) do
      create(
        :fee,
        invoice:,
        charge:,
        fee_type: :charge,
        total_aggregated_units: 100,
        amount_cents: 1_000
      )
    end

    before do
      fee_subscription
      fee_charge
    end

    context "when invoice does not exist" do
      it "returns an error" do
        result = described_class.new(invoice: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when customer has VIES check in progress" do
      let(:billing_entity) { create(:billing_entity, organization:, eu_tax_management: true) }
      let(:customer) { create(:customer, organization:, billing_entity:) }

      before { create(:pending_vies_check, customer:) }

      it "returns an unknown tax failure" do
        result = totals_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::UnknownTaxFailure)
        expect(result.error.code).to eq("vies_check_pending")
      end

      it "sets invoice status to pending" do
        totals_service.call

        expect(invoice.reload.status).to eq("pending")
        expect(invoice.reload.tax_status).to eq("pending")
      end

      context "when not finalizing" do
        subject(:totals_service) { described_class.new(invoice:, finalizing: false) }

        before { invoice.update!(status: :draft) }

        it "does not change invoice status but sets tax_status" do
          totals_service.call

          expect(invoice.reload.status).to eq("draft")
          expect(invoice.reload.tax_status).to eq("pending")
        end
      end

      context "when customer also has tax provider" do
        let(:integration) { create(:anrok_integration, organization:) }

        before { create(:anrok_customer, integration:, customer:) }

        it "uses tax provider instead of blocking for VIES" do
          expect { totals_service.call }
            .to have_enqueued_job(Invoices::ProviderTaxes::PullTaxesAndApplyJob).with(invoice:)
        end

        it "does not return vies_check_pending error" do
          result = totals_service.call

          expect(result.error.code).to eq("tax_error")
        end
      end
    end

    context "when there is tax provider" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

      before do
        integration_customer
      end

      it "enqueues a Invoices::ProviderTaxes::PullTaxesAndApplyJob" do
        expect do
          totals_service.call
        end.to have_enqueued_job(Invoices::ProviderTaxes::PullTaxesAndApplyJob).with(invoice:)
      end

      it "sets correct statuses on invoice" do
        totals_service.call

        expect(invoice.reload.status).to eq("pending")
        expect(invoice.reload.tax_status).to eq("pending")
      end

      context "when invoice is subscription_gated" do
        let(:subscription) do
          create(:subscription, :incomplete, :with_activation_rules,
            activation_rules_config: [{type: :payment, timeout_hours: 48, status: :pending}],
            plan:, subscription_at: started_at, started_at:, created_at: started_at)
        end

        before { invoice.update!(status: :open) }

        it "keeps invoice status as open and sets tax_status to pending" do
          totals_service.call

          expect(invoice.reload).to be_open
          expect(invoice.reload).to be_tax_pending
        end
      end

      context "when invoice is draft" do
        before { invoice.update!(status: :draft) }

        it "sets only tax status" do
          described_class.new(invoice:, finalizing: false).call

          expect(invoice.reload.status).to eq("draft")
          expect(invoice.reload.tax_status).to eq("pending")
        end
      end

      context "when there is no fees" do
        let(:fee_subscription) { nil }
        let(:fee_charge) { nil }
        let(:result) { BaseService::Result.new }

        before do
          allow(Invoices::ComputeAmountsFromFees).to receive(:call)
            .with(invoice:)
            .and_return(result)
        end

        it "calls compute amounts service" do
          totals_service.call

          expect(Invoices::ComputeAmountsFromFees).to have_received(:call)
        end

        it "does not enqueue a Invoices::ProviderTaxes::PullTaxesAndApplyJob" do
          expect do
            totals_service.call
          end.not_to have_enqueued_job(Invoices::ProviderTaxes::PullTaxesAndApplyJob).with(invoice:)
        end
      end

      context "with zero amount invoice" do
        let(:fee_charge) { nil }
        let(:result) { BaseService::Result.new }
        let(:fee_subscription) do
          create(
            :fee,
            invoice:,
            subscription:,
            fee_type: :subscription,
            amount_cents: 0
          )
        end

        before do
          allow(Invoices::ComputeAmountsFromFees).to receive(:call)
            .with(invoice:)
            .and_return(result)
        end

        context "when skip zero amount invoice configuration is used" do
          let(:customer) { create(:customer, organization:, finalize_zero_amount_invoice: "skip") }

          it "calls compute amounts service" do
            totals_service.call

            expect(Invoices::ComputeAmountsFromFees).to have_received(:call)
          end

          it "does not enqueue a Invoices::ProviderTaxes::PullTaxesAndApplyJob" do
            expect do
              totals_service.call
            end.not_to have_enqueued_job(Invoices::ProviderTaxes::PullTaxesAndApplyJob).with(invoice:)
          end
        end

        context "when finalize zero amount invoice configuration is used" do
          let(:customer) { create(:customer, organization:, finalize_zero_amount_invoice: "finalize") }

          it "does not call compute amounts service" do
            totals_service.call

            expect(Invoices::ComputeAmountsFromFees).not_to have_received(:call)
          end

          it "enqueues a Invoices::ProviderTaxes::PullTaxesAndApplyJob" do
            expect do
              totals_service.call
            end.to have_enqueued_job(Invoices::ProviderTaxes::PullTaxesAndApplyJob).with(invoice:)
          end
        end
      end
    end

    context "when there is NO tax provider" do
      let(:result) { BaseService::Result.new }

      before do
        allow(Invoices::ComputeAmountsFromFees).to receive(:call)
          .with(invoice:)
          .and_return(result)
      end

      it "calls the add on create service" do
        totals_service.call

        expect(Invoices::ComputeAmountsFromFees).to have_received(:call)
      end
    end
  end
end
