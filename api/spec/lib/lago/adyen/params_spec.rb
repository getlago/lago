# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lago::Adyen::Params do
  let(:adyen_params) { described_class.new(params) }

  describe "#to_h" do
    subject(:to_h) { adyen_params.to_h }

    let(:default_params_hash) do
      {
        applicationInfo: {
          externalPlatform: {
            name: "Lago",
            integrator: "Lago"
          },
          merchantApplication: {
            name: "Lago"
          }
        }
      }
    end

    context "when params are empty hash" do
      let(:params) { {} }

      it "returns default params hash" do
        expect(to_h).to eq(default_params_hash)
      end
    end

    context "when params are nil" do
      let(:params) { nil }

      it "returns default params hash" do
        expect(to_h).to eq(default_params_hash)
      end
    end

    context "when params are present" do
      let(:params) do
        {
          merchantAccount: "Lago Account",
          shopperReference: "Lago123"
        }
      end

      let(:merged_params_hash) do
        default_params_hash.merge(params)
      end

      it "returns default params hash merged with given params" do
        expect(to_h).to eq(merged_params_hash)
      end
    end
  end
end
