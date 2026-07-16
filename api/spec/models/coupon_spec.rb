# frozen_string_literal: true

require "rails_helper"

RSpec.describe Coupon do
  subject(:coupon) { build(:coupon) }

  it_behaves_like "paper_trail traceable"

  describe "Clickhouse associations", clickhouse: true do
    it { is_expected.to have_many(:activity_logs).class_name("Clickhouse::ActivityLog") }
  end

  it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0).allow_nil }

  specify do
    expect(subject)
      .to validate_inclusion_of(:amount_currency)
      .in_array(described_class.currency_list)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_exclusion_of(:reusable).in_array([nil]) }

    describe "of amount cents" do
      subject { coupon }

      let(:coupon) { build_stubbed(:coupon, coupon_type:) }

      context "when coupon type is fixed amount" do
        let(:coupon_type) { :fixed_amount }

        it { is_expected.to validate_presence_of(:amount_cents) }
      end

      context "when coupon type is percentage" do
        let(:coupon_type) { :percentage }

        it { is_expected.not_to validate_presence_of(:amount_cents) }
      end
    end

    describe "of amount currency" do
      subject { coupon }

      let(:coupon) { build_stubbed(:coupon, coupon_type:) }

      context "when coupon type is fixed amount" do
        let(:coupon_type) { :fixed_amount }

        it { is_expected.to validate_presence_of(:amount_currency) }
      end

      context "when coupon type is percentage" do
        let(:coupon_type) { :percentage }

        it { is_expected.not_to validate_presence_of(:amount_currency) }
      end
    end

    describe "of percentage rate" do
      subject { coupon }

      let(:coupon) { build_stubbed(:coupon, coupon_type:) }

      context "when coupon type is fixed amount" do
        let(:coupon_type) { :fixed_amount }

        it { is_expected.not_to validate_presence_of(:percentage_rate) }
      end

      context "when coupon type is percentage" do
        let(:coupon_type) { :percentage }

        it { is_expected.to validate_presence_of(:percentage_rate) }
      end
    end

    describe "of frequency_duration" do
      subject(:coupon) { build(:coupon, frequency:) }

      context "when recurring" do
        let(:frequency) { "recurring" }

        it { is_expected.to validate_presence_of(:frequency_duration).with_message("value_is_mandatory") }
        it { is_expected.to validate_numericality_of(:frequency_duration).is_greater_than(0) }
      end

      context "when once" do
        let(:frequency) { "once" }

        it { is_expected.not_to validate_presence_of(:frequency_duration) }
      end

      context "when forever" do
        let(:frequency) { "forever" }

        it { is_expected.not_to validate_presence_of(:frequency_duration) }
      end
    end
  end

  describe ".mark_as_terminated" do
    it "terminates the coupon" do
      coupon.mark_as_terminated!

      expect(coupon).to be_terminated
      expect(coupon.terminated_at).to be_present
    end
  end
end
