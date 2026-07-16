# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Anrok::UpdateService do
  include_context "with mocked security logger"

  let(:integration) { create(:anrok_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  describe "#call" do
    subject(:service_call) { described_class.call(integration:, params: update_args) }

    before { integration }

    let(:name) { "Anrok 1" }

    let(:update_args) do
      {
        name:,
        code: "anrok1",
        api_key: "123456789"
      }
    end

    context "without premium license" do
      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "with premium license", :premium do
      context "without validation errors" do
        it "updates an integration" do
          service_call

          integration = Integrations::AnrokIntegration.order(updated_at: :desc).first
          expect(integration.name).to eq(name)
          expect(integration.api_key).to eq("123456789")
        end

        it "returns an integration in result object" do
          result = service_call

          expect(result.integration).to be_a(Integrations::AnrokIntegration)
        end

        it_behaves_like "produces a security log", "integration.updated" do
          before { service_call }
        end
      end

      context "with validation error" do
        let(:name) { nil }

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
        end
      end
    end
  end
end
