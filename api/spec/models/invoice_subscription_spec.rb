# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceSubscription do
  subject(:invoice_subscription) do
    create(
      :invoice_subscription,
      from_datetime:,
      to_datetime:,
      charges_from_datetime:,
      charges_to_datetime:,
      fixed_charges_from_datetime:,
      fixed_charges_to_datetime:
    )
  end

  let(:invoice) { invoice_subscription.invoice }
  let(:subscription) { invoice_subscription.subscription }

  let(:from_datetime) { "2022-01-01 00:00:00" }
  let(:to_datetime) { "2022-01-31 23:59:59" }
  let(:charges_from_datetime) { "2022-01-01 00:00:00" }
  let(:charges_to_datetime) { "2022-01-31 23:59:59" }
  let(:fixed_charges_from_datetime) { "2022-01-01 00:00:00" }
  let(:fixed_charges_to_datetime) { "2022-01-31 23:59:59" }

  it { is_expected.to belong_to(:organization) }

  describe ".order_by_subscription_invoice_name" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, customer:, organization:) }

    let(:plan_zebra) { create(:plan, organization:, name: "Zebra Plan", invoice_display_name: nil) }
    let(:plan_alpha) { create(:plan, organization:, name: "Alpha Plan", invoice_display_name: nil) }
    let(:plan_beta) { create(:plan, organization:, name: "Beta Plan", invoice_display_name: "Custom Beta") }

    let(:subscription_zebra) { create(:subscription, customer:, plan: plan_zebra, name: nil) }
    let(:subscription_alpha) { create(:subscription, customer:, plan: plan_alpha, name: nil) }
    let(:subscription_custom) { create(:subscription, customer:, plan: plan_beta, name: "AAA Custom Name") }

    before do
      create(:invoice_subscription, invoice:, subscription: subscription_zebra)
      create(:invoice_subscription, invoice:, subscription: subscription_alpha)
      create(:invoice_subscription, invoice:, subscription: subscription_custom)
    end

    it "orders by COALESCE(subscription.name, plan.invoice_display_name, plan.name) ASC" do
      result = invoice.invoice_subscriptions.order_by_subscription_invoice_name

      expect(result.map { |is| is.subscription.invoice_name }).to eq([
        "AAA Custom Name",
        "Alpha Plan",
        "Zebra Plan"
      ])
    end

    it "uses plan.invoice_display_name when subscription.name is nil" do
      subscription_alpha.update!(name: nil)
      plan_alpha.update!(invoice_display_name: "ZZZ Display Name")

      result = invoice.invoice_subscriptions.order_by_subscription_invoice_name

      # Alphabetical order: AAA < ZZZ < Zebra
      expect(result.map { |is| is.subscription.invoice_name }).to eq([
        "AAA Custom Name",
        "ZZZ Display Name",
        "Zebra Plan"
      ])
    end
  end

  describe ".starting_from" do
    let(:subscription) { create(:subscription) }

    let!(:invoice_subscription_at_boundary) { create(:invoice_subscription, subscription:, from_datetime: "2022-02-01 00:00:00") }
    let!(:invoice_subscription_after_boundary) { create(:invoice_subscription, subscription:, from_datetime: "2022-03-01 00:00:00") }

    before { create(:invoice_subscription, subscription:, from_datetime: "2022-01-01 00:00:00") }

    it "returns invoice subscription starting from the given datetime" do
      result = subscription.invoice_subscriptions.starting_from("2022-02-01 00:00:00")

      expect(result).to eq([invoice_subscription_at_boundary, invoice_subscription_after_boundary])
    end
  end

  describe ".matching?" do
    subject(:matching?) { described_class.matching?(subscription, boundaries) }

    let(:subscription) { create(:subscription, plan:) }
    let(:plan) { create(:plan, interval: plan_interval, bill_charges_monthly:, bill_fixed_charges_monthly:) }
    let(:plan_interval) { "monthly" }
    let(:bill_charges_monthly) { nil }
    let(:bill_fixed_charges_monthly) { nil }

    let(:boundaries) do
      BillingPeriodBoundaries.new(
        from_datetime: from_datetime.to_datetime,
        to_datetime: to_datetime.to_datetime,
        charges_from_datetime: charges_from_datetime.to_datetime,
        charges_to_datetime: charges_to_datetime.to_datetime,
        fixed_charges_from_datetime: fixed_charges_from_datetime.to_datetime,
        fixed_charges_to_datetime: fixed_charges_to_datetime.to_datetime,
        charges_duration: 1.month,
        timestamp: Time.current
      )
    end

    let(:base_from_datetime) { "2022-01-01 00:00:00" }
    let(:base_to_datetime) { "2022-01-31 23:59:59" }
    let(:base_charges_from_datetime) { "2022-01-01 00:00:00" }
    let(:base_charges_to_datetime) { "2022-01-31 23:59:59" }
    let(:base_fixed_charges_from_datetime) { "2022-01-01 00:00:00" }
    let(:base_fixed_charges_to_datetime) { "2022-01-31 23:59:59" }

    let(:from_datetime) { base_from_datetime }
    let(:to_datetime) { base_to_datetime }
    let(:charges_from_datetime) { base_charges_from_datetime }
    let(:charges_to_datetime) { base_charges_to_datetime }
    let(:fixed_charges_from_datetime) { base_fixed_charges_from_datetime }
    let(:fixed_charges_to_datetime) { base_fixed_charges_to_datetime }

    context "when there are matching invoice subscriptions" do
      let(:invoice_subscription_recurring) { true }

      before do
        create(
          :invoice_subscription,
          subscription:,
          from_datetime: base_from_datetime,
          to_datetime: base_to_datetime,
          charges_from_datetime: base_charges_from_datetime,
          charges_to_datetime: base_charges_to_datetime,
          fixed_charges_from_datetime: base_fixed_charges_from_datetime,
          fixed_charges_to_datetime: base_fixed_charges_to_datetime,
          recurring: invoice_subscription_recurring
        )
      end

      context "with recurring" do
        it { is_expected.to eq(true) }

        context "when non-recurring records exist" do
          let(:invoice_subscription_recurring) { false }

          it { is_expected.to eq(false) }
        end
      end

      context "with not recurring" do
        subject(:matching?) { described_class.matching?(subscription, boundaries, recurring: false) }

        it { is_expected.to eq(true) }

        context "when non-recurring records exist" do
          let(:invoice_subscription_recurring) { false }

          it { is_expected.to eq(true) }
        end
      end
    end

    context "when there are no matching invoice subscriptions" do
      context "when no records exist" do
        it { is_expected.to eq(false) }
      end

      context "when records exist but don't match boundaries" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        context "when from_datetime doesn't match" do
          let(:from_datetime) { "2022-02-01 00:00:00" }

          it { is_expected.to eq(false) }
        end

        context "when to_datetime doesn't match" do
          let(:to_datetime) { "2022-02-28 23:59:59" }

          it { is_expected.to eq(false) }
        end

        context "when subscription_id doesn't match" do
          subject(:matching?) { described_class.matching?(different_subscription, boundaries) }

          let(:different_subscription) { create(:subscription, plan:) }

          it { is_expected.to eq(false) }
        end
      end

      context "when record exists but doesn't match charges boundaries" do
        let(:charges_from_datetime) { "2022-02-01 00:00:00" }
        let(:charges_to_datetime) { "2022-02-28 23:59:59" }

        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        it "ignores charges boundaries and returns true" do
          expect(matching?).to be(true)
        end
      end
    end

    context "with yearly plan that doesn't bill charges monthly" do
      let(:plan_interval) { "yearly" }
      let(:bill_charges_monthly) { false }
      let(:charges_from_datetime) { "2022-02-01 00:00:00" }
      let(:charges_to_datetime) { "2022-02-28 23:59:59" }

      before do
        create(
          :invoice_subscription,
          subscription:,
          from_datetime: base_from_datetime,
          to_datetime: base_to_datetime,
          charges_from_datetime: base_charges_from_datetime,
          charges_to_datetime: base_charges_to_datetime,
          fixed_charges_from_datetime: base_fixed_charges_from_datetime,
          fixed_charges_to_datetime: base_fixed_charges_to_datetime,
          recurring: true
        )
      end

      it "ignores charges boundaries and returns true" do
        expect(matching?).to be(true)
      end
    end

    context "with yearly plan that bills charges monthly" do
      let(:plan_interval) { "yearly" }
      let(:bill_charges_monthly) { true }

      context "when charges boundaries match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        it { is_expected.to eq(true) }
      end

      context "when charges boundaries don't match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        context "when charges_from_datetime doesn't match" do
          let(:charges_from_datetime) { "2022-02-01 00:00:00" }

          it { is_expected.to eq(false) }
        end

        context "when charges_to_datetime doesn't match" do
          let(:charges_to_datetime) { "2022-02-28 23:59:59" }

          it { is_expected.to eq(false) }
        end
      end
    end

    context "with yearly plan that bills fixed charges monthly" do
      let(:plan_interval) { "yearly" }
      let(:bill_fixed_charges_monthly) { true }

      context "when fixed charges boundaries match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        it { is_expected.to eq(true) }
      end

      context "when fixed charges boundaries don't match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        context "when fixed_charges_from_datetime doesn't match" do
          let(:fixed_charges_from_datetime) { "2022-02-01 00:00:00" }

          it { is_expected.to eq(false) }
        end

        context "when fixed_charges_to_datetime doesn't match" do
          let(:fixed_charges_to_datetime) { "2022-02-28 23:59:59" }

          it { is_expected.to eq(false) }
        end
      end
    end

    context "with semiannual plan that doesn't bill charges monthly" do
      let(:plan_interval) { "semiannual" }
      let(:bill_charges_monthly) { false }
      let(:charges_from_datetime) { "2022-02-01 00:00:00" }
      let(:charges_to_datetime) { "2022-02-28 23:59:59" }

      before do
        create(
          :invoice_subscription,
          subscription:,
          from_datetime: base_from_datetime,
          to_datetime: base_to_datetime,
          charges_from_datetime: base_charges_from_datetime,
          charges_to_datetime: base_charges_to_datetime,
          fixed_charges_from_datetime: base_fixed_charges_from_datetime,
          fixed_charges_to_datetime: base_fixed_charges_to_datetime,
          recurring: true
        )
      end

      it "ignores charges boundaries and returns true" do
        expect(matching?).to be(true)
      end
    end

    context "with semiannual plan that bills charges monthly" do
      let(:plan_interval) { "semiannual" }
      let(:bill_charges_monthly) { true }

      context "when charges boundaries match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        it { is_expected.to eq(true) }
      end

      context "when charges boundaries don't match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        context "when charges_from_datetime doesn't match" do
          let(:charges_from_datetime) { "2022-02-01 00:00:00" }

          it { is_expected.to eq(false) }
        end

        context "when charges_to_datetime doesn't match" do
          let(:charges_to_datetime) { "2022-02-28 23:59:59" }

          it { is_expected.to eq(false) }
        end
      end
    end

    context "with semiannual plan that bills fixed charges monthly" do
      let(:plan_interval) { "semiannual" }
      let(:bill_fixed_charges_monthly) { true }

      context "when charges boundaries match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        it { is_expected.to eq(true) }
      end

      context "when charges boundaries don't match" do
        before do
          create(
            :invoice_subscription,
            subscription:,
            from_datetime: base_from_datetime,
            to_datetime: base_to_datetime,
            charges_from_datetime: base_charges_from_datetime,
            charges_to_datetime: base_charges_to_datetime,
            fixed_charges_from_datetime: base_fixed_charges_from_datetime,
            fixed_charges_to_datetime: base_fixed_charges_to_datetime,
            recurring: true
          )
        end

        context "when charges_from_datetime doesn't match" do
          let(:fixed_charges_from_datetime) { "2022-02-01 00:00:00" }

          it { is_expected.to eq(false) }
        end

        context "when charges_to_datetime doesn't match" do
          let(:fixed_charges_to_datetime) { "2022-02-28 23:59:59" }

          it { is_expected.to eq(false) }
        end
      end
    end

    context "with non-yearly plans" do
      let(:charges_from_datetime) { "2022-02-01 00:00:00" }
      let(:charges_to_datetime) { "2022-02-28 23:59:59" }

      before do
        create(
          :invoice_subscription,
          subscription:,
          from_datetime: base_from_datetime,
          to_datetime: base_to_datetime,
          charges_from_datetime: base_charges_from_datetime,
          charges_to_datetime: base_charges_to_datetime,
          fixed_charges_from_datetime: base_fixed_charges_from_datetime,
          fixed_charges_to_datetime: base_fixed_charges_to_datetime,
          recurring: true
        )
      end

      context "with monthly plan" do
        let(:plan_interval) { "monthly" }

        it "ignores charges boundaries and returns true" do
          expect(matching?).to be(true)
        end
      end

      context "with quarterly plan" do
        let(:plan_interval) { "quarterly" }

        it "ignores charges boundaries and returns true" do
          expect(matching?).to be(true)
        end
      end

      context "with weekly plan" do
        let(:plan_interval) { "weekly" }

        it "ignores charges boundaries and returns true" do
          expect(matching?).to be(true)
        end
      end
    end
  end

  describe "#fees" do
    it "returns corresponding fees" do
      first_fee = create(:fee, subscription_id: subscription.id, invoice_id: invoice.id)
      create(:fee, subscription_id: subscription.id)
      create(:fee, invoice_id: invoice.id)

      expect(invoice_subscription.fees).to eq([first_fee])
    end
  end

  describe "#charge_amount_cents" do
    it "returns the sum of the related charge fees" do
      charge = create(:standard_charge)
      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        charge:,
        amount_cents: 100
      )

      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        charge:,
        amount_cents: 200
      )

      create(
        :fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 400
      )

      expect(invoice_subscription.charge_amount_cents).to eq(300)
    end
  end

  describe "#fixed_charge_amount_cents" do
    before do
      create(
        :fixed_charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 100
      )

      create(
        :fixed_charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 200
      )

      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 400
      )
    end

    it "returns the sum of the related fixed charge fees" do
      expect(invoice_subscription.fixed_charge_amount_cents).to eq(300)
    end
  end

  describe "#subscription_amount_cents" do
    it "returns the amount of the subscription fees" do
      create(
        :fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 50
      )

      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        charge: create(:standard_charge),
        amount_cents: 200
      )

      expect(invoice_subscription.subscription_amount_cents).to eq(50)
    end
  end

  describe "#total_amount_cents" do
    it "returns the sum of the related fees" do
      charge = create(:standard_charge)
      create(
        :fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 50
      )

      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        charge:,
        amount_cents: 200
      )

      create(
        :charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        charge:,
        amount_cents: 100
      )

      create(
        :fixed_charge_fee,
        subscription_id: subscription.id,
        invoice_id: invoice.id,
        amount_cents: 25
      )

      expect(invoice_subscription.total_amount_cents).to eq(375)
    end
  end

  describe "#total_amount_currency" do
    it "returns the currency of the total amount" do
      expect(invoice_subscription.total_amount_currency).to eq(subscription.plan.amount_currency)
    end
  end

  describe "#charge_amount_currency" do
    it "returns the currency of the charge amount" do
      expect(invoice_subscription.charge_amount_currency).to eq(subscription.plan.amount_currency)
    end
  end

  describe "#fixed_charge_amount_currency" do
    it "returns the currency of the fixed charge amount" do
      expect(invoice_subscription.fixed_charge_amount_currency).to eq(subscription.plan.amount_currency)
    end
  end

  describe "#subscription_amount_currency" do
    it "returns the currency of the subscription amount" do
      expect(invoice_subscription.subscription_amount_currency).to eq(subscription.plan.amount_currency)
    end
  end

  describe "#previous_invoice_subscription" do
    subject(:previous_invoice_subscription_call) { invoice_subscription.previous_invoice_subscription }

    context "when it has previous invoice subscription" do
      let(:previous_invoice_subscription) do
        create(
          :invoice_subscription,
          subscription: invoice_subscription.subscription,
          from_datetime: invoice_subscription.from_datetime - 1.year,
          to_datetime: invoice_subscription.to_datetime - 1.year,
          charges_from_datetime: invoice_subscription.charges_from_datetime - 1.year,
          charges_to_datetime: invoice_subscription.charges_to_datetime - 1.year
        )
      end

      before do
        previous_invoice_subscription

        create(
          :fee,
          subscription: previous_invoice_subscription.subscription,
          invoice: previous_invoice_subscription.invoice,
          amount_cents: 857 # prorated
        )
      end

      it "returns previous invoice subscription" do
        expect(previous_invoice_subscription_call).to eq(previous_invoice_subscription)
      end
    end

    context "when there is a previous invoice subscription for different subscription" do
      let(:previous_invoice_subscription) do
        create(
          :invoice_subscription,
          from_datetime: invoice_subscription.from_datetime - 1.year,
          to_datetime: invoice_subscription.to_datetime - 1.year,
          charges_from_datetime: invoice_subscription.charges_from_datetime - 1.year,
          charges_to_datetime: invoice_subscription.charges_to_datetime - 1.year
        )
      end

      before do
        previous_invoice_subscription

        create(
          :invoice_subscription,
          from_datetime: invoice_subscription.from_datetime - 2.years,
          to_datetime: invoice_subscription.to_datetime - 2.years,
          charges_from_datetime: invoice_subscription.charges_from_datetime - 2.years,
          charges_to_datetime: invoice_subscription.charges_to_datetime - 2.years
        )
      end

      it "returns nil" do
        expect(previous_invoice_subscription_call).to be(nil)
      end
    end

    context "when it has no previous invoice subscription" do
      before do
        create(
          :invoice_subscription,
          from_datetime: invoice_subscription.from_datetime + 1.year,
          to_datetime: invoice_subscription.to_datetime + 1.year,
          charges_from_datetime: invoice_subscription.charges_from_datetime + 1.year,
          charges_to_datetime: invoice_subscription.charges_to_datetime + 1.year
        )
      end

      it "returns nil" do
        expect(previous_invoice_subscription_call).to be(nil)
      end
    end
  end
end
