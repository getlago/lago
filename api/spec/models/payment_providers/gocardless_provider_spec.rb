# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::GocardlessProvider do
  subject(:gocardless_provider) { build(:gocardless_provider, attributes) }

  let(:attributes) {}

  it { is_expected.to validate_length_of(:success_redirect_url).is_at_most(1024).allow_nil }
  it { is_expected.to validate_presence_of(:name) }

  describe "validations" do
    let(:errors) { provider.errors }

    it "validates uniqueness of the code" do
      expect(gocardless_provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end

    describe "of success redirect url format" do
      subject(:provider) { build(:gocardless_provider, success_redirect_url:) }

      before { provider.valid? }

      context "when it is valid url with http(s) scheme" do
        let(:success_redirect_url) { Faker::Internet.url }

        it "does not add an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).not_to be_present
        end
      end

      context "when it is valid url with custom scheme" do
        let(:success_redirect_url) { "my-app://your.package.name?param=12&p=7" }

        it "adds an error" do
          expect(errors.where(:success_redirect_url, :url_invalid)).to be_present
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

  describe "access_token" do
    it "assigns and retrieves an access token" do
      gocardless_provider.access_token = "foo_bar"
      expect(gocardless_provider.access_token).to eq("foo_bar")
    end
  end

  describe "#success_redirect_url" do
    let(:success_redirect_url) { Faker::Internet.url }

    before { gocardless_provider.success_redirect_url = success_redirect_url }

    it "returns the url" do
      expect(gocardless_provider.success_redirect_url).to eq success_redirect_url
    end
  end
end
