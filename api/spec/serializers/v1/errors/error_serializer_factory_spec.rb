# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Errors::ErrorSerializerFactory do
  subject(:serializer) { described_class.new_instance(error) }

  describe ".new_instance" do
    context "when error is a Stripe error" do
      let(:error) { ::Stripe::StripeError.new }

      it "returns a StripeErrorSerializer instance" do
        expect(serializer).to be_a(V1::Errors::StripeErrorSerializer)
      end
    end

    context "when error is not a Stripe error" do
      let(:error) { StandardError.new }

      it "returns a base ErrorSerializer instance" do
        expect(serializer).to be_a(ErrorSerializer)
      end
    end
  end
end
