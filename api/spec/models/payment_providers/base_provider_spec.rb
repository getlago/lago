# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::BaseProvider do
  subject(:provider) { described_class.new(attributes) }

  let(:secrets) { {"api_key" => api_key, "api_secret" => api_secret} }
  let(:api_key) { SecureRandom.uuid }
  let(:api_secret) { SecureRandom.uuid }

  let(:attributes) do
    {secrets: secrets.to_json}
  end

  it_behaves_like "paper_trail traceable" do
    subject { build(:stripe_provider) }
  end

  it { is_expected.to have_many(:payment_provider_customers).dependent(:nullify) }
  it { is_expected.to have_many(:customers).through(:payment_provider_customers) }
  it { is_expected.to have_many(:payments).dependent(:nullify) }
  it { is_expected.to have_many(:refunds).dependent(:nullify) }

  it { is_expected.to validate_presence_of(:name) }

  describe "validations" do
    describe "of code uniqueness" do
      let(:error) { payment_provider.errors.where(:code, :taken) }

      let(:payment_provider) { build(:stripe_provider, organization:, code: "stripe1") }
      let(:organization) { create(:organization) }

      before do
        create(:stripe_provider, code: "stripe1")
        create(:stripe_provider, code: "stripe1", organization:, deleted_at: generate(:past_date))
      end

      context "when code is unique in scope of the organization" do
        before { payment_provider.valid? }

        it "does not add an error" do
          expect(error).not_to be_present
        end
      end

      context "when code is not unique in scope of the organization" do
        before do
          create(:stripe_provider, code: "stripe1", organization:)

          payment_provider.valid?
        end

        it "adds an error" do
          expect(error).to be_present
        end
      end
    end
  end

  describe ".json_secrets" do
    it { expect(provider.secrets_json).to eq(secrets) }
  end

  describe ".push_to_secrets" do
    it "push the value into the secrets" do
      provider.push_to_secrets(key: "api_key", value: "foo_bar")

      expect(provider.secrets_json).to eq(
        {
          "api_key" => "foo_bar",
          "api_secret" => api_secret
        }
      )
    end
  end

  describe ".get_from_secrets" do
    it { expect(provider.get_from_secrets("api_secret")).to eq(api_secret) }

    it { expect(provider.get_from_secrets(nil)).to be_nil }
    it { expect(provider.get_from_secrets("foo")).to be_nil }
  end
end
