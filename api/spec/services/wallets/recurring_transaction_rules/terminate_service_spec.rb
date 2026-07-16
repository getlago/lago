# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RecurringTransactionRules::TerminateService do
  subject(:terminate_service) { described_class.new(recurring_transaction_rule:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:) }
  let(:recurring_transaction_rule) do
    create(
      :recurring_transaction_rule,
      wallet: wallet,
      status: "active",
      expiration_at: Time.zone.now - 40.days
    )
  end

  describe "#call" do
    it "terminates the recurring transaction rule" do
      result = terminate_service.call

      expect(result).to be_success
      expect(recurring_transaction_rule.reload).to be_terminated
    end

    context "when the recurring transaction rule is already terminated" do
      before do
        recurring_transaction_rule.mark_as_terminated!
      end

      it "does not change the termination date" do
        terminated_at = recurring_transaction_rule.terminated_at

        result = terminate_service.call

        expect(result).to be_success
        expect(recurring_transaction_rule.reload).to be_terminated
        expect(recurring_transaction_rule.terminated_at).to eq(terminated_at)
      end
    end
  end
end
