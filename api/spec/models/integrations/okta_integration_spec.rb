# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::OktaIntegration do
  subject(:okta_integration) { build(:okta_integration) }

  it { is_expected.to validate_presence_of(:domain) }
  it { is_expected.to validate_presence_of(:organization_name) }
  it { is_expected.to validate_presence_of(:client_id) }
  it { is_expected.to validate_presence_of(:client_secret) }

  describe "#host" do
    context "when settings host is present" do
      before do
        subject.host = "test.com"
      end

      it "use the settings host" do
        expect(subject.host).to eq("test.com")
      end
    end

    context "when settings host is nil" do
      before do
        subject.organization_name = "test"
        subject.host = nil
      end

      it "use the default host" do
        expect(subject.host).to eq("test.okta.com")
      end
    end
  end

  describe "validations" do
    it "validates uniqueness of domain" do
      expect(okta_integration).to be_valid
    end

    context "when domain already exists" do
      before { create(:okta_integration) }

      it "does not validate the record" do
        expect(okta_integration).not_to be_valid
        expect(okta_integration.errors).to include(:domain)
      end
    end
  end
end
