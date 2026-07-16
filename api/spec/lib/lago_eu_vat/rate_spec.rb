# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoEuVat::Rate do
  subject { described_class }

  describe "#country_codes" do
    it "returns all EU country codes" do
      # NOTE: 28 in the original file but we removed GB manually
      expect(subject.country_codes.count).to eq(27)
    end
  end

  describe "#country_rate" do
    it "returns all applicable rates for a country" do
      fr_taxes = subject.country_rates(country_code: "FR")
      fr_rates = fr_taxes[:rates]
      fr_exceptions = fr_taxes[:exceptions]

      expect(fr_rates["standard"]).to eq(20)
      expect(fr_exceptions.count).to eq(5)
    end
  end
end
