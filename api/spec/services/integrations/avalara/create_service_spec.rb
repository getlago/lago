# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Avalara::CreateService do
  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  describe "#call" do
    subject(:service_call) { described_class.call(params: create_args) }

    let(:name) { "Avalara 1" }

    let(:create_args) do
      {
        name:,
        code: "anrok1",
        organization_id: organization.id,
        connection_id: "conn1",
        account_id: "account-id1",
        company_code: "company-code1",
        license_key: "123456789"
      }
    end

    context "without premium license" do
      it "does not create an integration" do
        expect { service_call }.not_to change(Integrations::AvalaraIntegration, :count)
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      end
    end

    context "with premium license", :premium do
      context "when avalara premium integration is not present" do
        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        end
      end

      context "when avalara premium integration is present" do
        before do
          organization.update!(premium_integrations: ["avalara"])
          allow(Integrations::Avalara::FetchCompanyIdJob).to receive(:perform_later)
        end

        context "without validation errors" do
          it "creates an integration" do
            expect { service_call }.to change(Integrations::AvalaraIntegration, :count).by(1)
          end

          it "returns an integration in result object" do
            result = service_call

            expect(result.integration).to be_a(Integrations::AvalaraIntegration)
            expect(result.integration.name).to eq(name)
            expect(result.integration.code).to eq("anrok1")
            expect(result.integration.organization).to eq(organization)
            expect(result.integration.connection_id).to eq("conn1")
            expect(result.integration.company_code).to eq("company-code1")
            expect(result.integration.account_id).to eq("account-id1")
            expect(result.integration.license_key).to eq("123456789")
          end

          it "enqueues the jobs to fetch company id" do
            service_call

            integration = Integrations::AvalaraIntegration.order(:created_at).last
            expect(Integrations::Avalara::FetchCompanyIdJob).to have_received(:perform_later).with(integration:)
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
