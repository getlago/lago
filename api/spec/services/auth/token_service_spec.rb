# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::TokenService do
  let(:user) { create(:user) }
  let(:user_id) { user.id }
  let(:extra) { {login_method: Organizations::AuthenticationMethods::EMAIL_PASSWORD} }
  let(:token) { described_class.encode(user:, **extra) }

  before { token }

  describe "self.encode" do
    subject { described_class.encode(**params) }

    context "with an user instance" do
      let(:params) { {user:} }

      it { is_expected.to be_present }

      it "produces the correct token for the user" do
        token = subject
        expect(described_class.decode(token:)["sub"]).to eq(user.id)
      end
    end

    context "with user_id" do
      let(:params) { {user_id:} }

      it { is_expected.to be_present }

      it "produces the correct token for the user" do
        token = subject
        expect(described_class.decode(token:)["sub"]).to eq(user_id)
      end
    end

    context "with extra auth info" do
      let(:params) { {user:, **extra} }

      it "produces the token with extra auth info" do
        token = subject
        expect(described_class.decode(token:)["login_method"]).to eq(Organizations::AuthenticationMethods::EMAIL_PASSWORD)
      end
    end

    context "without user info" do
      let(:params) { {user: nil, user_id: nil} }

      it { is_expected.to be_nil }
    end
  end

  describe "self.decode" do
    subject { described_class.decode(token:) }

    context "with token" do
      it { is_expected.to include("sub" => user.id, "login_method" => Organizations::AuthenticationMethods::EMAIL_PASSWORD) }
    end

    context "without token" do
      let(:token) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe "self.renew" do
    subject { described_class.renew(token:) }

    context "with token" do
      it { is_expected.to be_present }

      it "creates a new token" do
        travel_to(Time.current + 10.minutes) do
          expect(subject).not_to eq(token)
        end
      end

      it "renews with the same info" do
        travel_to(Time.current + 10.minutes) do
          old = described_class.decode(token:)
          renew = described_class.decode(token: subject)

          expect(renew["sub"]).to eq(old["sub"])
          expect(renew["login_method"]).to eq(old["login_method"])
          expect(renew["exp"].to_i).to be > old["exp"].to_i
        end
      end
    end

    context "without token" do
      let(:token) { nil }

      it { is_expected.to be_nil }
    end
  end
end
