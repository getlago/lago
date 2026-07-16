# frozen_string_literal: true

require "rails_helper"

Rspec.describe Credits::ProgressiveBillingService do
  subject(:credit_service) { described_class.new(invoice:) }

  let(:subscription) { create(:subscription, customer_id: customer.id) }
  let(:organization) { subscription.organization }
  let(:customer) { create(:customer) }
  let(:subscriptions) { [subscription] }

  let(:invoice) do
    create(:invoice,
      :subscription,
      customer:,
      organization:,
      sub_total_excluding_taxes_amount_cents: 1000,
      subscriptions: subscriptions)
  end

  let(:subscription_fees) { [subscription_fee1, subscription_fee2] }
  let(:subscription_fee1) { create(:charge_fee, invoice:, subscription:, amount_cents: 500) }
  let(:subscription_fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 500) }

  before do
    invoice
    invoice.invoice_subscriptions.each { |is| is.update!(charges_from_datetime: invoice.issuing_date - 1.month, timestamp: invoice.issuing_date, charges_to_datetime: invoice.issuing_date) }
    subscription_fees
  end

  context "without progressive billing invoices" do
    describe "#call" do
      it "does not apply any credit to the invoice" do
        result = credit_service.call
        expect(result.credits).to be_empty
        expect(invoice.progressive_billing_credit_amount_cents).to be_zero
      end
    end
  end

  context "with one progressive billing invoice for the sole subscription" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_fee) {
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    }

    before do
      progressive_billing_invoice
      progressive_billing_fee
      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )
    end

    describe "#call" do
      it "applies one credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        credit = result.credits.sole
        expect(credit.amount_cents).to eq(20)
        expect(invoice.progressive_billing_credit_amount_cents).to eq(20)
        expect(subscription_fee1.reload.precise_coupons_amount_cents).to eq(20)
        expect(subscription_fee2.reload.precise_coupons_amount_cents).to eq(0)
      end

      it "applies the credit to the already-loaded fees association without a reload" do
        invoice.fees.load

        credit_service.call

        cached_fee = invoice.fees.find { |fee| fee.id == subscription_fee1.id }
        expect(cached_fee.precise_coupons_amount_cents).to eq(20)
        expect(cached_fee.sub_total_excluding_taxes_amount_cents).to eq(cached_fee.amount_cents - 20)
      end

      context "when progressive billing credits are greater than amount cents" do
        let(:subscription_fee1) { create(:charge_fee, invoice:, subscription:, amount_cents: 19) }

        it "applies correctly one credit to the invoice" do
          result = credit_service.call
          expect(result.credits.size).to eq(1)
          credit = result.credits.sole
          expect(credit.amount_cents).to eq(19)
          expect(invoice.progressive_billing_credit_amount_cents).to eq(19)
          expect(subscription_fee1.reload.precise_coupons_amount_cents).to eq(19)
          expect(subscription_fee2.reload.precise_coupons_amount_cents).to eq(0)
        end
      end

      context "with additional subscription fee" do
        let(:subscription_fees) { [subscription_fee1, subscription_fee2, subscription_fee3] }
        let(:subscription_fee1) { create(:charge_fee, invoice:, subscription:, amount_cents: 300) }
        let(:subscription_fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 300) }
        let(:subscription_fee3) { create(:fee, invoice:, subscription:, amount_cents: 400) }

        it "calculate correctly credits and weighted amounts" do
          result = credit_service.call
          expect(result.credits.size).to eq(1)
          credit = result.credits.sole

          expect(credit.amount_cents).to eq(20)
          expect(invoice.progressive_billing_credit_amount_cents).to eq(20)

          expect(subscription_fee1.reload.precise_coupons_amount_cents).to eq(20)
          expect(subscription_fee2.reload.precise_coupons_amount_cents).to eq(0)
          expect(subscription_fee3.reload.precise_coupons_amount_cents).to eq(0)
        end
      end

      context "when progressive billing invoice has the same charges as the final invoice" do
        let(:progressive_billing_invoice) do
          create(
            :invoice,
            :with_subscriptions,
            organization:,
            customer:,
            status: "finalized",
            invoice_type: :progressive_billing,
            subscriptions: [subscription],
            issuing_date: invoice.issuing_date - 1.day,
            created_at: invoice.issuing_date - 1.day,
            fees_amount_cents: 40
          )
        end

        let(:progressive_billing_fee2) {
          create(:charge_fee,
            amount_cents: 20,
            charge: subscription_fee2.charge,
            invoice: progressive_billing_invoice)
        }

        before { progressive_billing_fee2 }

        it "applies one credit to the invoice" do
          result = credit_service.call
          expect(result.credits.size).to eq(1)
          credit = result.credits.sole
          expect(credit.amount_cents).to eq(40)
          expect(invoice.progressive_billing_credit_amount_cents).to eq(40)
          expect(subscription_fee1.reload.precise_coupons_amount_cents).to eq(20)
          expect(subscription_fee2.reload.precise_coupons_amount_cents).to eq(20)
        end
      end
    end
  end

  context "with multiple progressive billing invoices for the sole subscription" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 2.days,
        created_at: invoice.issuing_date - 2.days,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_invoice2) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 200
      )
    end
    let(:progressive_billing_fee) do
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    end
    let(:progressive_billing_fee2) do
      create(:charge_fee,
        amount_cents: 200,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice2)
    end

    before do
      progressive_billing_fee
      progressive_billing_fee2
      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )
      progressive_billing_invoice2.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice2.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice2.issuing_date,
        timestamp: progressive_billing_invoice2.issuing_date
      )
    end

    describe "#call" do
      it "applies one credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        sole_credit = result.credits.find { |credit| credit.progressive_billing_invoice == progressive_billing_invoice2 }
        expect(sole_credit.amount_cents).to eq(200)

        expect(invoice.progressive_billing_credit_amount_cents).to eq(200)
      end
    end
  end

  context "with multiple progressive billing invoices on the same date for the sole subscription" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_invoice2) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day + 10.minutes,
        fees_amount_cents: 200
      )
    end
    let(:progressive_billing_fee) do
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    end
    let(:progressive_billing_fee2) do
      create(:charge_fee,
        amount_cents: 200,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice2)
    end

    before do
      progressive_billing_fee
      progressive_billing_fee2
      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )
      progressive_billing_invoice2.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice2.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice2.issuing_date,
        timestamp: progressive_billing_invoice2.issuing_date
      )
    end

    describe "#call" do
      it "applies one credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        sole_credit = result.credits.find { |credit| credit.progressive_billing_invoice == progressive_billing_invoice2 }
        expect(sole_credit.amount_cents).to eq(200)

        expect(invoice.progressive_billing_credit_amount_cents).to eq(200)
      end
    end
  end

  context "with multiple progressive billing invoices for the sole subscription with an amount higher than the subscription charges" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 3.days,
        created_at: invoice.issuing_date - 3.days,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_invoice2) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 2.days,
        created_at: invoice.issuing_date - 2.days,
        fees_amount_cents: 1000
      )
    end

    let(:progressive_billing_invoice3) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 2000
      )
    end
    let(:progressive_billing_fee) do
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    end
    let(:progressive_billing_fee2) do
      create(:charge_fee,
        amount_cents: 1_000,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice2)
    end
    let(:progressive_billing_fee3) do
      create(:charge_fee,
        amount_cents: 2_000,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice3)
    end

    before do
      progressive_billing_fee
      progressive_billing_fee2
      progressive_billing_fee3

      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )
      progressive_billing_invoice2.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice2.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice2.issuing_date,
        timestamp: progressive_billing_invoice2.issuing_date
      )
      progressive_billing_invoice3.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice3.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice3.issuing_date,
        timestamp: progressive_billing_invoice3.issuing_date
      )
    end

    describe "#call" do
      it "applies the last credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        sole_credit = result.credits.find { |credit| credit.progressive_billing_invoice == progressive_billing_invoice3 }
        expect(sole_credit.amount_cents).to eq(500)

        expect(invoice.progressive_billing_credit_amount_cents).to eq(500)
      end

      it "creates credit notes for the remainder of the progressive billed invoices" do
        expect { credit_service.call }.to change(CreditNote, :count).by(1)
        # we were able to credit 1000 from the invoice, this means we've got 20 and 200 remaining respectively
        expect(progressive_billing_invoice3.credit_notes.size).to eq(1)

        first = progressive_billing_invoice3.credit_notes.sole
        expect(first.credit_amount_cents).to eq(1_500) # 2000 - 500 - targeting specific fee
      end
    end
  end

  context "with one progressive billing invoice for one subscription and one without" do
    let(:subscription2) { create(:subscription, customer_id: customer.id) }
    let(:subscriptions) { [subscription, subscription2] }

    let(:subscription_fees) { [subscription_fee1, subscription_fee2, subscription2_fee1, subscription2_fee2] }
    let(:subscription2_fee1) { create(:charge_fee, invoice:, subscription: subscription2, amount_cents: 500) }
    let(:subscription2_fee2) { create(:charge_fee, invoice:, subscription: subscription2, amount_cents: 500) }

    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 20
      )
    end
    let(:progressive_billing_fee) do
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    end

    before do
      progressive_billing_invoice
      progressive_billing_fee
      progressive_billing_invoice.invoice_subscriptions.each do |is|
        is.update!(
          charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
          charges_to_datetime: progressive_billing_invoice.issuing_date,
          timestamp: progressive_billing_invoice.issuing_date
        )
      end
    end

    describe "#call" do
      it "applies one credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        credit = result.credits.sole
        expect(credit.amount_cents).to eq(20)
        expect(credit.progressive_billing_invoice).to eq(progressive_billing_invoice)
        expect(invoice.progressive_billing_credit_amount_cents).to eq(20)
      end
    end
  end

  context "with one progressive billing invoice outside the current billing boundaries for the sole subscription" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 2.months,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_fee) do
      create(:charge_fee,
        amount_cents: 20,
        invoice: progressive_billing_invoice)
    end

    before do
      progressive_billing_invoice
      progressive_billing_fee
      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )
    end

    describe "#call" do
      it "applies no credit to the invoice" do
        result = credit_service.call
        expect(result.credits).to be_empty
        expect(invoice.progressive_billing_credit_amount_cents).to eq(0)
      end
    end
  end

  context "with a spy on Subscriptions::ProgressiveBilledAmount" do
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription],
        issuing_date: invoice.issuing_date - 1.day,
        created_at: invoice.issuing_date - 1.day,
        fees_amount_cents: 20
      )
    end

    let(:progressive_billing_fee) {
      create(:charge_fee,
        amount_cents: 20,
        charge: subscription_fee1.charge,
        invoice: progressive_billing_invoice)
    }

    let(:dummy_result) do
      BaseService::Result.new.tap do |r|
        r.to_
      end
    end

    before do
      progressive_billing_invoice
      progressive_billing_fee
      progressive_billing_invoice.invoice_subscriptions.first.update!(
        charges_from_datetime: progressive_billing_invoice.issuing_date - 1.month,
        charges_to_datetime: progressive_billing_invoice.issuing_date,
        timestamp: progressive_billing_invoice.issuing_date
      )

      allow(Subscriptions::ProgressiveBilledAmount).to receive(:call).and_wrap_original do |original_method, *args, **kwargs, &block|
        result = original_method.call(*args, **kwargs, &block)
        expect(result).to receive(:to_credit_amount).and_call_original # rubocop:disable RSpec/ExpectInHook,RSpec/MessageSpies
        result
      end
    end

    describe "#call" do
      it "applies one credit to the invoice" do
        result = credit_service.call
        expect(result.credits.size).to eq(1)
        credit = result.credits.sole
        expect(credit.amount_cents).to eq(20)
        expect(invoice.progressive_billing_credit_amount_cents).to eq(20)

        expect(subscription_fee1.reload.precise_coupons_amount_cents).to eq(20)
        expect(subscription_fee2.reload.precise_coupons_amount_cents).to eq(0)
      end
    end
  end
end
