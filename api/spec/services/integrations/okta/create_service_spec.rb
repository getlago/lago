# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Okta::CreateService do
  include_context "with mocked security logger"

  let(:service) { described_class.new(membership.user) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:domain) { "foo.bar" }
  let(:host) { "test.com" }

  describe "#call" do
    subject(:service_call) { service.call(**create_args) }

    let(:create_args) do
      {
        organization_id: organization.id,
        client_id: "cl1",
        client_secret: "secret",
        domain:,
        organization_name: "Foobar",
        host:
      }
    end

    context "without premium license" do
      it "does not create an integration" do
        expect { service_call }.not_to change(Integrations::OktaIntegration, :count)
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      end
    end

    context "with premium license", :premium do
      context "with okta premium integration not present" do
        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        end
      end

      context "with okta premium integration present" do
        before { organization.update!(premium_integrations: ["okta"]) }

        context "without validation errors" do
          it "creates an integration" do
            expect { service_call }.to change(Integrations::OktaIntegration, :count).by(1)

            integration = Integrations::OktaIntegration.order(:created_at).last
            expect(integration.domain).to eq(domain)
          end

          it "enables okta authentication" do
            service_call
            expect(organization.reload).to be_okta_authentication_enabled
          end

          it_behaves_like "produces a security log", "integration.created" do
            before { service_call }
          end
        end

        context "with validation error" do
          let(:domain) { nil }

          it "returns an error" do
            result = service_call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:domain]).to eq(["value_is_mandatory"])
          end
        end
      end
    end
  end
end
