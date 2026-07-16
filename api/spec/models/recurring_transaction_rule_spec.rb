# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringTransactionRule do
  describe "associations" do
    it { is_expected.to belong_to(:wallet) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:applied_invoice_custom_sections).class_name("RecurringTransactionRule::AppliedInvoiceCustomSection").dependent(:destroy) }
    it { is_expected.to have_many(:selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section) }
  end

  describe "enums" do
    it "defines expected enum values" do
      expect(described_class.defined_enums).to include(
        "interval" => hash_including("weekly", "monthly", "quarterly", "yearly", "semiannual"),
        "method" => hash_including("fixed", "target"),
        "trigger" => hash_including("interval", "threshold"),
        "status" => hash_including("active", "terminated")
      )
    end
  end

  describe "validations" do
    it { is_expected.to validate_length_of(:transaction_name).is_at_least(1).is_at_most(255).allow_nil }

    describe "grants_target_top_up validation" do
      context "when method is target" do
        it "accepts nil so legacy rows created before the column stay valid" do
          rule = build(:recurring_transaction_rule, method: :target)
          rule.grants_target_top_up = nil
          expect(rule).to be_valid
        end

        it "accepts true" do
          rule = build(:recurring_transaction_rule, method: :target, grants_target_top_up: true)
          expect(rule).to be_valid
        end

        it "accepts false" do
          rule = build(:recurring_transaction_rule, method: :target, grants_target_top_up: false)
          expect(rule).to be_valid
        end
      end

      context "when method is not target" do
        it "rejects true" do
          rule = build(:recurring_transaction_rule, method: :fixed, grants_target_top_up: true)
          expect(rule).not_to be_valid
          expect(rule.errors[:grants_target_top_up]).to be_present
        end

        it "rejects false" do
          rule = build(:recurring_transaction_rule, method: :fixed, grants_target_top_up: false)
          expect(rule).not_to be_valid
          expect(rule.errors[:grants_target_top_up]).to be_present
        end

        it "accepts nil" do
          rule = build(:recurring_transaction_rule, method: :fixed)
          expect(rule).to be_valid
        end
      end
    end

    describe "target_ongoing_balance validation" do
      context "when method is target and trigger is threshold" do
        it "rejects a target below the threshold" do
          rule = build(:recurring_transaction_rule, method: :target, trigger: :threshold, target_ongoing_balance: 50, threshold_credits: 100)
          expect(rule).not_to be_valid
          expect(rule.errors[:target_ongoing_balance]).to be_present
        end

        it "accepts a target equal to the threshold" do
          rule = build(:recurring_transaction_rule, method: :target, trigger: :threshold, target_ongoing_balance: 100, threshold_credits: 100)
          expect(rule).to be_valid
        end

        it "accepts a target above the threshold" do
          rule = build(:recurring_transaction_rule, method: :target, trigger: :threshold, target_ongoing_balance: 150, threshold_credits: 100)
          expect(rule).to be_valid
        end

        it "does not block saving a legacy invalid record when the relevant fields are unchanged" do
          rule = build(:recurring_transaction_rule, method: :target, trigger: :threshold, target_ongoing_balance: 50, threshold_credits: 100)
          rule.save!(validate: false)

          expect { rule.mark_as_terminated! }.not_to raise_error
          expect(rule.reload).to be_terminated
        end
      end

      context "when trigger is interval" do
        it "ignores the threshold comparison" do
          rule = build(:recurring_transaction_rule, method: :target, trigger: :interval, target_ongoing_balance: 50, threshold_credits: 100)
          expect(rule).to be_valid
        end
      end
    end
  end

  describe "scopes" do
    let!(:active_rule) { create(:recurring_transaction_rule, status: :active, expiration_at: nil) }
    let!(:future_rule) { create(:recurring_transaction_rule, status: :active, expiration_at: 1.day.from_now) }
    let!(:expired_rule) { create(:recurring_transaction_rule, status: :active, expiration_at: 1.day.ago) }
    let!(:terminated_rule) { create(:recurring_transaction_rule, status: :terminated, expiration_at: 1.day.ago) }

    it "returns correct records for active, eligible_for_termination, and expired scopes" do
      expect(described_class.active).to match_array([active_rule, future_rule])
      expect(described_class.eligible_for_termination).to match_array([expired_rule])
      expect(described_class.expired).to match_array([expired_rule, terminated_rule])
    end
  end

  describe "#currently_active?" do
    it "returns true for active rules with no expiration" do
      rule = build_stubbed(:recurring_transaction_rule, status: :active, expiration_at: nil)
      expect(rule.currently_active?).to be true
    end

    it "returns true for active rules expiring in the future" do
      rule = build_stubbed(:recurring_transaction_rule, status: :active, expiration_at: 1.day.from_now)
      expect(rule.currently_active?).to be true
    end

    it "returns false for active rules whose expiration has passed" do
      rule = build_stubbed(:recurring_transaction_rule, status: :active, expiration_at: 1.day.ago)
      expect(rule.currently_active?).to be false
    end

    it "returns false for terminated rules" do
      rule = build_stubbed(:recurring_transaction_rule, status: :terminated, expiration_at: nil)
      expect(rule.currently_active?).to be false
    end
  end

  describe "#mark_as_terminated!" do
    let(:recurring_transaction_rule) { create(:recurring_transaction_rule, status: :active) }

    it "marks the rule as terminated" do
      expect { recurring_transaction_rule.mark_as_terminated! }
        .to change(recurring_transaction_rule, :status)
        .from("active").to("terminated")
    end

    context "when the rule is a legacy target rule with a nil grants_target_top_up" do
      let(:recurring_transaction_rule) do
        create(:recurring_transaction_rule, method: :target, status: :active).tap do |r|
          r.update_column(:grants_target_top_up, nil) # rubocop:disable Rails/SkipsModelValidations
        end
      end

      it "terminates without raising on the nil value" do
        expect { recurring_transaction_rule.mark_as_terminated! }
          .to change(recurring_transaction_rule, :status)
          .from("active").to("terminated")
      end
    end
  end

  describe "#apply_min_top_up_limits" do
    subject { rule.apply_min_top_up_limits(credit_amount:) }

    let(:rule) { create(:recurring_transaction_rule, wallet:, ignore_paid_top_up_limits:) }
    let(:wallet) { create(:wallet, paid_top_up_min_amount_cents: 10_00, paid_top_up_max_amount_cents: 20_00) }
    let(:credit_amount) { 5 }

    context "when recurring transaction rule ignores paid top up limits" do
      let(:ignore_paid_top_up_limits) { true }

      it "returns not changed value" do
        expect(subject).to eq credit_amount
      end
    end

    context "when recurring transaction rule does not ignore paid top up limits" do
      let(:ignore_paid_top_up_limits) { false }

      it "returns normalized to wallet limits value" do
        expect(subject).to eq 10
      end

      context "when this is no minimum" do
        let(:wallet) { create(:wallet, paid_top_up_min_amount_cents: nil) }
        let(:credit_amount) { 5 }

        it "returns the credit amounts" do
          expect(subject).to eq 5
        end
      end

      context "when credit amount is lower than wallet min limit" do
        let(:credit_amount) { 5 }

        it "returns wallet minimum" do
          expect(subject).to eq 10
        end
      end

      context "when credit amount is greater than wallet max limit" do
        let(:credit_amount) { 25 }

        it "returns credit amount anyway" do
          expect(subject).to eq 25
        end
      end
    end
  end

  describe "#compute_granted_credits" do
    subject { rule.compute_granted_credits }

    let(:rule) { create(:recurring_transaction_rule, method:) }

    context "when method is fixed" do
      let(:method) { :fixed }

      it "returns granted credits specified on rule" do
        expect(subject).to eq rule.granted_credits
      end
    end

    context "when method is target" do
      let(:method) { :target }

      it "returns zero" do
        expect(subject).to eq 0.0
      end

      context "when grants_target_top_up is nil (legacy row)" do
        let(:rule) do
          create(:recurring_transaction_rule, method: :target).tap do |r|
            r.update_column(:grants_target_top_up, nil) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        it "returns zero, behaving like a paid target rule" do
          expect(subject).to eq 0.0
        end
      end

      context "when grants_target_top_up is true" do
        let(:rule) do
          create(
            :recurring_transaction_rule,
            wallet:,
            method: :target,
            grants_target_top_up: true,
            target_ongoing_balance: 101.0
          )
        end
        let(:wallet) do
          create(:wallet, rate_amount: 0.5, paid_top_up_min_amount_cents: 25_00, credits_ongoing_balance: 100.0)
        end

        it "returns the raw gap, bypassing the paid_top_up_min limit" do
          expect(subject).to eq 1.0
        end

        it "makes the rule grant the gap-fill instead of paying for it" do
          expect(rule.compute_paid_credits(ongoing_balance: 100.0)).to eq 0.0
          expect(rule.compute_granted_credits).to eq 1.0
        end
      end

      context "when grants_target_top_up is true but the balance already exceeds the target" do
        let(:rule) do
          create(:recurring_transaction_rule, wallet:, method: :target, grants_target_top_up: true, target_ongoing_balance: 100.0)
        end
        let(:wallet) { create(:wallet, rate_amount: 0.5, credits_ongoing_balance: 150.0) }

        it "grants nothing rather than a negative amount" do
          expect(subject).to eq 0.0
        end
      end
    end
  end

  describe "#compute_paid_credits" do
    subject { rule.compute_paid_credits(ongoing_balance:) }

    let(:rule) { create(:recurring_transaction_rule, wallet:, method:, target_ongoing_balance:) }
    let(:ongoing_balance) { 100.0 }
    let(:wallet) { create(:wallet, rate_amount: 0.5, paid_top_up_min_amount_cents: 25_00) }

    context "when method is fixed" do
      let(:method) { :fixed }
      let(:target_ongoing_balance) { 100.0 }

      it "returns paid credits specified on rule" do
        expect(subject).to eq rule.paid_credits
      end
    end

    context "when method is target" do
      let(:method) { :target }

      context "when ongoing balance is greater than target balance" do
        let(:target_ongoing_balance) { 99.0 }

        it "returns zero" do
          expect(subject).to eq 0.0
        end
      end

      context "when ongoing balance equals to target balance" do
        let(:target_ongoing_balance) { 100.0 }

        it "returns zero" do
          expect(subject).to eq 0.0
        end
      end

      context "when ongoing balance is smaller than target balance" do
        let(:target_ongoing_balance) { 101.0 }

        it "returns the gag with applied limits from wallet" do
          expect(subject).to eq 50.0 # min amount 25 x 2 because of wallet's rate 0.5
        end
      end

      context "when grants_target_top_up is nil (legacy row)" do
        let(:rule) do
          create(:recurring_transaction_rule, wallet:, method: :target, target_ongoing_balance:).tap do |r|
            r.update_column(:grants_target_top_up, nil) # rubocop:disable Rails/SkipsModelValidations
          end
        end
        let(:target_ongoing_balance) { 101.0 }

        it "returns the limited gap, behaving like a paid target rule" do
          expect(subject).to eq 50.0
        end
      end

      context "when grants_target_top_up is true" do
        let(:rule) do
          create(
            :recurring_transaction_rule,
            wallet:,
            method: :target,
            grants_target_top_up: true,
            target_ongoing_balance:
          )
        end
        let(:target_ongoing_balance) { 101.0 }

        it "returns zero" do
          expect(subject).to eq 0.0
        end
      end
    end
  end
end
