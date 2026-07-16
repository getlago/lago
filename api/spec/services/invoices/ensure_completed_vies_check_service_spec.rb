# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::EnsureCompletedViesCheckService do
  subject(:result) { described_class.call(invoice:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:invoice) { create(:invoice, customer:, organization:, billing_entity:, status: :generating) }

  describe "#call" do
    context "when invoice is nil" do
      let(:invoice) { nil }

      it "returns not found failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("invoice_not_found")
      end
    end

    context "when EU tax management is disabled" do
      before { billing_entity.update!(eu_tax_management: false) }

      it "returns success" do
        expect(result).to be_success
        expect(invoice.reload.status).to eq("generating")
      end

      context "when pending_vies_check exists" do
        before { create(:pending_vies_check, customer:) }

        it "returns success without changing invoice status" do
          expect(result).to be_success
          expect(invoice.reload.status).to eq("generating")
        end
      end
    end

    context "when EU tax management is enabled" do
      before { billing_entity.update!(eu_tax_management: true) }

      context "when VIES check is not in progress" do
        it "returns success" do
          expect(result).to be_success
          expect(invoice.reload.status).to eq("generating")
        end
      end

      context "when VIES check is in progress" do
        before { create(:pending_vies_check, customer:) }

        it "sets invoice to pending status and returns unknown tax failure" do
          expect(result).to be_failure
          expect(result.error).to be_a(BaseService::UnknownTaxFailure)
          expect(result.error.code).to eq("vies_check_pending")
          expect(invoice.reload.status).to eq("pending")
          expect(invoice.tax_status).to eq("pending")
        end

        context "when invoice is subscription_gated" do
          let(:subscription) do
            create(:subscription, :incomplete, :with_activation_rules,
              activation_rules_config: [{type: :payment, timeout_hours: 48, status: :pending}],
              customer:, organization:)
          end
          let(:invoice) { create(:invoice, :with_subscriptions, customer:, organization:, billing_entity:, status: :open, subscriptions: [subscription]) }

          it "keeps invoice status as open and sets tax_status to pending" do
            expect(result).to be_failure
            expect(invoice.reload).to be_open
            expect(invoice).to be_tax_pending
          end
        end

        context "when finalizing is false" do
          subject(:result) { described_class.call(invoice:, finalizing: false) }

          let(:invoice) { create(:invoice, customer:, organization:, billing_entity:, status: :draft) }

          it "does not change invoice status but sets tax_status to pending" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::UnknownTaxFailure)
            expect(result.error.code).to eq("vies_check_pending")
            expect(invoice.reload.status).to eq("draft")
            expect(invoice.tax_status).to eq("pending")
          end
        end
      end

      context "when customer has provider taxation" do
        before { create(:anrok_customer, customer:) }

        it "returns success" do
          expect(result).to be_success
          expect(invoice.reload.status).to eq("generating")
        end

        context "when VIES check is in progress" do
          before { create(:pending_vies_check, customer:) }

          it "returns success without changing invoice status" do
            expect(result).to be_success
            expect(invoice.reload.status).to eq("generating")
          end
        end
      end
    end
  end
end
