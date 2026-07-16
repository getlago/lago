# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKey do
  subject { build(:api_key, expires_at:) }

  let(:expires_at) { nil }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:organization) }

  it { is_expected.to validate_presence_of(:permissions) }

  describe "validations" do
    describe "of value uniqueness" do
      before { create(:api_key) }

      it { is_expected.to validate_uniqueness_of(:value) }
    end

    describe "of value presence" do
      subject { api_key }

      context "with a new record" do
        let(:api_key) { build(:api_key) }

        it { is_expected.not_to validate_presence_of(:value) }
      end

      context "with a persisted record" do
        let(:api_key) { create(:api_key) }

        it { is_expected.to validate_presence_of(:value) }
      end
    end

    describe "of permissions structure" do
      subject { api_key.valid? }

      let(:api_key) { build_stubbed(:api_key) }
      let(:error) { api_key.errors.where(:permissions, :forbidden_keys) }

      context "when permissions has forbidden keys" do
        before do
          api_key.permissions = api_key.permissions.merge(forbidden: [])
          subject
        end

        it "adds forbidden keys error" do
          expect(error).to be_present
        end
      end

      context "when permissions has no forbidden keys" do
        before { subject }

        it "does not add forbidden keys error" do
          expect(error).not_to be_present
        end
      end
    end

    describe "of permissions values" do
      subject { api_key.valid? }

      let(:api_key) { build_stubbed(:api_key, permissions:) }
      let(:error) { api_key.errors.where(:permissions, :forbidden_values) }

      before { subject }

      context "when permission contains forbidden values" do
        let(:permissions) { {add_on: ["forbidden", "read"]} }

        it "adds an error" do
          expect(error).to be_present
        end
      end

      context "when permission contains only allowed values" do
        let(:permissions) { {add_on: ["read", "write"]} }

        it "does not add an error" do
          expect(error).not_to be_present
        end
      end
    end
  end

  describe "#save" do
    subject { api_key.save! }

    context "with a new record" do
      let(:api_key) { build(:api_key) }
      let(:used_value) { create(:api_key).value }
      let(:unique_value) { SecureRandom.uuid }

      before do
        allow(SecureRandom).to receive(:uuid).and_return(used_value, unique_value)
      end

      it "sets the value" do
        expect { subject }.to change(api_key, :value).to unique_value
      end
    end

    context "with a persisted record" do
      let(:api_key) { create(:api_key) }

      it "does not change the value" do
        expect { subject }.not_to change(api_key, :value)
      end
    end
  end

  describe "default_scope" do
    subject { described_class.all }

    let!(:scoped) do
      [
        create(:api_key),
        create(:api_key, :expiring)
      ]
    end

    before { create(:api_key, :expired) }

    it "returns API keys with either no expiration or future expiration dates" do
      expect(subject).to match_array scoped
    end
  end

  describe ".non_expiring" do
    subject { described_class.non_expiring }

    let!(:scoped) { create(:api_key) }

    before { create(:api_key, :expiring) }

    it "returns API keys with no expiration date" do
      expect(subject).to contain_exactly scoped
    end
  end

  describe ".with_most_permissions" do
    subject { organization.api_keys.with_most_permissions }

    let(:organization) { create(:organization) }

    let(:limited_permissions_key) do
      create(:api_key, organization:, permissions: {add_on: ["read"], customer: ["read"]})
    end

    before { limited_permissions_key }

    it "returns the API key with the most permissions" do
      expect(subject).not_to eq(limited_permissions_key)
      expect(subject.permissions).to eq(described_class.default_permissions)
    end
  end

  describe "#permit?", :premium do
    subject { api_key.permit?(resource, mode) }

    let(:api_key) { create(:api_key, permissions:) }
    let(:resource) { described_class::RESOURCES.sample }
    let(:mode) { described_class::MODES.sample }

    before { api_key.organization.update!(premium_integrations:) }

    context "when organization has 'api_permissions' add-on enabled" do
      let(:premium_integrations) { ["api_permissions"] }

      context "when corresponding resource is specified in permissions" do
        let(:permissions) { {resource => allowed_modes} }

        context "when corresponding resource allows provided mode" do
          let(:allowed_modes) { [mode] }

          it "returns true" do
            expect(subject).to be true
          end
        end

        context "when corresponding resource does not allow provided mode" do
          let(:allowed_modes) { described_class::MODES.excluding(mode) }

          it "returns false" do
            expect(subject).to be false
          end
        end
      end

      context "when corresponding resource does not specified in permissions" do
        let(:permissions) { described_class.default_permissions.without(resource) }

        it "returns false" do
          expect(subject).to be false
        end
      end
    end

    context "when organization has 'api_permissions' add-on disabled" do
      let(:premium_integrations) { [] }

      context "when corresponding resource is specified in permissions" do
        let(:permissions) { {resource => allowed_modes} }

        context "when corresponding resource allows provided mode" do
          let(:allowed_modes) { [mode] }

          it "returns true" do
            expect(subject).to be true
          end
        end

        context "when corresponding resource does not allow provided mode" do
          let(:allowed_modes) { described_class::MODES.excluding(mode) }

          it "returns true" do
            expect(subject).to be true
          end
        end
      end

      context "when corresponding resource does not specified in permissions" do
        let(:permissions) { described_class.default_permissions.without(resource) }

        it "returns true" do
          expect(subject).to be true
        end
      end
    end
  end

  describe "#expired?" do
    it { expect(subject).not_to be_expired }

    context "with an expires_at value" do
      let(:expires_at) { Time.current + 1.hour }

      it { expect(subject).not_to be_expired }

      context "when expires_at is in the past" do
        let(:expires_at) { Time.current - 1.hour }

        it { expect(subject).to be_expired }
      end
    end
  end
end
