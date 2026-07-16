# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentIntent do
  it { is_expected.to define_enum_for(:status).with_values(described_class::STATUSES) }

  it { is_expected.to belong_to(:invoice) }
  it { is_expected.to belong_to(:organization) }

  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_presence_of(:expires_at) }

  describe "validations" do
    describe "of status uniqueness" do
      subject { payment_intent.valid? }

      let(:payment_intent) { build(:payment_intent, invoice:, status:) }
      let(:invoice) { create(:invoice) }
      let(:error) { payment_intent.errors.where(:status, :taken) }

      context "when status is active" do
        let(:status) { :active }

        before { create(:payment_intent, status:) }

        context "when a record with the same status and invoice exists" do
          before do
            create(:payment_intent, status:, invoice:)
            subject
          end

          it "adds an error" do
            expect(error).to be_present
          end
        end

        context "when no record with the same status and invoice exists" do
          before do
            create(:payment_intent, :expired, invoice:)
            subject
          end

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end

      context "when status is expired" do
        let(:status) { :expired }

        before { create(:payment_intent, status:) }

        context "when a record with the same status and invoice exists" do
          before do
            create(:payment_intent, status:, invoice:)
            subject
          end

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end

        context "when no record with the same status and invoice exists" do
          before do
            create(:payment_intent, invoice:)
            subject
          end

          it "does not add an error" do
            expect(error).not_to be_present
          end
        end
      end
    end
  end

  describe ".non_expired" do
    subject { described_class.non_expired }

    let!(:scoped) { create(:payment_intent) }

    before { create(:payment_intent, :expired) }

    it "returns intents with future expire date" do
      expect(subject).to contain_exactly scoped
    end
  end

  describe ".awaiting_expiration" do
    subject { described_class.awaiting_expiration }

    let!(:scoped) { create(:payment_intent, expires_at: generate(:past_date)) }

    before do
      create(:payment_intent)
      create(:payment_intent, :expired)
    end

    it "returns intents with past expire date and active status" do
      expect(subject).to contain_exactly scoped
    end
  end
end
