# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeys::UpdateService, :premium do
  subject(:service_result) { described_class.call(api_key:, params:) }

  include_context "with mocked security logger"

  let(:name) { Faker::Lorem.words.join(" ") }

  context "when API key is provided" do
    let!(:api_key) { create(:api_key) }
    let(:organization) { api_key.organization }

    context "when permissions hash is provided" do
      let(:params) { {permissions:, name:} }
      let(:permissions) { api_key.permissions.merge("add_on" => ["read"]) }

      before { organization.update!(premium_integrations:) }

      context "when organization has api permissions addon" do
        let(:premium_integrations) { ["api_permissions"] }

        it "updates the API key" do
          expect { service_result }.to change { api_key.reload.permissions }.to(permissions)
        end

        it_behaves_like "produces a security log", "api_key.updated" do
          before { service_result }
        end
      end

      context "when organization has no api permissions addon" do
        let(:premium_integrations) { [] }

        it "does not update an API key" do
          expect { service_result }.not_to change(api_key, :permissions)
        end

        it "returns an error" do
          expect(service_result).not_to be_success
          expect(service_result.error).to be_a(BaseService::ForbiddenFailure)
          expect(service_result.error.code).to eq("premium_integration_missing")
        end

        it_behaves_like "does not produce a security log" do
          before { service_result }
        end
      end
    end

    context "when permissions hash is missing" do
      let(:params) { {name:} }

      before { organization.update!(premium_integrations:) }

      context "when organization has api permissions addon" do
        let(:premium_integrations) { ["api_permissions"] }

        it "updates the API key" do
          expect { service_result }.to change(api_key, :name).to(name)
        end
      end

      context "when organization has no api permissions addon" do
        let(:premium_integrations) { [] }

        it "updates the API key" do
          expect { service_result }.to change(api_key, :name).to(name)
        end
      end
    end
  end

  context "when API key is missing" do
    let(:api_key) { nil }
    let(:params) { {name:} }

    it "returns an error" do
      expect(service_result).not_to be_success
      expect(service_result.error).to be_a(BaseService::NotFoundFailure)
      expect(service_result.error.error_code).to eq("api_key_not_found")
    end

    it_behaves_like "does not produce a security log" do
      before { service_result }
    end
  end
end
