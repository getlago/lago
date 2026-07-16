# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasFeatureFlags do
  subject(:organization) { create(:organization, feature_flags: []) }

  let(:valid_flag) { FeatureFlag::DEFINITION.keys.first }

  before do
    skip "No feature flags defined" if FeatureFlag::DEFINITION.empty?
  end

  describe "#feature_flag_enabled?" do
    it "returns false when flag is not in the list" do
      expect(organization.feature_flag_enabled?(valid_flag)).to be false
    end

    it "returns true when flag is in the list and definition" do
      organization.update!(feature_flags: [valid_flag])
      expect(organization.feature_flag_enabled?(valid_flag)).to be true
    end

    context "when flag is in the list but not in definition" do
      it "raises error in non-production environment" do
        organization.update_column(:feature_flags, ["unknown_flag"]) # rubocop:disable Rails/SkipsModelValidations
        expect { organization.feature_flag_enabled?("unknown_flag") }
          .to raise_error(ArgumentError, "Unknown feature flag: unknown_flag")
      end

      it "is a no-op in production environment" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        organization.update_column(:feature_flags, ["unknown_flag"]) # rubocop:disable Rails/SkipsModelValidations
        expect(organization.feature_flag_enabled?("unknown_flag")).to be false
      end
    end

    it "accepts symbol as flag name" do
      organization.update!(feature_flags: [valid_flag])
      expect(organization.feature_flag_enabled?(valid_flag.to_sym)).to be true
    end
  end

  describe "#feature_flag_disabled?" do
    it "returns true when flag is not enabled" do
      expect(organization.feature_flag_disabled?(valid_flag)).to be true
    end

    it "returns false when flag is enabled" do
      organization.update!(feature_flags: [valid_flag])
      expect(organization.feature_flag_disabled?(valid_flag)).to be false
    end
  end

  describe "#enable_feature_flag!" do
    it "adds the flag to the list" do
      expect { organization.enable_feature_flag!(valid_flag) }
        .to change { organization.reload.feature_flags }
        .from([]).to([valid_flag])
    end

    it "does not duplicate flags" do
      organization.update!(feature_flags: [valid_flag])
      expect { organization.enable_feature_flag!(valid_flag) }
        .not_to change { organization.reload.feature_flags }
    end

    it "accepts symbol as flag name" do
      organization.enable_feature_flag!(valid_flag.to_sym)
      expect(organization.reload.feature_flags).to eq([valid_flag])
    end

    context "when flag is not in definition" do
      it "raises error in non-production environment" do
        expect { organization.enable_feature_flag!("unknown_flag") }
          .to raise_error(ArgumentError, "Unknown feature flag: unknown_flag")
      end

      it "is a no-op in production environment" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        expect { organization.enable_feature_flag!("unknown_flag") }
          .not_to change { organization.reload.feature_flags }
      end
    end
  end

  describe "#disable_feature_flag!" do
    before { organization.update!(feature_flags: [valid_flag]) }

    it "removes the flag from the list" do
      expect { organization.disable_feature_flag!(valid_flag) }
        .to change { organization.reload.feature_flags }
        .from([valid_flag]).to([])
    end

    it "does nothing if flag is not in the list" do
      organization.update!(feature_flags: [])
      expect { organization.disable_feature_flag!(valid_flag) }
        .not_to change { organization.reload.feature_flags }
    end

    it "accepts symbol as flag name" do
      organization.disable_feature_flag!(valid_flag.to_sym)
      expect(organization.reload.feature_flags).to eq([])
    end

    context "when flag is not in definition" do
      it "raises error in non-production environment" do
        expect { organization.disable_feature_flag!("unknown_flag") }
          .to raise_error(ArgumentError, "Unknown feature flag: unknown_flag")
      end

      it "is a no-op in production environment" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        expect { organization.disable_feature_flag!("unknown_flag") }
          .not_to change { organization.reload.feature_flags }
      end
    end
  end
end
