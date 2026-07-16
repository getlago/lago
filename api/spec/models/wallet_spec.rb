# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallet do
  subject(:wallet) { build(:wallet) }

  it_behaves_like "paper_trail traceable"

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:customer)
      expect(subject).to belong_to(:billing_entity).optional
      expect(subject).to have_many(:applied_invoice_custom_sections).class_name("Wallet::AppliedInvoiceCustomSection").dependent(:destroy)
      expect(subject).to have_many(:selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section)
      expect(subject).to have_one(:metadata).class_name("Metadata::ItemMetadata").dependent(:destroy)
      expect(subject).to have_many(:alerts).class_name("UsageMonitoring::Alert")
      expect(subject).to have_many(:triggered_alerts).class_name("UsageMonitoring::TriggeredAlert")
    end
  end

  describe "Clickhouse associations", clickhouse: true do
    it { is_expected.to have_many(:activity_logs).class_name("Clickhouse::ActivityLog") }
  end

  describe "#billing_entity" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    context "when wallet has a billing_entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:wallet) { create(:wallet, customer:, billing_entity:) }

      it "returns the wallet billing_entity" do
        expect(wallet.billing_entity).to eq(billing_entity)
      end
    end

    context "when wallet does not have a billing_entity" do
      let(:wallet) { create(:wallet, customer:, billing_entity: nil) }

      it "falls back to the customer billing_entity" do
        expect(wallet.billing_entity).to eq(customer.billing_entity)
      end
    end
  end

  describe ".with_positive_balance" do
    subject { described_class.with_positive_balance }

    let(:scoped) { create(:wallet, balance_cents: rand(1..1000)) }

    before do
      create(:wallet, balance_cents: 0)
      create(:wallet, balance_cents: -rand(1..1000), traceable: false)
    end

    it "returns wallets with positive balance cents" do
      expect(subject).to contain_exactly(scoped)
    end
  end

  describe ".in_application_order" do
    subject { described_class.in_application_order }

    let!(:wallet_10_newer) { create(:wallet, priority: 10, created_at: 1.day.ago) }
    let!(:wallet_5) { create(:wallet, priority: 5, created_at: 1.second.ago) }
    let!(:wallet_10_older) { create(:wallet, priority: 10, created_at: 3.days.ago) }
    let!(:wallet_50) { create(:wallet, created_at: 2.seconds.ago) }

    it "orders by priority first then by created_at" do
      expect(subject.to_a).to eq([
        wallet_5,
        wallet_10_older,
        wallet_10_newer,
        wallet_50
      ])
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:rate_amount).is_greater_than(0) }
    it { is_expected.to validate_inclusion_of(:currency).in_array(described_class.currency_list) }
    it { is_expected.to validate_exclusion_of(:invoice_requires_successful_payment).in_array([nil]) }
    it { is_expected.to validate_numericality_of(:paid_top_up_min_amount_cents).is_greater_than(0).allow_nil }
    it { is_expected.to validate_numericality_of(:paid_top_up_max_amount_cents).is_greater_than(0).allow_nil }
    it { is_expected.to validate_inclusion_of(:priority).in_range(1..50) }

    it "validates than max is greater than min" do
      subject.paid_top_up_min_amount_cents = 100
      subject.paid_top_up_max_amount_cents = 1

      expect(subject).not_to be_valid
      expect(subject.errors["paid_top_up_max_amount_cents"]).to eq ["must_be_greater_than_or_equal_min"]

      subject.paid_top_up_max_amount_cents = subject.paid_top_up_min_amount_cents
      expect(subject).to be_valid
      expect(subject.errors).to be_empty
    end

    it "validates uniqueness of code per customer" do
      customer = create(:customer)
      existing_wallet = create(:wallet, customer:, code: "unique_code")

      subject.customer = customer
      subject.code = existing_wallet.code

      expect(subject).not_to be_valid
      expect(subject.errors["code"]).to eq ["value_already_exist"]

      # Same code with different customer should be valid
      other_customer = create(:customer, organization: customer.organization)
      subject.customer = other_customer
      expect(subject).to be_valid
      expect(subject.errors).to be_empty
    end

    describe "of balance cents" do
      let(:wallet) { build(:wallet, balance_cents:, traceable:) }
      let(:error) { wallet.errors.where(:balance_cents, :greater_than_or_equal_to) }

      before { wallet.valid? }

      context "when wallet is traceable" do
        let(:traceable) { true }

        context "when balance_cents is negative" do
          let(:balance_cents) { rand(1..1000) * -1 }

          it "adds an error" do
            expect(error).to be_present
          end
        end

        context "when balance_cents is zero" do
          let(:balance_cents) { 0 }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end

        context "when balance_cents is positive" do
          let(:balance_cents) { rand(1..1000) }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end

      context "when wallet is not traceable" do
        let(:traceable) { false }

        context "when balance_cents is negative" do
          let(:balance_cents) { rand(1..1000) * -1 }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end

        context "when balance_cents is zero" do
          let(:balance_cents) { 0 }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end

        context "when balance_cents is positive" do
          let(:balance_cents) { rand(1..1000) }

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end
    end
  end

  describe "currency=" do
    it "assigns the currency to all amounts" do
      wallet.currency = "CAD"

      expect(wallet).to have_attributes(
        balance_currency: "CAD",
        consumed_amount_currency: "CAD"
      )
    end
  end

  describe "currency" do
    it "returns the wallet currency" do
      expect(wallet.currency).to eq(wallet.balance_currency)
    end
  end

  describe "limited_fee_types?" do
    context "when allowed_fee_types is present" do
      before { wallet.allowed_fee_types = %w[charge] }

      it "returns true" do
        expect(wallet.limited_fee_types?).to be true
      end
    end

    context "when allowed_fee_types is empty" do
      before { wallet.allowed_fee_types = [] }

      it "returns false" do
        expect(wallet.limited_fee_types?).to be false
      end
    end
  end

  describe "limited_to_billable_metrics?" do
    context "when wallet_targets are present" do
      before { create(:wallet_target, wallet:) }

      it "returns true" do
        expect(wallet.limited_to_billable_metrics?).to be true
      end
    end

    context "when wallet targets are not present" do
      it "returns false" do
        expect(wallet.limited_to_billable_metrics?).to be false
      end
    end
  end

  describe "#paid_top_up_min_credits" do
    it "converts min amount cents to credits using the wallet rate" do
      wallet.rate_amount = 25
      wallet.paid_top_up_min_amount_cents = 1_00
      expect(wallet.paid_top_up_min_credits).to eq(0.04)

      wallet.paid_top_up_min_amount_cents = nil
      expect(wallet.paid_top_up_min_credits).to be_nil
    end
  end

  describe "#paid_top_up_max_credits" do
    it "converts max amount cents to credits using the wallet rate" do
      wallet.paid_top_up_max_amount_cents = 5_00
      expect(wallet.paid_top_up_max_credits).to eq(5.0)

      wallet.paid_top_up_max_amount_cents = nil
      expect(wallet.paid_top_up_max_credits).to be_nil
    end
  end

  describe "REFRESH_RELEVANT_ATTRIBUTES" do
    # If this list changes, you MUST decide whether the new/removed column
    # should trigger Customers::RefreshWalletsService and update
    # Wallet::REFRESH_RELEVANT_ATTRIBUTES accordingly.
    non_refresh_relevant_attributes = %w[
      id
      balance_cents
      balance_currency
      consumed_amount_cents
      consumed_amount_currency
      consumed_credits
      credits_balance
      credits_ongoing_balance
      credits_ongoing_usage_balance
      depleted_ongoing_balance
      expiration_at
      invoice_requires_successful_payment
      last_balance_sync_at
      last_consumed_credit_at
      last_ongoing_balance_sync_at
      lock_version
      name
      ongoing_balance_cents
      ongoing_usage_balance_cents
      paid_top_up_max_amount_cents
      paid_top_up_min_amount_cents
      payment_method_type
      rate_amount
      ready_to_be_refreshed
      skip_invoice_custom_sections
      status
      terminated_at
      traceable
      created_at
      updated_at
      billing_entity_id
      customer_id
      organization_id
      payment_method_id
    ].freeze

    it "covers every column that does not need to trigger a refresh" do
      expect(described_class.column_names - described_class::REFRESH_RELEVANT_ATTRIBUTES)
        .to match_array(non_refresh_relevant_attributes)
    end
  end
end
