# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Errors::StripeErrorSerializer do
  describe "#serialize" do
    subject(:serializer) { described_class.new(error) }

    let(:error) do
      Stripe::StripeError.new(
        "Your card was declined.",
        code: "card_declined",
        http_headers: {"request-id" => "req_123"},
        http_status: 402,
        http_body: '{"error": {"type": "card_error"}}'
      )
    end

    it "serializes the Stripe error with all attributes" do
      expect(serializer.serialize).to eq({
        code: "card_declined",
        message: "Your card was declined.",
        request_id: "req_123",
        http_status: 402,
        http_body: {"error" => {"type" => "card_error"}}
      })
    end

    context "when http_body is nil" do
      before do
        allow(error).to receive(:http_body).and_return(nil)
      end

      it "returns empty object for http_body" do
        expect(serializer.serialize[:http_body]).to eq({})
      end
    end
  end
end
