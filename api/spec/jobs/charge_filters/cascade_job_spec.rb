# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeFilters::CascadeJob do
  let(:charge) { create(:standard_charge) }
  let(:filter_values) { {"region" => ["us"]} }
  let(:old_properties) { {"amount" => "10"} }
  let(:new_properties) { {"amount" => "15"} }
  let(:invoice_display_name) { "US region" }

  before do
    allow(ChargeFilters::CascadeService).to receive(:call!)
  end

  it "calls the cascade service" do
    described_class.perform_now(charge.id, "update", filter_values, old_properties, new_properties, invoice_display_name)

    expect(ChargeFilters::CascadeService).to have_received(:call!).with(
      charge:,
      action: "update",
      filter_values:,
      old_properties:,
      new_properties:,
      invoice_display_name:
    )
  end

  context "when charge does not exist" do
    it "does not call the cascade service" do
      described_class.perform_now(SecureRandom.uuid, "update", filter_values, old_properties, new_properties, invoice_display_name)

      expect(ChargeFilters::CascadeService).not_to have_received(:call!)
    end
  end
end
