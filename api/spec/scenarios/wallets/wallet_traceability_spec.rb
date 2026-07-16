# frozen_string_literal: true

require "rails_helper"

describe "Wallet Traceability Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 0) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 0, pay_in_advance: false) }
  let(:billable_metric) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
  let(:charge) { create(:charge, plan:, billable_metric:, charge_model: "standard", properties: {"amount" => "1"}) }

  before { charge }

  def create_traceable_wallet(rate_amount: "1")
    params = {
      external_customer_id: customer.external_id,
      rate_amount:,
      name: "Traceable Wallet",
      currency: "EUR",
      granted_credits: "0",
      invoice_requires_successful_payment: false
    }

    wallet = create_wallet(params, as: :model)
    wallet.update!(traceable: true)
    wallet
  end

  def create_non_traceable_wallet(rate_amount: "1")
    params = {
      external_customer_id: customer.external_id,
      rate_amount:,
      name: "Non-Traceable Wallet",
      currency: "EUR",
      granted_credits: "0",
      invoice_requires_successful_payment: false
    }

    wallet = create_wallet(params, as: :model)
    wallet.update!(traceable: false)
    wallet
  end

  def top_up_wallet(wallet, granted_credits: nil, paid_credits: nil)
    params = {wallet_id: wallet.id}
    params[:granted_credits] = granted_credits if granted_credits
    params[:paid_credits] = paid_credits if paid_credits

    create_wallet_transaction(params, as: :model)
  end

  def void_credits(wallet, amount)
    transactions = create_wallet_transaction({
      wallet_id: wallet.id,
      voided_credits: amount.to_s
    }, as: :model)
    transactions.find { |t| t.transaction_status == "voided" }
  end

  def get_fundings(wallet_transaction)
    get_with_token(organization, "/api/v1/wallet_transactions/#{wallet_transaction.id}/fundings")
    json[:wallet_transaction_fundings]
  end

  def get_consumptions(wallet_transaction)
    get_with_token(organization, "/api/v1/wallet_transactions/#{wallet_transaction.id}/consumptions")
    json[:wallet_transaction_consumptions]
  end

  def setup_subscription
    create_subscription({
      external_customer_id: customer.external_id,
      external_id: customer.external_id,
      plan_code: plan.code
    })
    customer.subscriptions.first
  end

  def ingest_usage(subscription, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric.field_name => amount}
    })
    perform_usage_update
  end

  describe "Invoice Consumption Scenarios" do
    describe "Example 1: Simple Consumption (Single Source)" do
      # Customer tops up $100, then invoice consumes $40:
      #
      # INBOUND                                   OUTBOUND
      # ┌─────────────────────────┐              ┌─────────────────────────┐
      # │ TX1 (granted)           │              │ TX2 (invoiced)          │
      # │ amount: $100            │────$40─────▶ │ amount: $40             │
      # │ remaining: $60          │              │                         │
      # └─────────────────────────┘              └─────────────────────────┘
      #
      # Join table:
      # │ TX1 │ TX2 │ $40 │

      it "creates a single consumption record linking inbound to outbound" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          tx1 = wallet.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 40)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.first
          expect(invoice.total_amount_cents).to eq(0)
        end

        tx2 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        expect(tx2).to be_present
        expect(tx2.amount).to eq(40)

        fundings = get_fundings(tx2)
        expect(fundings.count).to eq(1)
        expect(fundings.first[:wallet_transaction][:lago_id]).to eq(tx1.id)
        expect(fundings.first[:amount_cents]).to eq(4000)

        expect(tx1.reload.remaining_amount_cents).to eq(6000)
      end
    end

    describe "Example 2: Consumption Spanning Multiple Inbounds" do
      # Customer has two top-ups ($30 granted, $50 granted), then invoice consumes $60:
      #
      # INBOUND                                 OUTBOUND
      # ┌─────────────────────────┐
      # │ TX1 (granted)           │             ┌─────────────────────────┐
      # │ amount: $30             │────$30─────▶│ TX3 (invoiced)          │
      # │ remaining: $0           │         ┌──▶│ amount: $60             │
      # └─────────────────────────┘         │   └─────────────────────────┘
      # ┌─────────────────────────┐         │
      # │ TX2 (granted)           │         │
      # │ amount: $50             │───$30───┘
      # │ remaining: $20          │
      # └─────────────────────────┘
      #
      # Join table:
      # │ TX1 │ TX3 │ $30 │  (first inbound consumed first - FIFO)
      # │ TX2 │ TX3 │ $30 │  (then second inbound)

      it "creates consumption records from both inbounds following FIFO order" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet
          top_up_wallet(wallet, granted_credits: "30")
          tx1 = wallet.wallet_transactions.inbound.first
        end

        travel_to(time_0 + 1.hour) do
          top_up_wallet(wallet, granted_credits: "50")
          tx2 = wallet.wallet_transactions.inbound.order(created_at: :desc).first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 60)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx3 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first

        fundings = get_fundings(tx3)
        expect(fundings.count).to eq(2)

        tx1_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx1.id }
        tx2_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx2.id }

        expect(tx1_funding[:amount_cents]).to eq(3000)
        expect(tx2_funding[:amount_cents]).to eq(3000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)
      end
    end

    describe "Example 3: Multiple Outbounds from Same Inbound" do
      # Customer tops up $100, then has two invoices ($25 and $35):
      #
      # INBOUND                              OUTBOUND
      # ┌─────────────────────────┐              ┌─────────────────────────┐
      # │ TX1 (granted)           │────$25──────▶│ TX2 (invoiced)          │
      # │ amount: $100            │              │ amount: $25             │
      # │ remaining: $40          │              └─────────────────────────┘
      # │                         │              ┌─────────────────────────┐
      # │                         │────$35──────▶│ TX3 (invoiced)          │
      # │                         │              │ amount: $35             │
      # └─────────────────────────┘              └─────────────────────────┘
      #
      # Join table:
      # │ TX1 │ TX2 │ $25 │
      # │ TX1 │ TX3 │ $35 │

      it "creates separate consumption records for each invoice from the same inbound" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")
          tx1 = wallet.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        # First billing period - $25 usage
        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx2 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first

        # Second billing period - $35 usage
        travel_to(time_0 + 1.month + 5.days) do
          ingest_usage(subscription, 35)
        end

        travel_to(time_0 + 2.months) do
          perform_billing
        end

        tx3 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).order(created_at: :desc).first

        fundings_tx2 = get_fundings(tx2)
        expect(fundings_tx2.count).to eq(1)
        expect(fundings_tx2.first[:wallet_transaction][:lago_id]).to eq(tx1.id)
        expect(fundings_tx2.first[:amount_cents]).to eq(2500)

        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.count).to eq(1)
        expect(fundings_tx3.first[:wallet_transaction][:lago_id]).to eq(tx1.id)
        expect(fundings_tx3.first[:amount_cents]).to eq(3500)

        consumptions = get_consumptions(tx1)
        expect(consumptions.count).to eq(2)

        expect(tx1.reload.remaining_amount_cents).to eq(4000)
      end
    end

    describe "Example 4: Complex Scenario with Priority" do
      # Customer has: $20 granted (priority 1), $25 granted (priority 2 older),
      # $25 granted (priority 2 newer), $30 granted (priority 2 newest).
      # Then invoice consumes $80:
      #
      # Consumption order: TX1 (prio 1) → TX2 (prio 2, oldest) → TX3 (prio 2, newer) → TX4 (prio 2, newest)
      #
      # Join table:
      # │ TX1 │ TX5 │ $20 │  (granted, priority 1)
      # │ TX2 │ TX5 │ $25 │  (granted, priority 2, oldest)
      # │ TX3 │ TX5 │ $25 │  (granted, priority 2, newer)
      # │ TX4 │ TX5 │ $10 │  (granted, priority 2, newest)

      it "consumes in order: priority first, then FIFO" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        tx3 = nil
        tx4 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet

          # TX1: priority 1, high priority (consumed first)
          transactions1 = top_up_wallet(wallet, granted_credits: "20")
          tx1 = transactions1.find(&:inbound?)
          tx1.update!(priority: 1)

          # TX2: priority 2, created "3 days ago" (oldest of prio 2)
          transactions2 = top_up_wallet(wallet, granted_credits: "25")
          tx2 = transactions2.find(&:inbound?)
          tx2.update!(priority: 2, created_at: 3.days.ago)

          # TX3: priority 2, created "1 day ago" (newer than TX2)
          transactions3 = top_up_wallet(wallet, granted_credits: "25")
          tx3 = transactions3.find(&:inbound?)
          tx3.update!(priority: 2, created_at: 1.day.ago)

          # TX4: priority 2, created now (newest of prio 2)
          transactions4 = top_up_wallet(wallet, granted_credits: "30")
          tx4 = transactions4.find(&:inbound?)
          tx4.update!(priority: 2)

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 80)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx5 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first

        fundings = get_fundings(tx5)
        expect(fundings.count).to eq(4)

        tx1_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx1.id }
        tx2_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx2.id }
        tx3_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx3.id }
        tx4_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx4.id }

        expect(tx1_funding[:amount_cents]).to eq(2000)
        expect(tx2_funding[:amount_cents]).to eq(2500)
        expect(tx3_funding[:amount_cents]).to eq(2500)
        expect(tx4_funding[:amount_cents]).to eq(1000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(0)
        expect(tx3.reload.remaining_amount_cents).to eq(0)
        expect(tx4.reload.remaining_amount_cents).to eq(2000)
      end
    end

    describe "Invoice Prepaid Credit Breakdown" do
      # When invoice consumes from both granted and purchased transactions,
      # the invoice should track the breakdown separately:
      # - prepaid_granted_credit_amount_cents: amount from granted transactions
      # - prepaid_purchased_credit_amount_cents: amount from purchased transactions
      #
      # INBOUND                                 OUTBOUND
      # ┌─────────────────────────┐
      # │ TX1 (granted)           │             ┌─────────────────────────┐
      # │ amount: $30             │────$30─────▶│ TX3 (invoiced)          │
      # │ remaining: $0           │         ┌──▶│ amount: $80             │
      # └─────────────────────────┘         │   └─────────────────────────┘
      # ┌─────────────────────────┐         │
      # │ TX2 (purchased)         │         │
      # │ amount: $70             │───$50───┘
      # │ remaining: $20          │
      # └─────────────────────────┘
      #
      # Invoice breakdown:
      # - prepaid_granted_credit_amount_cents: 3000
      # - prepaid_purchased_credit_amount_cents: 5000

      it "tracks granted and purchased amounts separately on invoice" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        tx2 = nil
        subscription = nil
        invoice = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet
          top_up_wallet(wallet, granted_credits: "30")
          tx1 = wallet.wallet_transactions.inbound.where(transaction_status: :granted).first
        end

        travel_to(time_0 + 1.hour) do
          top_up_wallet(wallet, paid_credits: "70")
          tx2 = wallet.wallet_transactions.inbound.where(transaction_status: :purchased).first

          # Mark the credit invoice as paid so the purchased transaction becomes settled
          credit_invoice = customer.invoices.credit.sole
          update_invoice(credit_invoice, {payment_status: "succeeded"})
          perform_all_enqueued_jobs

          tx2.reload
          expect(tx2.status).to eq("settled")

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 80)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.subscription.first
        end

        expect(invoice.prepaid_granted_credit_amount_cents).to eq(3000)
        expect(invoice.prepaid_purchased_credit_amount_cents).to eq(5000)

        tx3 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        fundings = get_fundings(tx3)
        expect(fundings.count).to eq(2)

        tx1_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx1.id }
        tx2_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx2.id }

        expect(tx1_funding[:amount_cents]).to eq(3000)
        expect(tx2_funding[:amount_cents]).to eq(5000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)
      end
    end
  end

  describe "Voiding Credit Scenarios" do
    describe "Simple voiding" do
      # Customer tops up $100, then voids $40:
      #
      # INBOUND                                   OUTBOUND
      # ┌─────────────────────────┐              ┌─────────────────────────┐
      # │ TX1 (granted)           │              │ TX2 (voided)            │
      # │ amount: $100            │────$40─────▶ │ amount: $40             │
      # │ remaining: $60          │              │                         │
      # └─────────────────────────┘              └─────────────────────────┘
      #
      # Join table:
      # │ TX1 │ TX2 │ $40 │

      it "creates consumption record when voiding credits" do
        wallet = create_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        tx1 = wallet.wallet_transactions.inbound.first

        tx2 = void_credits(wallet, 40)

        fundings = get_fundings(tx2)
        expect(fundings.count).to eq(1)
        expect(fundings.first[:wallet_transaction][:lago_id]).to eq(tx1.id)
        expect(fundings.first[:amount_cents]).to eq(4000)

        expect(tx1.reload.remaining_amount_cents).to eq(6000)
      end
    end

    describe "Voiding spanning multiple inbounds" do
      # Customer has two top-ups ($30, $50), then voids $60:
      #
      # INBOUND                                 OUTBOUND
      # ┌─────────────────────────┐
      # │ TX1 (granted)           │             ┌─────────────────────────┐
      # │ amount: $30             │────$30─────▶│ TX3 (voided)            │
      # │ remaining: $0           │         ┌──▶│ amount: $60             │
      # └─────────────────────────┘         │   └─────────────────────────┘
      # ┌─────────────────────────┐         │
      # │ TX2 (granted)           │         │
      # │ amount: $50             │───$30───┘
      # │ remaining: $20          │
      # └─────────────────────────┘

      it "creates consumption records from multiple inbounds when voiding" do
        wallet = create_traceable_wallet
        top_up_wallet(wallet, granted_credits: "30")
        tx1 = wallet.wallet_transactions.inbound.first

        top_up_wallet(wallet, granted_credits: "50")
        tx2 = wallet.wallet_transactions.inbound.order(created_at: :desc).first

        tx3 = void_credits(wallet, 60)

        fundings = get_fundings(tx3)
        expect(fundings.count).to eq(2)

        tx1_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx1.id }
        tx2_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx2.id }

        expect(tx1_funding[:amount_cents]).to eq(3000)
        expect(tx2_funding[:amount_cents]).to eq(3000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)
      end
    end

    describe "Multiple voids from same inbound" do
      # Customer tops up $100, then voids $25 and $35:
      #
      # INBOUND                              OUTBOUND
      # ┌─────────────────────────┐              ┌─────────────────────────┐
      # │ TX1 (granted)           │────$25──────▶│ TX2 (voided)            │
      # │ amount: $100            │              │ amount: $25             │
      # │ remaining: $40          │              └─────────────────────────┘
      # │                         │              ┌─────────────────────────┐
      # │                         │────$35──────▶│ TX3 (voided)            │
      # │                         │              │ amount: $35             │
      # └─────────────────────────┘              └─────────────────────────┘

      it "creates separate consumption records for each void" do
        wallet = create_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")
        tx1 = wallet.wallet_transactions.inbound.first

        tx2 = void_credits(wallet, 25)
        tx3 = void_credits(wallet, 35)

        fundings_tx2 = get_fundings(tx2)
        expect(fundings_tx2.count).to eq(1)
        expect(fundings_tx2.first[:amount_cents]).to eq(2500)

        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.count).to eq(1)
        expect(fundings_tx3.first[:amount_cents]).to eq(3500)

        consumptions = get_consumptions(tx1)
        expect(consumptions.count).to eq(2)

        expect(tx1.reload.remaining_amount_cents).to eq(4000)
      end
    end

    describe "Voiding with priority ordering" do
      # Customer has multiple inbounds with different priorities, then voids credits:
      # TX1 (priority 1), TX2 (priority 2), TX3 (priority 2)
      # Void $50 - should consume TX1 first (priority 1), then TX2/TX3 in FIFO order

      it "respects priority ordering when voiding" do
        wallet = create_traceable_wallet

        transactions1 = top_up_wallet(wallet, granted_credits: "20")
        tx1 = transactions1.find(&:inbound?)
        tx1.update!(priority: 1)

        transactions2 = top_up_wallet(wallet, granted_credits: "25")
        tx2 = transactions2.find(&:inbound?)
        tx2.update!(priority: 2, created_at: 2.days.ago)

        transactions3 = top_up_wallet(wallet, granted_credits: "25")
        tx3 = transactions3.find(&:inbound?)
        tx3.update!(priority: 2, created_at: 1.day.ago)

        void_tx = void_credits(wallet, 50)

        fundings = get_fundings(void_tx)
        expect(fundings.count).to eq(3)

        tx1_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx1.id }
        tx2_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx2.id }
        tx3_funding = fundings.find { |f| f[:wallet_transaction][:lago_id] == tx3.id }

        expect(tx1_funding[:amount_cents]).to eq(2000)
        expect(tx2_funding[:amount_cents]).to eq(2500)
        expect(tx3_funding[:amount_cents]).to eq(500)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(0)
        expect(tx3.reload.remaining_amount_cents).to eq(2000)
      end
    end
  end

  describe "Edge cases" do
    describe "exact balance consumption" do
      it "fully consumes inbound when invoice amount matches exactly" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        tx1 = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_traceable_wallet
          top_up_wallet(wallet, granted_credits: "50")
          tx1 = wallet.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 50)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        tx2 = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first

        fundings = get_fundings(tx2)
        expect(fundings.count).to eq(1)
        expect(fundings.first[:amount_cents]).to eq(5000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
      end
    end

    describe "insufficient balance for voiding" do
      it "fails when trying to void more than available balance" do
        wallet = create_traceable_wallet
        top_up_wallet(wallet, granted_credits: "30")

        expect {
          create_wallet_transaction({
            wallet_id: wallet.id,
            voided_credits: "50"
          }, raise_on_error: false)
        }.not_to change(WalletTransactionConsumption, :count)

        expect(json[:status]).to eq(422)
        expect(json[:error]).to eq("Unprocessable Entity")
        expect(json[:code]).to eq("validation_errors")
      end
    end

    describe "non-integer wallet rate" do
      # With rate_amount: "0.5", 100 credits = 50 EUR (5000 cents)

      it "tracks consumption based on amount_cents using wallet rate" do
        wallet = create_traceable_wallet(rate_amount: "0.5")
        top_up_wallet(wallet, granted_credits: "100")
        tx1 = wallet.wallet_transactions.inbound.first

        # With rate 0.5, 100 credits = 50 EUR (5000 cents)
        expect(tx1.remaining_amount_cents).to eq(5000)

        # Void 60 credits = 30 EUR (3000 cents)
        tx2 = void_credits(wallet, 60)
        # Void 40 credits = 20 EUR (2000 cents)
        tx3 = void_credits(wallet, 40)

        fundings_tx2 = get_fundings(tx2)
        expect(fundings_tx2.first[:amount_cents]).to eq(3000)

        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.first[:amount_cents]).to eq(2000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
      end
    end
  end

  describe "Multiple Wallets Scenarios" do
    let(:billable_metric2) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
    let(:charge2) { create(:charge, plan:, billable_metric: billable_metric2, charge_model: "standard", properties: {"amount" => "1"}) }

    before { charge2 }

    def create_wallet_with_applies_to(applies_to:, granted_credits: "0", traceable: true)
      params = {
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet",
        currency: "EUR",
        invoice_requires_successful_payment: false,
        applies_to:
      }
      if traceable
        params[:granted_credits] = granted_credits
      end

      wallet = create_wallet(params, as: :model)
      if !traceable
        wallet.update!(traceable: false)
        create_wallet_transaction({
          wallet_id: wallet.id,
          granted_credits: granted_credits
        })
      end
      wallet
    end

    describe "Invoice consumption spanning multiple wallets" do
      # Customer has two wallets:
      # - Wallet 1: $30 (applies to billable_metric)
      # - Wallet 2: $50 (applies to billable_metric2)
      # Invoice consumes $25 from each metric:
      #
      # WALLET 1                                 OUTBOUND
      # ┌─────────────────────────┐
      # │ TX1 (granted)           │             ┌─────────────────────────┐
      # │ amount: $30             │────$25─────▶│ TX3 (invoiced)          │
      # │ remaining: $5           │             │ amount: $25             │
      # └─────────────────────────┘             └─────────────────────────┘
      #
      # WALLET 2                                 OUTBOUND
      # ┌─────────────────────────┐
      # │ TX2 (granted)           │             ┌─────────────────────────┐
      # │ amount: $50             │────$25─────▶│ TX4 (invoiced)          │
      # │ remaining: $25          │             │ amount: $25             │
      # └─────────────────────────┘             └─────────────────────────┘
      #
      # Invoice breakdown:
      # - prepaid_granted_credit_amount_cents: 5000 (from both wallets)

      it "creates consumption records for each wallet and sums prepaid breakdown" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        tx1 = nil
        tx2 = nil
        subscription = nil
        invoice = nil

        travel_to(time_0) do
          wallet1 = create_wallet_with_applies_to(
            applies_to: {billable_metric_codes: [billable_metric.code]},
            granted_credits: "30"
          )
          tx1 = wallet1.wallet_transactions.inbound.first
        end

        travel_to(time_0 + 1.hour) do
          wallet2 = create_wallet_with_applies_to(
            applies_to: {billable_metric_codes: [billable_metric2.code]},
            granted_credits: "50"
          )
          tx2 = wallet2.wallet_transactions.inbound.first

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          # Ingest $25 usage for each metric
          ingest_usage(subscription, 25)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric2.code,
            external_subscription_id: subscription.external_id,
            properties: {billable_metric2.field_name => 25}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.subscription.first
        end

        # Verify invoice prepaid breakdown sums from both wallets
        expect(invoice.prepaid_credit_amount_cents).to eq(5000)
        expect(invoice.prepaid_granted_credit_amount_cents).to eq(5000)

        # Verify outbound transactions created for each wallet
        tx3 = wallet1.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        tx4 = wallet2.wallet_transactions.outbound.where(transaction_status: :invoiced).first

        expect(tx3.amount_cents).to eq(2500)
        expect(tx4.amount_cents).to eq(2500)

        # Verify consumption records
        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.count).to eq(1)
        expect(fundings_tx3.first[:amount_cents]).to eq(2500)
        expect(fundings_tx3.first[:wallet_transaction][:lago_id]).to eq(tx1.id)

        fundings_tx4 = get_fundings(tx4)
        expect(fundings_tx4.count).to eq(1)
        expect(fundings_tx4.first[:amount_cents]).to eq(2500)
        expect(fundings_tx4.first[:wallet_transaction][:lago_id]).to eq(tx2.id)

        # Verify remaining amounts
        expect(tx1.reload.remaining_amount_cents).to eq(500)
        expect(tx2.reload.remaining_amount_cents).to eq(2500)
      end
    end

    describe "Mixed traceable and non-traceable wallets" do
      # When one wallet is traceable and another is not,
      # prepaid credit breakdown should NOT be set on the invoice.

      it "does not set prepaid breakdown when not all wallets are traceable" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        subscription = nil
        invoice = nil

        travel_to(time_0) do
          wallet1 = create_wallet_with_applies_to(
            applies_to: {billable_metric_codes: [billable_metric.code]},
            granted_credits: "30",
            traceable: true
          )
        end

        travel_to(time_0 + 1.hour) do
          # Create second wallet but do NOT set traceable
          wallet2 = create_wallet_with_applies_to(
            applies_to: {billable_metric_codes: [billable_metric2.code]},
            granted_credits: "50",
            traceable: false
          )

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
          create_event({
            transaction_id: SecureRandom.uuid,
            code: billable_metric2.code,
            external_subscription_id: subscription.external_id,
            properties: {billable_metric2.field_name => 25}
          })
          perform_usage_update
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.subscription.first
        end

        # Prepaid credits were applied
        expect(invoice.prepaid_credit_amount_cents).to eq(5000)

        # But breakdown is NOT set because not all wallets are traceable
        expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
        expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil

        # Consumption records exist only for traceable wallet
        tx3 = wallet1.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.count).to eq(1)

        # Non-traceable wallet has no consumption records
        tx4 = wallet2.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        expect(tx4.fundings).to be_empty
      end
    end

    describe "Multiple wallets with priority-based consumption" do
      # Customer has two unrestricted wallets with different priorities:
      # - Wallet 1: $30, priority 1 (higher priority)
      # - Wallet 2: $50, priority 2
      # Invoice consumes $60:
      # - First: $30 from Wallet 1 (fully consumed)
      # - Then: $30 from Wallet 2

      it "consumes from wallets in priority order" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet1 = nil
        wallet2 = nil
        tx1 = nil
        tx2 = nil
        subscription = nil
        invoice = nil

        travel_to(time_0) do
          params1 = {
            external_customer_id: customer.external_id,
            rate_amount: "1",
            name: "Priority 1 Wallet",
            currency: "EUR",
            granted_credits: "30",
            priority: 1,
            invoice_requires_successful_payment: false
          }
          wallet1 = create_wallet(params1, as: :model)
          wallet1.update!(traceable: true)
          # Manually set remaining_amount_cents since traceable was set after transaction creation
          tx1 = wallet1.wallet_transactions.inbound.first
          tx1.update!(remaining_amount_cents: tx1.amount_cents)
        end

        travel_to(time_0 + 1.hour) do
          params2 = {
            external_customer_id: customer.external_id,
            rate_amount: "1",
            name: "Priority 2 Wallet",
            currency: "EUR",
            granted_credits: "50",
            priority: 2,
            invoice_requires_successful_payment: false
          }
          wallet2 = create_wallet(params2, as: :model)
          wallet2.update!(traceable: true)
          # Manually set remaining_amount_cents since traceable was set after transaction creation
          tx2 = wallet2.wallet_transactions.inbound.first
          tx2.update!(remaining_amount_cents: tx2.amount_cents)

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 60)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.subscription.first
        end

        expect(invoice.prepaid_credit_amount_cents).to eq(6000)
        expect(invoice.prepaid_granted_credit_amount_cents).to eq(6000)

        # Wallet 1 (priority 1) fully consumed
        tx3 = wallet1.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        expect(tx3.amount_cents).to eq(3000)

        fundings_tx3 = get_fundings(tx3)
        expect(fundings_tx3.count).to eq(1)
        expect(fundings_tx3.first[:amount_cents]).to eq(3000)

        # Wallet 2 (priority 2) partially consumed
        tx4 = wallet2.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        expect(tx4.amount_cents).to eq(3000)

        fundings_tx4 = get_fundings(tx4)
        expect(fundings_tx4.count).to eq(1)
        expect(fundings_tx4.first[:amount_cents]).to eq(3000)

        expect(tx1.reload.remaining_amount_cents).to eq(0)
        expect(tx2.reload.remaining_amount_cents).to eq(2000)
      end
    end
  end

  describe "Non-traceable wallet scenarios (self-hosted pre-migration)" do
    # These tests ensure non-traceable wallets still work correctly for
    # self-hosted instances that have not yet run the traceability migration.

    describe "Invoice consumption with non-traceable wallet" do
      it "deducts from wallet without creating consumption records or prepaid breakdown" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil
        invoice = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")

          subscription = setup_subscription
        end

        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 40)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
          invoice = subscription.invoices.subscription.first
        end

        expect(invoice.prepaid_credit_amount_cents).to eq(4000)
        expect(invoice.prepaid_granted_credit_amount_cents).to be_nil
        expect(invoice.prepaid_purchased_credit_amount_cents).to be_nil

        tx = wallet.wallet_transactions.outbound.where(transaction_status: :invoiced).first
        expect(tx).to be_present
        expect(tx.amount_cents).to eq(4000)
        expect(tx.fundings).to be_empty

        expect(wallet.reload.balance_cents).to eq(6000)
      end
    end

    describe "Voiding credits with non-traceable wallet" do
      it "voids credits without creating consumption records" do
        wallet = create_non_traceable_wallet
        top_up_wallet(wallet, granted_credits: "100")

        create_wallet_transaction({
          wallet_id: wallet.id,
          voided_credits: "40"
        })

        tx = wallet.wallet_transactions.outbound.where(transaction_status: :voided).first
        expect(tx).to be_present
        expect(tx.amount_cents).to eq(4000)
        expect(tx.fundings).to be_empty

        expect(wallet.reload.balance_cents).to eq(6000)
      end
    end

    describe "Multiple billing periods with non-traceable wallet" do
      it "deducts across billing periods without consumption tracking" do
        time_0 = DateTime.new(2022, 12, 1)
        wallet = nil
        subscription = nil

        travel_to(time_0) do
          wallet = create_non_traceable_wallet
          top_up_wallet(wallet, granted_credits: "100")

          subscription = setup_subscription
        end

        # First billing period - $25 usage
        travel_to(time_0 + 5.days) do
          ingest_usage(subscription, 25)
        end

        travel_to(time_0 + 1.month) do
          perform_billing
        end

        invoice1 = subscription.invoices.subscription.first
        expect(invoice1.prepaid_credit_amount_cents).to eq(2500)
        expect(invoice1.prepaid_granted_credit_amount_cents).to be_nil

        # Second billing period - $35 usage
        travel_to(time_0 + 1.month + 5.days) do
          ingest_usage(subscription, 35)
        end

        travel_to(time_0 + 2.months) do
          perform_billing
        end

        invoice2 = subscription.invoices.subscription.order(created_at: :desc).first
        expect(invoice2.prepaid_credit_amount_cents).to eq(3500)
        expect(invoice2.prepaid_granted_credit_amount_cents).to be_nil

        expect(wallet.reload.balance_cents).to eq(4000)
        expect(WalletTransactionConsumption.where(organization_id: organization.id).count).to eq(0)
      end
    end
  end
end
