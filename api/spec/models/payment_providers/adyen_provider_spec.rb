# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AdyenProvider do
  subject(:provider) { build(:adyen_provider) }

  it { is_expected.to validate_length_of(:success_redirect_url).is_at_most(1024).allow_nil }
  it { is_expected.to validate_presence_of(:name) }

  describe "validations" do
    let(:errors) { provider.errors }

    it "validates uniqueness of the code" do
      expect(provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end

    describe "of success redirect url format" do
      subject(:provider) { build(:adyen_provider, success_redirect_url:) }

      before { provider.valid? }

      context "when it is valid url with http(s) scheme" do
        let(:success_redirect_url) { Faker::Internet.url }

        it "does not add an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).not_to be_present
        end
      end

      context "when it is valid url with custom scheme" do
        let(:success_redirect_url) { "my-app://your.package.name?param=12&p=7" }

        it "does not add an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).not_to be_present
        end
      end

      context "when it is nil" do
        let(:success_redirect_url) { nil }

        it "does not add an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).not_to be_present
        end
      end

      context "when it is an empty string" do
        let(:success_redirect_url) { "" }

        it "adds an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).to be_present
        end
      end

      context "when it is not valid url" do
        context "when it contains no scheme" do
          let(:success_redirect_url) { "your.package.name?param=12&p=7" }

          it "adds an error" do
            expect(errors.where(:success_redirect_url, :url_invalid)).to be_present
          end
        end

        context "when it contains only scheme" do
          let(:success_redirect_url) { "https://" }

          it "adds an error" do
            expect(errors.where(:success_redirect_url, :url_invalid)).to be_present
          end
        end

        context "when it is just a string" do
          let(:success_redirect_url) { "invalidurl" }

          it "adds an error" do
            expect(errors.where(:success_redirect_url, :url_invalid)).to be_present
          end
        end
      end
    end
  end

  describe "#api_key" do
    let(:api_key) { SecureRandom.uuid }

    before { provider.api_key = api_key }

    it "returns the api key" do
      expect(provider.api_key).to eq api_key
    end
  end

  describe "#merchant_account" do
    let(:merchant_account) { "TestECOM" }

    before { provider.merchant_account = merchant_account }

    it "returns the merchant account" do
      expect(provider.merchant_account).to eq merchant_account
    end
  end

  describe "#live_prefix" do
    let(:live_prefix) { Faker::Internet.domain_word }

    before { provider.live_prefix = live_prefix }

    it "returns the live prefix" do
      expect(provider.live_prefix).to eq live_prefix
    end
  end

  describe "#hmac_key" do
    let(:hmac_key) { SecureRandom.uuid }

    before { provider.hmac_key = hmac_key }

    it "returns the hmac key" do
      expect(provider.hmac_key).to eq hmac_key
    end
  end

  describe "#success_redirect_url" do
    let(:success_redirect_url) { Faker::Internet.url }

    before { provider.success_redirect_url = success_redirect_url }

    it "returns the url" do
      expect(provider.success_redirect_url).to eq success_redirect_url
    end
  end
end
