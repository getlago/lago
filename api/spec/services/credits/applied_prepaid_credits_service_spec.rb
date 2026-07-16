# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credits::AppliedPrepaidCreditsService do
  let(:invoice) do
    create(
      :invoice,
      customer:,
      currency: "EUR",
      total_amount_cents: amount_cents
    )
  end
  let(:fee) {
    create(:charge_fee, invoice:, subscription:,
      amount_cents: fee_amount_cents, precise_amount_cents: fee_amount_cents,
      taxes_precise_amount_cents: 0)
  }
  let(:amount_cents) { 100 }
  let(:fee_amount_cents) { 100 }

  let(:normal_wallet) do
    create(:wallet, :with_inbound_transaction, name: "normal", customer:, balance_cents: 1000, credits_balance: 10.0)
  end

  let(:priority_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49)
  end

  let(:limited_charge_wallet) do
    create(:wallet, :with_inbound_transaction, name: "limited charge", customer:, balance_cents: 1000, credits_balance: 10.0, allowed_fee_types: %w[charge])
  end

  let(:priority_limited_charge_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority limited charge", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49, allowed_fee_types: %w[charge])
  end

  let(:limited_subscription_wallet) do
    create(:wallet, :with_inbound_transaction, name: "limited subscription", customer:, balance_cents: 1000, credits_balance: 10.0, allowed_fee_types: %w[subscription])
  end

  let(:priority_limited_subscription_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority limited subscription", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49, allowed_fee_types: %w[subscription])
  end
  let(:wallets) do
    [
      normal_wallet,
      priority_wallet,
      limited_charge_wallet,
      priority_limited_charge_wallet,
      limited_subscription_wallet,
      priority_limited_subscription_wallet
    ]
  end
  let(:customer) { create(:customer) }
  let(:subscription) { create(:subscription, customer:) }

  before do
    wallets
    fee
    subscription
  end

  describe "#call" do
    subject(:result) { described_class.call(invoice:) }

    it "calculates prepaid credit" do
      expect(result).to be_success
      expect(result.prepaid_credit_amount_cents).to eq(100)
      expect(invoice.prepaid_credit_amount_cents).to eq(100)
    end

    context "when customer has no applicable wallets" do
      let(:wallets) { [] }

      it "returns early with empty values and no side effects" do
        expect(result).to be_success
        expect(result.prepaid_credit_amount_cents).to eq(0)
        expect(result.wallet_transactions).to eq([])
        expect(invoice.prepaid_credit_amount_cents).to eq(0)
      end
    end

    it "creates wallet transaction" do
      expect(result).to be_success
      expect(result.wallet_transactions.count).to eq(1)
      expect(result.wallet_transactions.first.wallet_id).to eq(priority_wallet.id)
      expect(result.wallet_transactions.first.amount).to eq(1.0)
      expect(result.wallet_transactions.first).to be_invoiced
      expect(result.prepaid_credit_amount_cents).to eq(100)
      expect(invoice.prepaid_credit_amount_cents).to eq(100)
    end

    it "updates wallet balance" do
      subject
      wallet = priority_wallet.reload

      expect(wallet.id).to eq(priority_wallet.id)
      expect(wallet.balance_cents).to eq(900)
      expect(wallet.credits_balance).to eq(9.0)

      [
        normal_wallet,
        limited_charge_wallet,
        priority_limited_charge_wallet,
        limited_subscription_wallet,
        priority_limited_subscription_wallet
      ].each do |w|
        expect(w.reload.balance_cents).to eq(1000)
      end
    end

    it "enqueues a SendWebhookJob" do
      expect { subject }.to have_enqueued_job_after_commit(SendWebhookJob)
        .with("wallet_transaction.created", WalletTransaction)
    end

    it "produces an activity log" do
      wallet_transaction = result.wallet_transactions.first

      expect(Utils::ActivityLog).to have_produced("wallet_transaction.created").after_commit.with(wallet_transaction)
    end

    context "when priority wallet credits are less than invoice amount" do
      let(:amount_cents) { 1500 }
      let(:fee_amount_cents) { 1500 }

      it "creates wallet transactions" do
        expect(result).to be_success
        expect(result.wallet_transactions.count).to eq(2)

        wallet_transaction_1 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_wallet.id }
        wallet_transaction_2 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_charge_wallet.id }

        expect(wallet_transaction_1.amount).to eq(10.0)
        expect(wallet_transaction_2.amount).to eq(5.0)
        expect(result.prepaid_credit_amount_cents).to eq(1500)
        expect(invoice.prepaid_credit_amount_cents).to eq(1500)
      end

      it "updates wallets balance" do
        subject
        wallet_priority = priority_wallet.reload
        wallet_priority_limited_charge = priority_limited_charge_wallet.reload

        expect(wallet_priority.balance).to eq(0.0)
        expect(wallet_priority.credits_balance).to eq(0.0)
        expect(wallet_priority_limited_charge.balance_cents).to eq(500)
        expect(wallet_priority_limited_charge.credits_balance).to eq(5.0)
        [normal_wallet,
          limited_charge_wallet,
          limited_subscription_wallet,
          priority_limited_subscription_wallet].each do |w|
          expect(w.reload.balance_cents).to eq(1000)
        end
      end
    end

    context "when already applied" do
      let(:wallet_transaction) { create(:wallet_transaction, wallet: wallets.first, invoice:, transaction_type: "outbound") }

      before { wallet_transaction }

      it "returns error" do
        expect(result).not_to be_success
        expect(result.error.code).to eq("already_applied")
        expect(result.error.error_message).to eq("Prepaid credits already applied")
      end
    end

    context "with fee type limitations" do
      let(:subscription_fees) { [fee, fee2] }
      let(:amount_cents) { 110 }
      let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 60, precise_amount_cents: 60, taxes_precise_amount_cents: 6) }
      let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, precise_amount_cents: 40, taxes_precise_amount_cents: 4) }

      before { subscription_fees }

      it "creates wallet transaction" do
        expect(result).to be_success
        expect(result.wallet_transactions.count).to eq(1)
        expect(result.wallet_transactions.first.wallet_id).to eq(priority_wallet.id)
        expect(result.wallet_transactions.first.amount).to eq(1.10)
        expect(result.prepaid_credit_amount_cents).to eq(110)
        expect(invoice.prepaid_credit_amount_cents).to eq(110)
      end

      it "updates wallet balance" do
        subject
        wallet = priority_wallet.reload

        expect(wallet.balance_cents).to eq(890)
        expect(wallet.credits_balance).to eq(8.90)
        [normal_wallet,
          limited_charge_wallet,
          priority_limited_charge_wallet,
          limited_subscription_wallet,
          priority_limited_subscription_wallet].each do |w|
          expect(w.reload.balance_cents).to eq(1000)
        end
      end

      context "when wallet credits are less than invoice amount" do
        let(:amount_cents) { 5150 }
        let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 3500, precise_amount_cents: 3500, taxes_precise_amount_cents: 100) }
        let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 1500, precise_amount_cents: 1500, taxes_precise_amount_cents: 50) }

        it "creates wallet transaction" do
          expect(result).to be_success
          expect(result.wallet_transactions.count).to eq(6)
          wallet_transaction_1 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_wallet.id }
          wallet_transaction_2 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_charge_wallet.id }
          wallet_transaction_3 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_subscription_wallet.id }
          wallet_transaction_4 = result.wallet_transactions.detect { |tx| tx.wallet_id == normal_wallet.id }
          wallet_transaction_5 = result.wallet_transactions.detect { |tx| tx.wallet_id == limited_charge_wallet.id }
          wallet_transaction_6 = result.wallet_transactions.detect { |tx| tx.wallet_id == limited_subscription_wallet.id }

          expect(wallet_transaction_1.amount).to eq(10.0)
          expect(wallet_transaction_2.amount).to eq(10.0)
          expect(wallet_transaction_3.amount).to eq(10.0)
          expect(wallet_transaction_4.amount).to eq(10.0)
          expect(wallet_transaction_5.amount).to eq(5.5)
          expect(wallet_transaction_6.amount).to eq(6.0)
          expect(result.prepaid_credit_amount_cents).to eq(5150)
          expect(invoice.prepaid_credit_amount_cents).to eq(5150)
        end

        it "updates wallet balance" do
          subject

          expect(normal_wallet.reload.balance_cents).to eq(0)
          expect(priority_wallet.reload.balance_cents).to eq(0)
          expect(limited_charge_wallet.reload.balance_cents).to eq(450)
          expect(priority_limited_charge_wallet.reload.balance_cents).to eq(0)
          expect(limited_subscription_wallet.reload.balance_cents).to eq(400)
          expect(priority_limited_subscription_wallet.reload.balance_cents).to eq(0)
        end
      end
    end

    context "with billable metric limitations" do
      let(:limited_bm_wallet) do
        create(:wallet, :with_inbound_transaction, name: "limited bm wallet", customer:, balance_cents: 1000, credits_balance: 10.0)
      end
      let(:priority_limited_bm_wallet) do
        create(:wallet, :with_inbound_transaction, name: "priority limited bm wallet", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49)
      end
      let(:wallets) do
        [
          normal_wallet,
          limited_subscription_wallet,
          priority_limited_subscription_wallet,
          limited_bm_wallet,
          priority_limited_bm_wallet,
          priority_limited_charge_wallet,
          priority_wallet,
          limited_charge_wallet
        ]
      end
      let(:subscription_fees) { [fee, fee2] }
      let(:amount_cents) { 110 }
      let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 60, precise_amount_cents: 60, taxes_precise_amount_cents: 6) }
      let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, precise_amount_cents: 40, taxes_precise_amount_cents: 4, charge:) }
      let(:charge) { create(:standard_charge, organization: wallets.first.organization, billable_metric:) }
      let(:billable_metric) { create(:billable_metric, organization: wallets.first.organization) }
      let(:wallet_targets) do
        create(:wallet_target, wallet: limited_bm_wallet, billable_metric:)
        create(:wallet_target, wallet: priority_limited_bm_wallet, billable_metric:)
      end

      before do
        subscription_fees
        wallet_targets
      end

      it "creates wallet transaction" do
        expect(result).to be_success
        expect(result.wallet_transactions.count).to eq(2)

        wallet_transaction_1 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_subscription_wallet.id }
        wallet_transaction_2 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_bm_wallet.id }

        expect(wallet_transaction_1.amount).to eq(0.66)
        expect(wallet_transaction_2.amount).to eq(0.44)
        expect(wallet_transaction_1).to be_invoiced
        expect(wallet_transaction_2).to be_invoiced
        expect(result.prepaid_credit_amount_cents).to eq(110)
        expect(invoice.prepaid_credit_amount_cents).to eq(110)
      end

      it "updates wallet balance" do
        subject
        wallet_priority_limited_subscription = priority_limited_subscription_wallet.reload
        wallet_priority_limited_bm = priority_limited_bm_wallet.reload
        expect(wallet_priority_limited_subscription.balance_cents).to eq(934)
        expect(wallet_priority_limited_subscription.credits_balance).to eq(9.34)
        expect(wallet_priority_limited_bm.balance_cents).to eq(956)
        expect(wallet_priority_limited_bm.credits_balance).to eq(9.56)

        [
          normal_wallet,
          limited_bm_wallet,
          priority_limited_charge_wallet,
          priority_wallet,
          limited_charge_wallet
        ].each do |w|
          expect(w.reload.balance_cents).to eq(1000)
        end
      end

      context "when precise fees have decimals" do
        let(:amount_cents) { 114.4 }
        let(:subscription_fees) { [fee2] }

        let(:fee2) do
          create(
            :charge_fee,
            invoice:,
            subscription:,
            amount_cents: 44,
            precise_amount_cents: 44,
            taxes_precise_amount_cents: 4.4,
            charge:
          )
        end

        it "rounds the decimals" do
          expect(result).to be_success
          expect(result.prepaid_credit_amount_cents).to eq(114)
        end
      end

      context "when wallet credits are less than invoice amount" do
        let(:subscription_fees) { [fee, fee2] }
        let(:amount_cents) { 10_000 }
        let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 2_000, precise_amount_cents: 2_000, taxes_precise_amount_cents: 200) }
        let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 1_000, precise_amount_cents: 1_000, taxes_precise_amount_cents: 100, charge:) }

        it "creates wallet transaction" do
          expect(result).to be_success
          expect(result.wallet_transactions.count).to eq(5)

          wallet_transaction_1 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_subscription_wallet.id }
          wallet_transaction_2 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_bm_wallet.id }
          wallet_transaction_3 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_limited_charge_wallet.id }
          wallet_transaction_4 = result.wallet_transactions.detect { |tx| tx.wallet_id == priority_wallet.id }
          wallet_transaction_5 = result.wallet_transactions.detect { |tx| tx.wallet_id == normal_wallet.id }

          expect(wallet_transaction_1.amount).to eq(10)
          expect(wallet_transaction_2.amount).to eq(10)
          expect(wallet_transaction_3.amount).to eq(1)
          expect(wallet_transaction_4.amount).to eq(10)
          expect(wallet_transaction_5.amount).to eq(2)
          expect(result.prepaid_credit_amount_cents).to eq(3300)
          expect(invoice.prepaid_credit_amount_cents).to eq(3300)
        end

        it "updates wallet balance" do
          subject

          expect(normal_wallet.reload.balance_cents).to eq(800)
          expect(priority_wallet.reload.balance_cents).to eq(0)
          expect(limited_charge_wallet.reload.balance_cents).to eq(1000)
          expect(priority_limited_charge_wallet.reload.balance_cents).to eq(900)
          expect(limited_subscription_wallet.reload.balance_cents).to eq(1000)
          expect(priority_limited_subscription_wallet.reload.balance_cents).to eq(0)
          expect(limited_bm_wallet.reload.balance_cents).to eq(1000)
          expect(priority_limited_bm_wallet.reload.balance_cents).to eq(0)
        end
      end
    end

    context "when wallet is limited to a fee processed last" do
      let(:fee) { nil }
      let(:amount_cents) { 680 }

      let(:wallet_limited_billable_metric) { create(:billable_metric, organization: customer.organization) }
      let(:wallet) do
        create(:wallet, :with_inbound_transaction, customer:, balance_cents: 6600, credits_balance: 66.0)
      end
      let(:wallet_target) { create(:wallet_target, wallet: wallet, billable_metric: wallet_limited_billable_metric) }
      let(:wallets) { [wallet] }

      before do
        uuid = SecureRandom.uuid
        10.times do |i|
          billable_metric = (i == 9) ? wallet_limited_billable_metric : create(:billable_metric, organization: customer.organization)
          charge = create(:standard_charge, organization: customer.organization, billable_metric: billable_metric)
          create(
            :charge_fee,
            id: "#{uuid[..-2]}#{i}", # enforce database order to avoid flaky tests
            invoice:,
            subscription:,
            charge: charge,
            amount_cents: 60, precise_amount_cents: 60.4, taxes_precise_amount_cents: 8.456, taxes_amount_cents: 8
          )
        end
        wallet_target
      end

      it "applies credits based on fee cap, not fee processing order" do
        expect(result).to be_success
        expect(result.prepaid_credit_amount_cents).to eq(68)
        expect(invoice.prepaid_credit_amount_cents).to eq(68)
      end
    end

    context "when wallet is traceable" do
      let(:wallets) { [traceable_wallet] }
      let(:traceable_wallet) do
        create(:wallet, name: "traceable", customer:, balance_cents: 1000, credits_balance: 10.0, traceable: true)
      end
      let!(:inbound_transaction) do
        create(:wallet_transaction,
          wallet: traceable_wallet,
          organization: traceable_wallet.organization,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 10,
          credit_amount: 10,
          remaining_amount_cents: 1000)
      end

      it "tracks consumption from inbound transactions" do
        expect { result }.to change(WalletTransactionConsumption, :count).by(1)
      end

      it "creates consumption record linking inbound and outbound" do
        result

        consumption = WalletTransactionConsumption.last
        expect(consumption.inbound_wallet_transaction).to eq(inbound_transaction)
        expect(consumption.outbound_wallet_transaction).to eq(result.wallet_transactions.first)
        expect(consumption.consumed_amount_cents).to eq(100)
      end

      it "decrements remaining_amount_cents on inbound transaction" do
        result

        expect(inbound_transaction.reload.remaining_amount_cents).to eq(900)
      end

      it "sets prepaid_granted_credit_amount_cents on invoice" do
        result

        expect(invoice.prepaid_granted_credit_amount_cents).to eq(100)
        expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
      end

      context "when inbound transaction is purchased" do
        let(:inbound_transaction) do
          create(:wallet_transaction,
            wallet: traceable_wallet,
            organization: traceable_wallet.organization,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 10,
            credit_amount: 10,
            remaining_amount_cents: 1000)
        end

        before { inbound_transaction }

        it "sets prepaid_purchased_credit_amount_cents on invoice" do
          result

          expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
          expect(invoice.prepaid_purchased_credit_amount_cents).to eq(100)
        end
      end

      context "when consuming from both granted and purchased transactions" do
        let(:amount_cents) { 500 }
        let(:fee_amount_cents) { 500 }

        let!(:inbound_transaction) do
          create(:wallet_transaction,
            wallet: traceable_wallet,
            organization: traceable_wallet.organization,
            transaction_type: :inbound,
            transaction_status: :granted,
            status: :settled,
            amount: 3,
            credit_amount: 3,
            remaining_amount_cents: 300)
        end

        let(:purchased_transaction) do
          create(:wallet_transaction,
            wallet: traceable_wallet,
            organization: traceable_wallet.organization,
            transaction_type: :inbound,
            transaction_status: :purchased,
            status: :settled,
            amount: 7,
            credit_amount: 7,
            remaining_amount_cents: 700)
        end

        before do
          inbound_transaction
          purchased_transaction
        end

        it "sets both breakdown amounts on invoice" do
          result

          expect(invoice.prepaid_granted_credit_amount_cents).to eq(300)
          expect(invoice.prepaid_purchased_credit_amount_cents).to eq(200)
        end
      end
    end

    context "when wallet is not traceable" do
      let(:wallets) { [non_traceable_wallet] }
      let(:non_traceable_wallet) do
        create(:wallet, name: "non-traceable", customer:, balance_cents: 1000, credits_balance: 10.0, traceable: false)
      end

      it "does not create consumption records" do
        expect { result }.not_to change(WalletTransactionConsumption, :count)
      end

      it "does not set breakdown amounts on invoice" do
        result

        expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
        expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
      end
    end

    context "when customer has both traceable and non-traceable wallets" do
      let(:wallets) { [traceable_wallet, non_traceable_wallet] }
      let(:traceable_wallet) do
        create(:wallet, name: "traceable", customer:, balance_cents: 500, credits_balance: 5.0, traceable: true)
      end
      let(:non_traceable_wallet) do
        create(:wallet, name: "non-traceable", customer:, balance_cents: 500, credits_balance: 5.0, traceable: false)
      end
      let(:inbound_transaction) do
        create(:wallet_transaction,
          wallet: traceable_wallet,
          organization: traceable_wallet.organization,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 5,
          credit_amount: 5,
          remaining_amount_cents: 500)
      end

      before { inbound_transaction }

      it "does not set breakdown amounts on invoice" do
        result

        expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
        expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil
      end
    end

    context "when customer has multiple traceable wallets" do
      let(:amount_cents) { 500 }
      let(:fee_amount_cents) { 500 }
      let(:wallets) { [traceable_wallet1, traceable_wallet2] }
      let(:traceable_wallet1) do
        create(:wallet, name: "traceable1", customer:, balance_cents: 300, credits_balance: 3.0, traceable: true, priority: 1)
      end
      let(:traceable_wallet2) do
        create(:wallet, name: "traceable2", customer:, balance_cents: 400, credits_balance: 4.0, traceable: true, priority: 2)
      end
      let(:inbound_transaction1) do
        create(:wallet_transaction,
          wallet: traceable_wallet1,
          organization: traceable_wallet1.organization,
          transaction_type: :inbound,
          transaction_status: :granted,
          status: :settled,
          amount: 3,
          credit_amount: 3,
          remaining_amount_cents: 300)
      end
      let(:inbound_transaction2) do
        create(:wallet_transaction,
          wallet: traceable_wallet2,
          organization: traceable_wallet2.organization,
          transaction_type: :inbound,
          transaction_status: :purchased,
          status: :settled,
          amount: 4,
          credit_amount: 4,
          remaining_amount_cents: 400)
      end

      before do
        inbound_transaction1
        inbound_transaction2
      end

      it "creates consumption records for both wallets" do
        expect { result }.to change(WalletTransactionConsumption, :count).by(2)
      end

      it "sums breakdown amounts from both wallets" do
        result

        expect(invoice.prepaid_granted_credit_amount_cents).to eq(300)
        expect(invoice.prepaid_purchased_credit_amount_cents).to eq(200)
      end

      it "decrements remaining_amount_cents on both inbound transactions" do
        result

        expect(inbound_transaction1.reload.remaining_amount_cents).to eq(0)
        expect(inbound_transaction2.reload.remaining_amount_cents).to eq(200)
      end
    end

    context "when precise tax rounding causes fee caps to be slightly below invoice total" do
      let(:normal_wallet) do
        create(:wallet, :with_inbound_transaction, name: "normal", customer:, balance_cents: 200_000, credits_balance: 2000.0)
      end
      let(:wallets) { [normal_wallet] }
      let(:amount_cents) { 106_826 }
      let(:fee) { nil }

      before do
        create(:charge_fee, invoice:, subscription:,
          amount_cents: 50_000, precise_amount_cents: 50_000,
          taxes_amount_cents: 3413, taxes_precise_amount_cents: BigDecimal("3412.7"))
        create(:charge_fee, invoice:, subscription:,
          amount_cents: 50_000, precise_amount_cents: 50_000,
          taxes_amount_cents: 3413, taxes_precise_amount_cents: BigDecimal("3412.7"))
      end

      it "applies the full invoice amount without rounding gap" do
        expect(result).to be_success
        expect(result.prepaid_credit_amount_cents).to eq(106_826)
        expect(invoice.prepaid_credit_amount_cents).to eq(106_826)
      end
    end

    context "when wallet currency does not match invoice currency" do
      let(:wallets) { [eur_wallet, usd_wallet] }
      let(:eur_wallet) do
        create(:wallet, :with_inbound_transaction, name: "eur wallet", customer:, balance_cents: 1000, currency: "EUR")
      end
      let(:usd_wallet) do
        create(:wallet, :with_inbound_transaction, name: "usd wallet", customer:, balance_cents: 1000, currency: "USD")
      end

      it "only applies credits from wallets matching the invoice currency" do
        expect(result).to be_success
        expect(result.wallet_transactions.count).to eq(1)
        expect(result.wallet_transactions.first.wallet_id).to eq(eur_wallet.id)
        expect(result.prepaid_credit_amount_cents).to eq(100)
      end
    end

    context "when no wallets match the invoice currency" do
      let(:wallets) do
        [create(:wallet, name: "usd wallet", customer:, balance_cents: 1000, currency: "USD")]
      end

      it "returns early with no credits applied" do
        expect(result).to be_success
        expect(result.prepaid_credit_amount_cents).to eq(0)
        expect(result.wallet_transactions).to eq([])
      end
    end

    # QA scenario #1: USD wallet under entity US consumed by USD invoice under
    # entity EU. Decision 5.5: credits are filtered by currency only — there is
    # no entity gate — so the cross-entity wallet still applies its credits.
    context "when wallet and invoice belong to different billing entities" do
      let(:us_entity) { create(:billing_entity, organization: customer.organization, code: "us") }
      let(:eu_entity) { create(:billing_entity, organization: customer.organization, code: "eu") }

      let(:wallets) { [usd_wallet_under_us] }
      let(:usd_wallet_under_us) do
        create(:wallet, :with_inbound_transaction,
          name: "usd wallet under US",
          customer:,
          billing_entity: us_entity,
          currency: "USD",
          balance_cents: 1000,
          credits_balance: 10.0)
      end

      let(:invoice) do
        create(:invoice,
          customer:,
          billing_entity: eu_entity,
          currency: "USD",
          total_amount_cents: amount_cents)
      end

      it "applies credits regardless of the billing entity mismatch" do
        expect(result).to be_success
        expect(result.wallet_transactions.count).to eq(1)
        expect(result.wallet_transactions.first.wallet_id).to eq(usd_wallet_under_us.id)
        expect(result.prepaid_credit_amount_cents).to eq(100)
        expect(invoice.prepaid_credit_amount_cents).to eq(100)
      end

      it "decrements the wallet balance even though entities differ" do
        subject
        expect(usd_wallet_under_us.reload.balance_cents).to eq(900)
      end
    end

    # QA scenario #2: EUR wallet under entity US, USD invoice under entity US.
    # Same entity, different currency. The currency check filters the wallet
    # out before the entity comparison would even matter, confirming that
    # currency is the only gate and entity is not consulted.
    context "when wallet currency differs from invoice currency (same entity)" do
      let(:us_entity) { create(:billing_entity, organization: customer.organization, code: "us") }

      let(:wallets) { [eur_wallet_under_us] }
      let(:eur_wallet_under_us) do
        create(:wallet, :with_inbound_transaction,
          name: "eur wallet under US",
          customer:,
          billing_entity: us_entity,
          currency: "EUR",
          balance_cents: 1000,
          credits_balance: 10.0)
      end

      let(:invoice) do
        create(:invoice,
          customer:,
          billing_entity: us_entity,
          currency: "USD",
          total_amount_cents: amount_cents)
      end

      it "skips the wallet and applies no credits" do
        expect(result).to be_success
        expect(result.wallet_transactions).to be_empty
        expect(result.prepaid_credit_amount_cents).to eq(0)
        expect(invoice.prepaid_credit_amount_cents).to eq(0)
      end

      it "leaves the wallet balance untouched" do
        subject
        expect(eur_wallet_under_us.reload.balance_cents).to eq(1000)
      end
    end

    context "when there is a concurrent lock" do
      before do
        stub_const("Customers::LockService::ACQUIRE_LOCK_TIMEOUT", 1.second)
      end

      around do |test|
        with_advisory_lock("customer-#{customer.id}-prepaid_credit", lock_released_after:) do
          test.run
        end
      end

      context "when it fails to acquire the lock" do
        let(:lock_released_after) { 2.seconds }

        it "raises a Customers::FailedToAcquireLock error" do
          expect { subject }.to raise_error(Customers::FailedToAcquireLock)
        end
      end

      context "when the lock is acquired" do
        let(:lock_released_after) { 0.6.seconds }

        it "creates the invoice" do
          expect { subject }.not_to raise_error
        end
      end
    end
  end
end
