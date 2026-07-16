# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fee do
  subject { build(:fee) }

  it { is_expected.to belong_to(:add_on).optional }
  it { is_expected.to belong_to(:charge).optional }
  it { is_expected.to belong_to(:fixed_charge).optional }
  it { is_expected.to have_many(:presentation_breakdowns) }
  it { is_expected.to have_one(:fixed_charge_add_on).through(:fixed_charge) }
  it { is_expected.to have_one(:adjusted_fee).dependent(:nullify) }
  it { is_expected.to have_one(:billable_metric).through(:charge) }
  it { is_expected.to have_one(:customer).through(:subscription) }
  it { is_expected.to have_one(:pricing_unit_usage).dependent(:destroy) }
  it { is_expected.to have_one(:true_up_fee).with_foreign_key(:true_up_parent_fee_id).class_name("Fee").dependent(:destroy) }
  it { is_expected.to belong_to(:original_fee).class_name("Fee").optional }

  describe "#ordered_by_period" do
    let(:fee1) do
      create(:fee, properties: {
        "from_datetime" => "2021-02-01T00:00:00Z",
        "to_datetime" => "2021-03-31T23:59:59Z"
      })
    end
    let(:fee2) do
      create(:fee, properties: {
        "from_datetime" => "2021-03-01T00:00:00Z",
        "to_datetime" => "2021-04-20T23:59:59Z"
      })
    end
    let(:fee3) do
      create(:fee, properties: {
        "from_datetime" => "2021-01-01T00:00:00Z",
        "to_datetime" => "2021-02-18T23:59:59Z"
      })
    end
    let(:fee4) do
      create(:fee, properties: {
        "from_datetime" => "2021-01-01T00:00:00Z",
        "to_datetime" => "2021-01-31T23:59:59Z"
      })
    end

    before do
      described_class.destroy_all
      fee1
      fee2
      fee3
      fee4
    end

    it "returns fees in right order" do
      expect(described_class.ordered_by_period).to eq([fee4, fee3, fee1, fee2])
    end
  end

  describe "#item_code" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns related subscription code" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_code)
          .to eq(subscription.plan.code)
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns related billable metric code" do
        expect(described_class.new(charge:, fee_type: "charge").item_code)
          .to eq(charge.billable_metric.code)
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns add on code" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_code)
          .to eq(applied_add_on.add_on.code)
      end
    end

    context "when it is a credit fee" do
      it "returns add on code" do
        expect(described_class.new(fee_type: "credit").item_code).to eq("credit")
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns related billable metric code" do
        expect(described_class.new(charge:, fee_type: "charge").item_code)
          .to eq(charge.billable_metric.code)
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns related fixed charge add on code" do
        expect(fee.item_code).to eq(fee.fixed_charge.add_on.code)
      end
    end
  end

  describe "#invoice_name" do
    subject(:fee_invoice_name) { fee.invoice_name }

    context "when invoice display name is present" do
      let(:fee) { build(:fee) }

      it "returns fee invoice display name" do
        expect(fee_invoice_name).to eq(fee.invoice_display_name)
      end
    end

    context "when invoice display name is blank" do
      let(:invoice_display_name) { [nil, ""].sample }

      context "when it is a subscription fee" do
        let(:fee) { build(:fee, subscription:, fee_type: "subscription", invoice_display_name:) }
        let(:subscription) { create(:subscription) }

        it "returns related subscription name" do
          expect(fee_invoice_name).to eq(subscription.plan.invoice_name)
        end
      end

      context "when it is a commitment fee" do
        let(:fee) { build(:minimum_commitment_fee, invoice_display_name:) }

        it "returns related subscription name" do
          expect(fee_invoice_name).to eq(fee.subscription.plan.invoice_name)
        end
      end

      context "when it is a charge fee" do
        let(:fee) { build(:fee, charge:, fee_type: "charge", invoice_display_name:) }
        let(:charge) { create(:standard_charge, invoice_display_name: charge_invoice_display_name) }

        context "when charge has invoice display name present" do
          let(:charge_invoice_display_name) { Faker::Fantasy::Tolkien.location }

          it "returns charge invoice display name" do
            expect(fee_invoice_name).to eq(charge.invoice_display_name)
          end
        end

        context "when charge has invoice display name blank" do
          let(:charge_invoice_display_name) { [nil, ""].sample }

          it "returns related billable metric name" do
            expect(fee_invoice_name).to eq(charge.billable_metric.name)
          end
        end
      end

      context "when it is a fixed charge fee" do
        let(:fee) { build(:fixed_charge_fee, invoice_display_name:, fixed_charge:) }

        context "when fixed charge has invoice display name present" do
          let(:fixed_charge) { create(:fixed_charge, invoice_display_name: Faker::Fantasy::Tolkien.location) }

          it "returns related fixed charge add on code" do
            expect(fee_invoice_name).to eq(fee.fixed_charge.invoice_display_name)
          end
        end

        context "when fixed charge has invoice display name blank" do
          let(:fixed_charge) { create(:fixed_charge, invoice_display_name: [nil, ""].sample) }

          it "returns related fixed charge add on invoice name" do
            expect(fee_invoice_name).to eq(fee.fixed_charge.add_on.invoice_name)
          end
        end
      end

      context "when it is a add-on fee" do
        let(:fee) { build(:fee, applied_add_on:, fee_type: "add_on", invoice_display_name:) }
        let(:applied_add_on) { create(:applied_add_on) }

        it "returns add on name" do
          expect(fee_invoice_name).to eq(applied_add_on.add_on.invoice_name)
        end
      end

      context "when it is a credit fee" do
        let(:wallet) { create(:wallet, name: "My Wallet") }
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, name:) }
        let(:name) { "Custom Transaction" }
        let(:fee) { build(:fee, fee_type: "credit", invoice_display_name:, invoiceable: wallet_transaction) }

        context "when wallet transaction has a name" do
          it "returns the wallet transaction name" do
            expect(fee_invoice_name).to eq("Custom Transaction")
          end
        end

        context "when wallet transaction has no name" do
          let(:name) { nil }

          it "returns 'credit'" do
            expect(fee_invoice_name).to eq("credit")
          end
        end

        context "when invoiceable is nil" do
          let(:fee) { build(:fee, fee_type: "credit", invoice_display_name:, invoiceable: nil) }

          it "returns 'credit'" do
            expect(fee_invoice_name).to eq("credit")
          end
        end
      end

      context "when it is an pay_in_advance charge fee" do
        let(:fee) { build(:fee, charge:, fee_type: "charge", invoice_display_name:) }
        let(:charge) { create(:standard_charge, :pay_in_advance, invoice_display_name: charge_invoice_display_name) }

        context "when charge has invoice display name present" do
          let(:charge_invoice_display_name) { Faker::Fantasy::Tolkien.location }

          it "returns charge invoice display name" do
            expect(fee_invoice_name).to eq(charge.invoice_display_name)
          end
        end

        context "when charge has invoice display name blank" do
          let(:charge_invoice_display_name) { [nil, ""].sample }

          it "returns related billable metric name" do
            expect(fee_invoice_name).to eq(charge.billable_metric.name)
          end
        end
      end
    end
  end

  describe "#item_name" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns related subscription name" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_name)
          .to eq(subscription.plan.name)
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns related billable metric name" do
        expect(described_class.new(charge:, fee_type: "charge").item_name)
          .to eq(charge.billable_metric.name)
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns related fixed charge add on name" do
        expect(fee.item_name).to eq(fee.fixed_charge.add_on.name)
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns add on name" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_name)
          .to eq(applied_add_on.add_on.name)
      end
    end

    context "when it is a credit fee" do
      let(:wallet) { create(:wallet, name: "My Wallet") }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, name:) }
      let(:name) { "Custom Transaction" }
      let(:fee) { described_class.new(fee_type: "credit", invoiceable: wallet_transaction) }

      context "when wallet transaction has a name" do
        it "returns the wallet transaction name" do
          expect(fee.item_name).to eq("Custom Transaction")
        end
      end

      context "when wallet transaction has no name" do
        let(:name) { nil }

        it "returns 'credit'" do
          expect(fee.item_name).to eq("credit")
        end
      end

      context "when invoiceable is nil" do
        let(:fee) { described_class.new(fee_type: "credit", invoiceable: nil) }

        it "returns 'credit'" do
          expect(fee.item_name).to eq("credit")
        end
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns related billable metric name" do
        expect(described_class.new(charge:, fee_type: "charge").item_name)
          .to eq(charge.billable_metric.name)
      end
    end
  end

  describe "#item_description" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns related subscription description" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_description)
          .to eq(subscription.plan.description)
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns related billable metric description" do
        expect(described_class.new(charge:, fee_type: "charge").item_description)
          .to eq(charge.billable_metric.description)
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns related fixed charge add on description" do
        expect(fee.item_description).to eq(fee.fixed_charge.add_on.description)
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns add on description" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_description)
          .to eq(applied_add_on.add_on.description)
      end
    end

    context "when it is a credit fee" do
      it "returns 'credit'" do
        expect(described_class.new(fee_type: "credit").item_description).to eq("credit")
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns related billable metric description" do
        expect(described_class.new(charge:, fee_type: "charge").item_description)
          .to eq(charge.billable_metric.description)
      end
    end
  end

  describe "#item_type" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns subscription" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_type)
          .to eq("Subscription")
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns billable metric" do
        expect(described_class.new(charge:, fee_type: "charge").item_type)
          .to eq("BillableMetric")
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns fixed charge" do
        expect(fee.item_type).to eq("AddOn")
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns add on" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_type)
          .to eq("AddOn")
      end
    end

    context "when it is a credit fee" do
      it "returns wallet transaction" do
        expect(described_class.new(fee_type: "credit").item_type).to eq("WalletTransaction")
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns billable metric" do
        expect(described_class.new(charge:, fee_type: "charge").item_type)
          .to eq("BillableMetric")
      end
    end
  end

  describe "#item_source" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns subscription" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_source)
          .to eq(subscription.plan.code)
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns billable metric" do
        expect(described_class.new(charge:, fee_type: "charge").item_source)
          .to eq(charge.billable_metric.code)
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns fixed charge" do
        expect(fee.item_source).to eq(fee.fixed_charge.add_on.code)
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns add on" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_source)
          .to eq(applied_add_on.add_on.code)
      end
    end

    context "when it is a credit fee" do
      it "returns wallet transaction" do
        expect(described_class.new(fee_type: "credit").item_source).to eq("consumed_credits")
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns billable metric" do
        expect(described_class.new(charge:, fee_type: "charge").item_source)
          .to eq(charge.billable_metric.code)
      end
    end
  end

  describe "#item_id" do
    context "when it is a subscription fee" do
      let(:subscription) { create(:subscription) }

      it "returns the subscription id" do
        expect(described_class.new(subscription:, fee_type: "subscription").item_id)
          .to eq(subscription.id)
      end
    end

    context "when it is a charge fee" do
      let(:charge) { create(:standard_charge) }

      it "returns the billable metric id" do
        expect(described_class.new(charge:, fee_type: "charge").item_id)
          .to eq(charge.billable_metric.id)
      end
    end

    context "when it is a fixed charge fee" do
      let(:fee) { create(:fixed_charge_fee) }

      it "returns the fixed charge add on id" do
        expect(fee.item_id).to eq(fee.fixed_charge.add_on.id)
      end
    end

    context "when it is a add-on fee" do
      let(:applied_add_on) { create(:applied_add_on) }

      it "returns the add on id" do
        expect(described_class.new(applied_add_on:, fee_type: "add_on").item_id)
          .to eq(applied_add_on.add_on_id)
      end
    end

    context "when it is a credit fee" do
      let(:wallet_transaction) { create(:wallet_transaction) }

      it "returns the wallet transaction id" do
        expect(described_class.new(fee_type: "credit", invoiceable: wallet_transaction).item_id)
          .to eq(wallet_transaction.id)
      end
    end

    context "when it is an pay_in_advance charge fee" do
      let(:charge) { create(:standard_charge, :pay_in_advance) }

      it "returns the billable metric id" do
        expect(described_class.new(charge:, fee_type: "charge").item_id)
          .to eq(charge.billable_metric.id)
      end
    end
  end

  describe "#total_amount_cents" do
    let(:fee) { create(:fee, amount_cents: 100, taxes_amount_cents: 20) }

    it "returns the sum of amount and taxes" do
      expect(fee.total_amount_cents).to eq(120)
    end
  end

  describe "#total_amount_currency" do
    let(:fee) { create(:fee, amount_currency: "EUR") }

    it { expect(fee.total_amount_currency).to eq("EUR") }
  end

  describe "#precise_total_amount_cents" do
    subject(:method_call) { fee.precise_total_amount_cents }

    let(:fee) { create(:fee, precise_amount_cents: 200.0000000123, taxes_precise_amount_cents: 20.00000000012) }

    it "returns sum of precise amount cents and taxes precise amount cents" do
      expect(subject).to eq(220.00000001242)
    end
  end

  describe "#sub_total_excluding_taxes_precise_amount_cents" do
    subject(:method_call) { fee.sub_total_excluding_taxes_precise_amount_cents }

    let(:fee) { create(:fee, precise_amount_cents: 200.00456000123, precise_coupons_amount_cents: 150.00123) }

    it "returns sub total minus coupons amount cents" do
      expect(subject).to eq(50.00333000123)
    end
  end

  describe "#invoice_sorting_clause" do
    let(:charge) { create(:standard_charge, properties:) }
    let(:fee) { described_class.new(charge:, fee_type: "charge", grouped_by:) }
    let(:grouped_by) do
      {
        "key_1" => "mercredi",
        "key_2" => "week_01",
        "key_3" => "2024"
      }
    end
    let(:properties) do
      {
        "amount" => "5",
        "grouped_by" => %w[key_1 key_2 key_3]
      }
    end

    context "when it is standard charge fee with grouped_by property" do
      it "returns valid response" do
        expect(fee.invoice_sorting_clause)
          .to eq("#{fee.invoice_name} #{fee.grouped_by.values.join} #{fee.filter_display_name}".downcase)
      end
    end

    context "when missing grouped_by property" do
      let(:properties) do
        {
          "amount" => "5"
        }
      end

      it "returns valid response" do
        expect(fee.invoice_sorting_clause).to eq("#{fee.invoice_name} #{fee.grouped_by.values.join} #{fee.filter_display_name}".downcase)
      end
    end
  end

  describe "#grouped_by_display" do
    let(:charge) { create(:standard_charge, properties:) }
    let(:fee) { described_class.new(charge:, fee_type: "charge", grouped_by:) }
    let(:grouped_by) do
      {
        "key_1" => "mercredi",
        "key_2" => "week_01",
        "key_3" => "2024"
      }
    end
    let(:properties) do
      {
        "amount" => "5",
        "grouped_by" => %w[key_1 key_2 key_3]
      }
    end

    context "when a standard charge fee has grouped_by values" do
      it "formats the grouped_by values with bullet points" do
        expect(fee.grouped_by_display).to eq(" • mercredi • week_01 • 2024")
      end
    end

    context "when the charge properties are missing the grouped_by property" do
      let(:properties) do
        {
          "amount" => "5"
        }
      end

      it "formats the grouped_by values with bullet points" do
        expect(fee.grouped_by_display).to eq(" • mercredi • week_01 • 2024")
      end
    end

    context "when some grouped_by values are nil" do
      let(:grouped_by) do
        {
          "key_1" => nil,
          "key_2" => "week_01",
          "key_3" => "2024"
        }
      end

      it "skips nil values and formats only the present values" do
        expect(fee.grouped_by_display).to eq(" • week_01 • 2024")
      end
    end

    context "when grouped_by values are all blank" do
      let(:grouped_by) { {"key_1" => nil} }

      it "returns an empty string" do
        expect(fee.grouped_by_display).to eq("")
      end
    end

    context "when the fee is not a charge" do
      let(:fee) { described_class.new(fee_type: "subscription", grouped_by:) }

      it "returns an empty string" do
        expect(fee.grouped_by_display).to eq("")
      end
    end
  end

  describe "#non_zero?" do
    subject { fee.non_zero? }

    let(:fee) { build(:fee, units:, amount_cents:, events_count:) }
    let(:units) { 0 }
    let(:amount_cents) { 0 }
    let(:events_count) { 0 }

    context "when units, amount_cents and events_count are all zero" do
      it { is_expected.to be false }
    end

    context "when only units are positive" do
      let(:units) { 5 }

      it { is_expected.to be true }
    end

    context "when only amount_cents are positive" do
      let(:amount_cents) { 100 }

      it { is_expected.to be true }
    end

    context "when only events_count is positive" do
      let(:events_count) { 3 }

      it { is_expected.to be true }
    end

    context "when events_count is nil" do
      let(:events_count) { nil }

      it { is_expected.to be false }
    end
  end

  describe "#taxable?" do
    subject { fee.taxable? }

    let(:fee) { build(:fee, units:, amount_cents:, events_count:) }
    let(:units) { 0 }
    let(:amount_cents) { 0 }
    let(:events_count) { 0 }

    context "when amount_cents is positive" do
      let(:amount_cents) { 100 }

      it { is_expected.to be true }
    end

    context "when amount_cents is zero" do
      it { is_expected.to be false }
    end

    context "when amount_cents is zero but units and events_count are positive" do
      let(:units) { 5 }
      let(:events_count) { 3 }

      it { is_expected.to be false }
    end
  end

  describe "#has_charge_filter?" do
    subject(:fee) { create(:add_on_fee) }

    it { expect(fee).not_to be_has_charge_filters }

    context "when fee is a charge fee" do
      subject(:fee) { create(:charge_fee) }

      it { expect(fee).not_to be_has_charge_filters }

      context "when charge has filters" do
        let(:charge_filter) { create(:charge_filter, charge: fee.charge) }

        before { charge_filter }

        it { expect(fee).to be_has_charge_filters }
      end
    end
  end

  describe "#compute_precise_credit_amount_cents" do
    subject { fee.compute_precise_credit_amount_cents(credit_amount, base_amount_cents) }

    let(:fee) { create(:add_on_fee, amount_cents: 500, precise_coupons_amount_cents: 100) }
    let(:credit_amount) { 10 }

    context "when base amount cents is non-zero" do
      let(:base_amount_cents) { 5 }

      it "returns correct value" do
        expect(subject).to eq(800)
      end
    end

    context "when base amount cents is zero" do
      let(:base_amount_cents) { 0 }

      it "returns zero" do
        expect(subject).to eq(0)
      end
    end
  end

  describe "#creditable_amount_cents" do
    subject { fee.creditable_amount_cents }

    let(:amount_cents) { 1000 }

    context "when fee_type is subscription" do
      let(:fee) { create(:fee, fee_type: :subscription, amount_cents:) }

      it "returns the remaining amount" do
        expect(subject).to eq(1000)
      end
    end

    context "when fee_type is credit" do
      let(:wallet) { create(:wallet, balance_cents: 500, customer: invoice.customer) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: 500) }
      let(:invoice) { create(:invoice, invoice_type: :credit) }
      let(:fee) { create(:fee, fee_type: :credit, amount_cents:, invoice:, invoiceable: wallet_transaction) }

      it "returns the remaining amount of the inbound transaction" do
        expect(subject).to eq(500)
      end

      context "when remaining amount exceeds fee remaining amount" do
        let(:wallet) { create(:wallet, balance_cents: 1500, customer: invoice.customer) }
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: 1500) }

        it "returns the fee remaining amount" do
          expect(subject).to eq(1000)
        end
      end

      context "when credit note items reduce remaining amount" do
        let(:wallet) { create(:wallet, balance_cents: 1500, customer: invoice.customer) }
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: 1500) }

        before { create(:credit_note_item, fee:, amount_cents: 300) }

        it "returns the reduced remaining amount" do
          expect(subject).to eq(700)
        end
      end
    end
  end

  describe "#creditable_from_wallet_amount_cents" do
    subject { fee.creditable_from_wallet_amount_cents }

    context "when fee is not credit" do
      let(:fee) { create(:fee, fee_type: :subscription) }

      it "returns 0" do
        expect(subject).to eq(0)
      end
    end

    context "when fee is credit" do
      let(:wallet) { create(:wallet, balance_cents: 2000, customer: invoice.customer) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: 500) }
      let(:invoice) { create(:invoice, invoice_type: :credit) }
      let(:fee) { create(:fee, fee_type: :credit, amount_cents: 1000, invoice:, invoiceable: wallet_transaction) }

      it "returns the remaining amount of the inbound transaction" do
        expect(subject).to eq(500)
      end

      context "when wallet is terminated" do
        let(:wallet) { create(:wallet, balance_cents: 500, status: :terminated, customer: invoice.customer) }

        it "returns 0" do
          expect(subject).to eq(0)
        end
      end

      context "when remaining_amount_cents is nil" do
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: nil) }

        it "returns 0" do
          expect(subject).to eq(0)
        end
      end

      context "when wallet is not traceable" do
        let(:wallet) { create(:wallet, balance_cents: 500, customer: invoice.customer, traceable: false) }
        let(:wallet_transaction) { create(:wallet_transaction, wallet:) }

        it "returns the wallet balance" do
          expect(subject).to eq(500)
        end
      end

      context "when invoiceable is nil (historical fee)" do
        let(:invoice) { create(:invoice, invoice_type: :credit) }
        let(:fee) { create(:fee, fee_type: :credit, amount_cents: 1000, invoice:, invoiceable: nil) }

        it "returns 0" do
          expect(subject).to eq(0)
        end
      end
    end
  end

  describe "#prepaid_credit_fee_wallet" do
    subject { fee.prepaid_credit_fee_wallet }

    context "when fee is not credit" do
      let(:fee) { create(:fee, fee_type: :subscription) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when fee is credit" do
      let(:wallet) { create(:wallet, customer: invoice.customer) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:) }
      let(:invoice) { create(:invoice, invoice_type: :credit) }
      let(:fee) { create(:fee, fee_type: :credit, invoice:, invoiceable: wallet_transaction) }

      it "returns the wallet" do
        expect(subject).to eq(wallet)
      end

      context "when invoiceable is nil (historical fee)" do
        let(:fee) { create(:fee, fee_type: :credit, invoice:, invoiceable: nil) }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe "#offsettable_amount_cents" do
    subject { fee.offsettable_amount_cents }

    let(:fee) { create(:fee, fee_type:, amount_cents: 1000, invoice:) }

    context "with credit invoices" do
      let(:fee_type) { "credit" }

      context "when payment is pending" do
        let(:invoice) { create(:invoice, invoice_type: :credit, payment_status: :pending) }

        it "returns full amount" do
          expect(subject).to eq(1000)
        end
      end

      context "when payment succeeded" do
        let(:invoice) { create(:invoice, invoice_type: :credit, payment_status: :succeeded) }
        let(:wallet) { create(:wallet, balance_cents: 500, customer: invoice.customer) }

        before { fee.update(invoiceable: create(:wallet_transaction, wallet:, remaining_amount_cents: 500)) }

        it "returns the remaining amount of the inbound transaction" do
          expect(subject).to eq(500)
        end
      end

      context "when payment failed" do
        let(:invoice) { create(:invoice, invoice_type: :credit, payment_status: :failed) }

        it "returns full amount" do
          expect(subject).to eq(1000)
        end
      end
    end

    context "with regular invoices" do
      let(:invoice) { create(:invoice, invoice_type: :subscription) }
      let(:fee_type) { "subscription" }

      it "returns full amount when no credit notes" do
        expect(subject).to eq(1000)
      end

      it "deducts credit note items from amount" do
        create(:credit_note_item, fee:, amount_cents: 300)
        expect(subject).to eq(700) # 1000 - 300
      end

      it "deducts multiple credit note items" do
        create(:credit_note_item, fee:, amount_cents: 200)
        create(:credit_note_item, fee:, amount_cents: 150)
        expect(subject).to eq(650) # 1000 - 200 - 150
      end
    end
  end

  describe "#grouped_or_filtered?" do
    it "returns false when grouped_by is blank and charge_filter_id is nil" do
      fee = build(:charge_fee, grouped_by: {}, charge_filter_id: nil)
      expect(fee).not_to be_grouped_or_filtered
    end

    it "returns true when grouped_by is present" do
      fee = build(:charge_fee, grouped_by: {"cloud" => "aws"})
      expect(fee).to be_grouped_or_filtered
    end

    it "returns true when charge_filter_id is present" do
      fee = build(:charge_fee, grouped_by: {}, charge_filter_id: SecureRandom.uuid)
      expect(fee).to be_grouped_or_filtered
    end
  end

  describe "#ungrouped_or_filtered?" do
    it "returns false when grouped_by is present and charge_filter_id is nil" do
      fee = build(:charge_fee, grouped_by: {"cloud" => "aws"}, charge_filter_id: nil)
      expect(fee).not_to be_ungrouped_or_filtered
    end

    it "returns true when grouped_by is blank" do
      fee = build(:charge_fee, grouped_by: {}, charge_filter_id: nil)
      expect(fee).to be_ungrouped_or_filtered
    end

    it "returns true when charge_filter_id is present" do
      fee = build(:charge_fee, grouped_by: {"cloud" => "aws"}, charge_filter_id: SecureRandom.uuid)
      expect(fee).to be_ungrouped_or_filtered
    end
  end

  describe "#basic_rate_percentage?" do
    let(:fee) { create(:fee, fee_type: :charge, charge:, amount_cents: 1000, total_aggregated_units: 1) }
    let(:charge) { create(:standard_charge) }

    it "returns false if charge model is not percentage" do
      expect(fee).not_to be_basic_rate_percentage
    end

    context "when charge model is percentage but has other properties except rate" do
      let(:charge) { create(:charge, charge_model: "percentage", properties: {rate: "0", fixed_amount: "20"}) }

      it "returns false" do
        expect(fee).not_to be_basic_rate_percentage
      end
    end

    context "when properties of percentage charge contain only rate" do
      let(:charge) { create(:charge, charge_model: "percentage", properties: {rate: "0"}) }

      it "returns true" do
        expect(fee).to be_basic_rate_percentage
      end
    end

    context "when charge is percentage and there are charge filters" do
      let(:charge) { create(:charge, charge_model: "percentage", properties: {rate: "0"}) }

      before { fee.update!(charge_filter:) }

      context "when filter has other properties except rate" do
        let(:charge_filter) { create(:charge_filter, charge:, properties: {rate: "0", fixed_amount: "20"}) }

        it "returns false" do
          expect(fee).not_to be_basic_rate_percentage
        end
      end

      context "when filter properties contain only rate" do
        let(:charge_filter) { create(:charge_filter, charge:, properties: {rate: "0"}) }

        it "returns true" do
          expect(fee).to be_basic_rate_percentage
        end
      end
    end
  end
end
