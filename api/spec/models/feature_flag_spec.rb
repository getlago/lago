# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeatureFlag do
  describe ".valid?" do
    it "returns true for a valid flag" do
      expect(described_class.valid?("multiple_payment_methods")).to be(true)
    end

    it "returns true for the multi_entity_billing flag" do
      expect(described_class.valid?("multi_entity_billing")).to be(true)
    end

    it "returns false for an invalid flag" do
      expect(described_class.valid?("invalid_flag")).to be(false)
    end
  end

  describe ".validate!" do
    context "when in production environment" do
      before { allow(Rails.env).to receive(:production?).and_return(true) }

      it "does not raise an error for invalid flags" do
        expect { described_class.validate!("invalid_flag") }.not_to raise_error
      end
    end

    context "when not in production environment" do
      before { allow(Rails.env).to receive(:production?).and_return(false) }

      it "does not raise an error for valid flags" do
        expect { described_class.validate!("multiple_payment_methods") }.not_to raise_error
      end

      it "raises an error for invalid flags" do
        expect { described_class.validate!("invalid_flag") }
          .to raise_error(ArgumentError, "Unknown feature flag: invalid_flag")
      end
    end
  end

  describe ".sanitize!" do
    let(:organization_with_valid_flags) { create(:organization, feature_flags: ["multiple_payment_methods"]) }
    let(:organization_with_invalid_flags) { create(:organization, feature_flags: ["invalid_flag", "another_invalid"]) }
    let(:organization_with_mixed_flags) { create(:organization, feature_flags: ["multiple_payment_methods", "invalid_flag"]) }
    let(:organization_without_flags) { create(:organization, feature_flags: []) }

    before do
      organization_with_valid_flags
      organization_with_invalid_flags
      organization_with_mixed_flags
      organization_without_flags
    end

    it "removes invalid flags from organizations" do
      described_class.sanitize!

      expect(organization_with_valid_flags.reload.feature_flags).to eq(["multiple_payment_methods"])
      expect(organization_with_invalid_flags.reload.feature_flags).to eq([])
      expect(organization_with_mixed_flags.reload.feature_flags).to eq(["multiple_payment_methods"])
      expect(organization_without_flags.reload.feature_flags).to eq([])
    end

    it "does not update organizations that only have valid flags" do
      expect { described_class.sanitize! }
        .not_to change { organization_with_valid_flags.reload.updated_at }
    end
  end
end
