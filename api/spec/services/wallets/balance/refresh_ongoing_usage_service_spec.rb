# frozen_string_literal: true

RSpec.describe Wallets::Balance::RefreshOngoingUsageService do
  let(:wallet) do
    create(
      :wallet,
      customer:,
      depleted_ongoing_balance:,
      balance_cents: 1000,
      ongoing_balance_cents: 800,
      ongoing_usage_balance_cents: 200,
      credits_balance: 10.0,
      credits_ongoing_balance: 8.0,
      credits_ongoing_usage_balance: 2.0
    )
  end

  let(:depleted_ongoing_balance) { false }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:first_subscription) do
    create(:subscription, organization:, customer:, started_at: Time.zone.now - 2.years)
  end
  let(:second_subscription) do
    create(:subscription, organization:, customer:, started_at: Time.zone.now - 1.year)
  end
  let(:timestamp) { Time.current }
  let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }

  let(:first_charge) do
    create(
      :standard_charge,
      plan: first_subscription.plan,
      billable_metric:,
      properties: {amount: "3"}
    )
  end
  let(:second_charge) do
    create(
      :standard_charge,
      plan: second_subscription.plan,
      billable_metric:,
      properties: {amount: "5"}
    )
  end

  let(:usage_amount_cents) { 1100 }
  let(:current_usage_fees) { [] }
  let(:draft_invoices_fees) { [] }
  let(:progressive_billing_fees) { [] }
  let(:pay_in_advance_fees) { [] }

  before do
    first_charge
    second_charge
    wallet
  end

  describe ".call" do
    subject(:result) do
      described_class.call(
        wallet:,
        usage_amount_cents:,
        current_usage_fees:,
        draft_invoices_fees:,
        progressive_billing_fees:,
        pay_in_advance_fees:
      )
    end

    context "when there are current usage fees" do
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:first_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 600, taxes_amount_cents: 0)
      end
      let(:second_fee) do
        create(:charge_fee, charge: second_charge, subscription: second_subscription,
          organization:, invoice:, amount_cents: 500, taxes_amount_cents: 0)
      end
      let(:current_usage_fees) { [first_fee, second_fee] }

      it "updates wallet ongoing balance" do
        expect { subject }
          .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(1100)
          .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(11.0)
          .and change(wallet, :ongoing_balance_cents).from(800).to(-100)
          .and change(wallet, :credits_ongoing_balance).from(8.0).to(-1.0)
      end

      it "returns the wallet" do
        expect(result.wallet).to eq(wallet)
      end
    end

    context "when there are paid in advance fees" do
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:current_usage_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 1100, taxes_amount_cents: 0)
      end
      let(:pay_in_advance_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 700, taxes_amount_cents: 0)
      end
      let(:current_usage_fees) { [current_usage_fee] }
      let(:pay_in_advance_fees) { [pay_in_advance_fee] }

      it "updates wallet ongoing balance by deducting pay in advance fees" do
        # total_usage = 1100, billed_pay_in_advance = 700
        # ongoing_usage = 1100 - 700 = 400
        expect { subject }
          .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(400)
          .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(4.0)
          .and change(wallet, :ongoing_balance_cents).from(800).to(600)
          .and change(wallet, :credits_ongoing_balance).from(8.0).to(6.0)
      end
    end

    context "when there is a progressive billing invoice" do
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:current_usage_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 1100, taxes_amount_cents: 0)
      end
      let(:progressive_billing_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 100, taxes_amount_cents: 10,
          precise_coupons_amount_cents: 0)
      end
      let(:current_usage_fees) { [current_usage_fee] }
      let(:progressive_billing_fees) { [progressive_billing_fee] }

      it "deducts progressively_billed amount from the ongoing usage" do
        # total_usage = 1100, billed_progressive = 110 (100 + 10 taxes)
        # ongoing_usage = 1100 - 110 = 990
        expect { subject }
          .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(990)
          .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(9.9)
          .and change(wallet, :ongoing_balance_cents).from(800).to(10)
          .and change(wallet, :credits_ongoing_balance).from(8.0).to(0.1)
      end
    end

    context "when there are draft invoices fees" do
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:current_usage_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 1000, taxes_amount_cents: 0)
      end
      let(:draft_invoice_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 100, taxes_amount_cents: 10,
          precise_coupons_amount_cents: 10)
      end
      let(:current_usage_fees) { [current_usage_fee] }
      let(:draft_invoices_fees) { [draft_invoice_fee] }

      it "adds draft invoices amount to the ongoing usage" do
        # total_usage = 1000, draft_invoices = 100 (amount) + 10 (taxes) - 10 (coupons) = 100
        # ongoing_usage = 1000 + 100 = 1100
        expect { subject }
          .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(1100)
          .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(11.0)
          .and change(wallet, :ongoing_balance_cents).from(800).to(-100)
          .and change(wallet, :credits_ongoing_balance).from(8.0).to(-1.0)
      end
    end

    context "when recalculated ongoing balance is less than 0" do
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:current_usage_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 1100, taxes_amount_cents: 0)
      end
      let(:current_usage_fees) { [current_usage_fee] }

      before do
        allow(Wallets::Balance::UpdateOngoingService).to receive(:call).and_call_original
      end

      context "when wallet is not depleted" do
        it "sends update params with depleted_ongoing_balance set to true" do
          subject

          expect(Wallets::Balance::UpdateOngoingService).to have_received(:call)
            .with(wallet: wallet, update_params: hash_including(depleted_ongoing_balance: true), skip_single_wallet_update: false)
        end
      end

      context "when wallet is depleted before the update" do
        let(:depleted_ongoing_balance) { true }

        it "doesn't send update params with depleted_ongoing_balance set to true" do
          subject

          expect(Wallets::Balance::UpdateOngoingService).to have_received(:call)
            .with(wallet: wallet, update_params: hash_excluding(:depleted_ongoing_balance), skip_single_wallet_update: false)
        end
      end
    end

    context "when ongoing balance becomes positive after being depleted" do
      let(:depleted_ongoing_balance) { true }
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:current_usage_fee) do
        create(:charge_fee, charge: first_charge, subscription: first_subscription,
          organization:, invoice:, amount_cents: 500, taxes_amount_cents: 0)
      end
      let(:current_usage_fees) { [current_usage_fee] }

      before do
        allow(Wallets::Balance::UpdateOngoingService).to receive(:call).and_call_original
      end

      it "sends update params with depleted_ongoing_balance set to false" do
        subject

        expect(Wallets::Balance::UpdateOngoingService).to have_received(:call)
          .with(wallet: wallet, update_params: hash_including(depleted_ongoing_balance: false), skip_single_wallet_update: false)
      end
    end
  end
end
