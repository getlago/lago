# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDevice do
  subject(:user_device) { build(:user_device) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it do
      expect(user_device).to validate_uniqueness_of(:fingerprint).scoped_to(:user_id)
    end
  end
end
