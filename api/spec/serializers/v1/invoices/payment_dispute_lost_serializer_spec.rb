# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Invoices::PaymentDisputeLostSerializer do
  subject(:serializer) { described_class.new(invoice, options) }

  let(:invoice) { create(:invoice, :dispute_lost) }

  context "when options are present" do
    let(:options) do
      {
        "provider_error" => {
          "error_message" => "message",
          "error_code" => "code"
        }
      }.with_indifferent_access
    end

    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      expect(result["data"]["invoice"]["lago_id"]).to eq(invoice.id)
      expect(result["data"]["provider_error"]).to eq(options[:provider_error])
    end
  end

  context "when options are not present" do
    let(:options) do
      {}
    end

    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      expect(result["data"]["invoice"]["lago_id"]).to eq(invoice.id)
      expect(result["data"].key?("provider_error")).to eq(false)
    end
  end
end
