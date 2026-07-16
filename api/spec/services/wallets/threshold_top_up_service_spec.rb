# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::ThresholdTopUpService do
  subject(:top_up_service) { described_class.new(wallet:) }

  let(:wallet) do
    create(
      :wallet,
      balance_cents: 1000,
      ongoing_balance_cents: 550,
      ongoing_usage_balance_cents: 450,
      credits_balance: 10.0,
      credits_ongoing_balance: 5.5,
      credits_ongoing_usage_balance: 4.0,
      paid_top_up_min_amount_cents: 205_50
    )
  end

  describe "#call" do
    let(:recurring_transaction_rule) do
      create(
        :recurring_transaction_rule,
        wallet:,
        trigger: "threshold",
        threshold_credits: "6.0",
        paid_credits: "10.0",
        granted_credits: "3.0",
        ignore_paid_top_up_limits: true
      )
    end

    before { recurring_transaction_rule }

    it "calls wallet transaction create job with expected params" do
      expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
        .with(
          organization_id: wallet.organization.id,
          params: {
            wallet_id: wallet.id,
            paid_credits: "10.0",
            granted_credits: "3.0",
            source: :threshold,
            invoice_requires_successful_payment: false,
            metadata: [],
            name: "Recurring Transaction Rule",
            ignore_paid_top_up_limits: true
          },
          unique_transaction: true
        )
    end

    context "when rule requires successful payment" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          paid_credits: "10.0",
          granted_credits: "3.0",
          invoice_requires_successful_payment: true
        )
      end

      it "calls wallet transaction create job with expected params" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: hash_including(invoice_requires_successful_payment: true, ignore_paid_top_up_limits: false),
            unique_transaction: true
          )
      end
    end

    context "when rule contains transaction metadata" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          paid_credits: "10.0",
          granted_credits: "3.0",
          transaction_metadata:
        )
      end

      let(:transaction_metadata) { [{"key" => "valid_value", "value" => "also_valid"}] }

      it "calls wallet transaction create job with expected params" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: hash_including(metadata: transaction_metadata),
            unique_transaction: true
          )
      end
    end

    context "when rule has invoice custom sections" do
      let(:invoice_custom_section) { create(:invoice_custom_section, organization: wallet.organization) }

      before do
        create(:recurring_rule_applied_invoice_custom_section,
          recurring_transaction_rule:,
          invoice_custom_section:)
      end

      it "forwards invoice_custom_section params to the job" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: hash_including(
              invoice_custom_section: {
                skip_invoice_custom_sections: false,
                invoice_custom_section_ids: [invoice_custom_section.id]
              }
            ),
            unique_transaction: true
          )
      end
    end

    context "when rule has skip_invoice_custom_sections" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          paid_credits: "10.0",
          granted_credits: "3.0",
          skip_invoice_custom_sections: true
        )
      end

      it "forwards the skip flag to the job without fallback to other sections" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: hash_including(
              invoice_custom_section: {
                skip_invoice_custom_sections: true,
                invoice_custom_section_ids: []
              }
            ),
            unique_transaction: true
          )
      end
    end

    context "when rule does not contain transaction_name" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          paid_credits: "10.0",
          granted_credits: "3.0",
          transaction_name: nil
        )
      end

      it "calls wallet transaction create job with the transaction name" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: hash_including(name: nil),
            unique_transaction: true
          )
      end
    end

    context "when border has NOT been crossed" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, wallet:, trigger: "threshold", threshold_credits: "2.0")
      end

      it "does not call wallet transaction create job" do
        expect { top_up_service.call }.not_to have_enqueued_job(WalletTransactions::CreateJob)
      end
    end

    context "with pending transactions" do
      it "does not call wallet transaction create job" do
        create(:wallet_transaction, wallet:, amount: 1.0, credit_amount: 1.0, status: "pending")

        expect { top_up_service.call }.not_to have_enqueued_job(WalletTransactions::CreateJob)
      end
    end

    context "when recurring_transaction_rule is expired" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          method: "target",
          target_ongoing_balance: "200",
          expiration_at: 1.day.ago
        )
      end

      it "does not call wallet transaction create job" do
        expect { top_up_service.call }.not_to have_enqueued_job(WalletTransactions::CreateJob)
      end
    end

    context "when method is target" do
      let(:recurring_transaction_rule) do
        create(
          :recurring_transaction_rule,
          wallet:,
          trigger: "threshold",
          threshold_credits: "6.0",
          method: "target",
          target_ongoing_balance: "200"
        )
      end

      it "calls wallet transaction create job with expected params" do
        expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
          .with(
            organization_id: wallet.organization.id,
            params: {
              wallet_id: wallet.id,
              paid_credits: "205.5", # the gap is 194.5 but min transaction is 205.5
              granted_credits: "0.0",
              source: :threshold,
              invoice_requires_successful_payment: false,
              metadata: [],
              name: "Recurring Transaction Rule",
              ignore_paid_top_up_limits: false
            },
            unique_transaction: true
          )
      end

      context "when grants_target_top_up is true" do
        let(:recurring_transaction_rule) do
          create(
            :recurring_transaction_rule,
            wallet:,
            trigger: "threshold",
            threshold_credits: "6.0",
            method: "target",
            target_ongoing_balance: "200",
            grants_target_top_up: true
          )
        end

        it "enqueues the raw gap as granted credits, bypassing the paid_top_up_min limit" do
          expect { top_up_service.call }.to have_enqueued_job(WalletTransactions::CreateJob)
            .with(
              organization_id: wallet.organization.id,
              params: hash_including(
                paid_credits: "0.0",
                granted_credits: "194.5"
              ),
              unique_transaction: true
            )
        end
      end
    end
  end
end
