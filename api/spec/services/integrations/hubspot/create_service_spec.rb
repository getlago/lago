# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::CreateService do
  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  describe "#call" do
    subject(:service_call) { described_class.call(params: create_args) }

    let(:name) { "Hubspot 1" }
    let(:script_endpoint_url) { Faker::Internet.url }

    let(:create_args) do
      {
        name:,
        code: "hubspot1",
        organization_id: organization.id,
        connection_id: "conn1",
        client_secret: "secret",
        default_targeted_object: "test",
        sync_invoices: false,
        sync_subscriptions: false
      }
    end

    context "without premium license" do
      it "does not create an integration" do
        expect { service_call }.not_to change(Integrations::HubspotIntegration, :count)
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      end
    end

    context "with premium license", :premium do
      context "with hubspot premium integration not present" do
        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        end
      end

      context "with hubspot premium integration present" do
        before do
          organization.update!(premium_integrations: ["hubspot"])
          allow(Integrations::Aggregator::SyncCustomObjectsAndPropertiesJob).to receive(:perform_later)
          allow(Integrations::Hubspot::SavePortalIdJob).to receive(:perform_later)
        end

        context "without validation errors" do
          it "creates an integration" do
            expect { service_call }.to change(Integrations::HubspotIntegration, :count).by(1)

            integration = Integrations::HubspotIntegration.order(:created_at).last
            expect(integration.name).to eq(name)
            expect(integration.code).to eq(create_args[:code])
            expect(integration.connection_id).to eq(create_args[:connection_id])
            expect(integration.default_targeted_object).to eq(create_args[:default_targeted_object])
            expect(integration.sync_invoices).to eq(create_args[:sync_invoices])
            expect(integration.sync_subscriptions).to eq(create_args[:sync_subscriptions])
            expect(integration.organization_id).to eq(organization.id)
          end

          it "returns an integration in result object" do
            result = service_call

            expect(result.integration).to be_a(Integrations::HubspotIntegration)
          end

          it "enqueues the jobs to send token and sync objects to Hubspot" do
            service_call

            integration = Integrations::HubspotIntegration.order(:created_at).last
            expect(Integrations::Aggregator::SyncCustomObjectsAndPropertiesJob).to have_received(:perform_later).with(integration:)
            expect(Integrations::Hubspot::SavePortalIdJob).to have_received(:perform_later).with(integration:)
          end

          it_behaves_like "produces a security log", "integration.created" do
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
end
