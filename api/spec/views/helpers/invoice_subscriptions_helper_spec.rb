# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceSubscriptionsHelper do
  subject(:helper) { described_class }

  describe ".load_subscriptions_with_fees" do
    subject(:result) { helper.load_subscriptions_with_fees(invoice) }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:plan) { create(:plan, organization:) }
    let(:subscription) { create(:subscription, customer:, plan:) }
    let(:invoice) { create(:invoice, customer:, organization:) }
    let!(:invoice_subscription) { create(:invoice_subscription, subscription:, invoice:) }

    it "returns one SubscriptionWithFees per subscription" do
      expect(result.size).to eq(1)
      expect(result.first).to be_a(InvoiceSubscriptionsHelper::SubscriptionWithFees)
    end

    it "sets subscription and invoice_subscription correctly" do
      expect(result.first.subscription).to eq(subscription)
      expect(result.first.invoice_subscription).to eq(invoice_subscription)
    end

    context "with multiple subscriptions" do
      let(:subscription_2) { create(:subscription, customer:, plan:) }
      let!(:invoice_subscription_2) { create(:invoice_subscription, subscription: subscription_2, invoice:) }

      it "returns one entry per subscription in sorted order" do
        expect(result.map(&:subscription)).to match_array([subscription, subscription_2])
      end

      it "sets the invoice_subscription independently for each" do
        by_sub = result.index_by(&:subscription)
        expect(by_sub[subscription].invoice_subscription).to eq(invoice_subscription)
        expect(by_sub[subscription_2].invoice_subscription).to eq(invoice_subscription_2)
      end
    end

    describe "filtered_fees" do
      subject(:filtered_fees) { result.first.filtered_fees }

      context "when there is a subscription fee" do
        let!(:subscription_fee) { create(:fee, fee_type: "subscription", subscription:, invoice:) }

        it { is_expected.to include(subscription_fee) }
      end

      context "when there is a commitment fee" do
        let!(:commitment_fee) { create(:minimum_commitment_fee, subscription:, invoice:) }

        it { is_expected.to include(commitment_fee) }
      end

      context "when there is a fixed_charge fee" do
        context "with positive units" do
          let!(:fixed_charge_fee) { create(:fixed_charge_fee, subscription:, invoice:, units: 1) }

          it { is_expected.to include(fixed_charge_fee) }
        end

        context "with zero units" do
          let!(:fixed_charge_fee) { create(:fixed_charge_fee, subscription:, invoice:, units: 0) }

          it { is_expected.not_to include(fixed_charge_fee) }
        end
      end

      context "when there is a charge fee" do
        context "with positive units and no true_up_parent_fee" do
          let!(:charge_fee) { create(:charge_fee, subscription:, invoice:, units: 5, total_aggregated_units: 5) }

          it { is_expected.to include(charge_fee) }
        end

        context "with zero units and no true_up_parent_fee" do
          let!(:charge_fee) { create(:charge_fee, subscription:, invoice:, units: 0, total_aggregated_units: 0) }

          it { is_expected.not_to include(charge_fee) }
        end

        context "with zero units but is the parent of a true_up fee" do
          let!(:parent_fee) { create(:charge_fee, subscription:, invoice:, units: 0, total_aggregated_units: 0) }
          let!(:true_up_fee) { create(:charge_fee, subscription:, invoice:, units: 5, total_aggregated_units: 5, true_up_parent_fee: parent_fee) }

          it "includes the parent fee" do
            expect(filtered_fees).to include(parent_fee)
          end

          it "excludes the true_up fee itself" do
            expect(filtered_fees).not_to include(true_up_fee)
          end
        end
      end
    end
  end
end
