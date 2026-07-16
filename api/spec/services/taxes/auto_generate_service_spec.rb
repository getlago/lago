# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::AutoGenerateService do
  subject(:auto_generate_service) { described_class.new(organization:) }

  let(:organization) { create(:organization) }

  describe ".call" do
    it "creates eu taxes for organization" do
      auto_generate_service.call

      expect(organization.taxes.count).to eq(47) # EU taxes + 2 defaults
    end

    it "updates eu taxes for organization" do
      auto_generate_service.call
      organization.taxes.update_all(rate: 99) # rubocop:disable Rails/SkipsModelValidations
      expect(organization.taxes.pluck(:rate)).to all eq 99

      auto_generate_service.call
      expect(organization.taxes.count).to eq(47) # No new taxes created
      expect(organization.taxes.pluck(:rate)).to all(be < 99)
    end
  end
end
