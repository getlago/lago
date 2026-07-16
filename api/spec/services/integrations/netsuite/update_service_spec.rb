# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Netsuite::UpdateService do
  include_context "with mocked security logger"

  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  describe "#call" do
    subject(:service_call) { described_class.call(integration:, params: update_args) }

    before { integration }

    let(:name) { "Netsuite 1" }
    let(:script_endpoint_url) { Faker::Internet.url }

    let(:update_args) do
      {
        name:,
        code: "netsuite1",
        script_endpoint_url:
      }
    end

    context "without premium license" do
      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      end
    end

    context "with premium license", :premium do
      context "with netsuite premium integration not present" do
        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        end
      end

      context "with netsuite premium integration present" do
        before do
          organization.update!(premium_integrations: ["netsuite"])
          allow(Integrations::Aggregator::SendRestletEndpointJob).to receive(:perform_later)
          allow(Integrations::Aggregator::PerformSyncJob).to receive(:perform_later)
        end

        context "without validation errors" do
          it "updates an integration" do
            service_call

            integration = Integrations::NetsuiteIntegration.order(:updated_at).last
            expect(integration.name).to eq(name)
            expect(integration.script_endpoint_url).to eq(script_endpoint_url)
          end

          it "returns an integration in result object" do
            result = service_call

            expect(result.integration).to be_a(Integrations::NetsuiteIntegration)
          end

          it_behaves_like "produces a security log", "integration.updated" do
            before { service_call }
          end

          it "calls Integrations::Aggregator::SendRestletEndpointJob" do
            service_call

            expect(Integrations::Aggregator::SendRestletEndpointJob).to have_received(:perform_later).with(integration:)
          end

          it "calls Integrations::Aggregator::PerformSyncJob" do
            expect { service_call }.to have_enqueued_job(Integrations::Aggregator::PerformSyncJob)
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
end
