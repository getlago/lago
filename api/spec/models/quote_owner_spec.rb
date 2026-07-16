# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuoteOwner do
  subject(:quote_owner) { create(:quote_owner) }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:quote)
      expect(subject).to belong_to(:user)
    end
  end
end
