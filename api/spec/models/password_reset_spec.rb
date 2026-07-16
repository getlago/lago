# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasswordReset do
  subject(:password_reset) do
    described_class.new(
      user: create(:user),
      token: SecureRandom.hex(20),
      expire_at: Time.current + 30.minutes
    )
  end

  describe "Validations" do
    it "is valid with valid attributes" do
      expect(password_reset).to be_valid
    end

    it "is not valid without user" do
      password_reset.user = nil

      expect(password_reset).not_to be_valid
    end

    it "is not valid without token" do
      password_reset.token = nil

      expect(password_reset).not_to be_valid
    end

    it "is not valid without expire_at" do
      password_reset.expire_at = nil

      expect(password_reset).not_to be_valid
    end
  end
end
