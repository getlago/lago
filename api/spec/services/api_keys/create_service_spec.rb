# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeys::CreateService do
  include_context "with mocked security logger"

  describe "#call" do
    subject(:service_result) { described_class.call(params) }

    let(:name) { Faker::Lorem.words.join(" ") }
    let(:organization) { create(:organization) }

    context "with premium organization", :premium do
      context "when permissions hash is provided" do
        let(:params) { {permissions:, name:, organization:} }
        let(:permissions) { {"add_on" => ["read", "write"], "customer" => []} }

        before { organization.update!(premium_integrations:) }

        context "when organization has api permissions addon" do
          let(:premium_integrations) { ["api_permissions"] }

          it "creates a new API key" do
            expect { service_result }.to change(ApiKey, :count).by(1)
          end

          it "sends an API key created email" do
            expect { service_result }
              .to have_enqueued_mail(ApiKeyMailer, :created)
              .with(hash_including(params: {api_key: instance_of(ApiKey)}))
          end

          it_behaves_like "produces a security log", "api_key.created" do
            before { service_result }
          end
        end

        context "when organization has no api permissions addon" do
          let(:premium_integrations) { [] }

          it "does not create an API key" do
            expect { service_result }.not_to change(ApiKey, :count)
          end

          it "does not send an API key created email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :created)
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
        let(:params) { {name:, organization:} }

        before { organization.update!(premium_integrations:) }

        context "when organization has api permissions addon" do
          let(:premium_integrations) { ["api_permissions"] }

          it "creates a new API key" do
            expect { service_result }.to change(ApiKey, :count).by(1)
          end

          it "sends an API key created email" do
            expect { service_result }
              .to have_enqueued_mail(ApiKeyMailer, :created)
              .with(hash_including(params: {api_key: instance_of(ApiKey)}))
          end
        end

        context "when organization has no api permissions addon" do
          let(:premium_integrations) { [] }

          it "creates a new API key" do
            expect { service_result }.to change(ApiKey, :count).by(1)
          end

          it "sends an API key created email" do
            expect { service_result }
              .to have_enqueued_mail(ApiKeyMailer, :created)
              .with(hash_including(params: {api_key: instance_of(ApiKey)}))
          end
        end
      end
    end

    context "with free organization" do
      context "when permissions hash is provided" do
        let(:params) { {permissions:, name:, organization:} }
        let(:permissions) { ApiKey.default_permissions }

        before { organization.update!(premium_integrations:) }

        context "when organization has api permissions addon" do
          let(:premium_integrations) { ["api_permissions"] }

          it "does not create an API key" do
            expect { service_result }.not_to change(ApiKey, :count)
          end

          it "does not send an API key created email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :created)
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error).to be_a(BaseService::ForbiddenFailure)
          end

          it_behaves_like "does not produce a security log" do
            before { service_result }
          end
        end

        context "when organization has no api permissions addon" do
          let(:premium_integrations) { [] }

          it "does not create an API key" do
            expect { service_result }.not_to change(ApiKey, :count)
          end

          it "does not send an API key created email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :created)
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error).to be_a(BaseService::ForbiddenFailure)
          end

          it_behaves_like "does not produce a security log" do
            before { service_result }
          end
        end
      end

      context "when permissions hash is missing" do
        let(:params) { {name:, organization:} }

        before { organization.update!(premium_integrations:) }

        context "when organization has api permissions addon" do
          let(:premium_integrations) { ["api_permissions"] }

          it "does not create an API key" do
            expect { service_result }.not_to change(ApiKey, :count)
          end

          it "does not send an API key created email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :created)
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error).to be_a(BaseService::ForbiddenFailure)
          end

          it_behaves_like "does not produce a security log" do
            before { service_result }
          end
        end

        context "when organization has no api permissions addon" do
          let(:premium_integrations) { [] }

          it "does not create an API key" do
            expect { service_result }.not_to change(ApiKey, :count)
          end

          it "does not send an API key created email" do
            expect { service_result }.not_to have_enqueued_mail(ApiKeyMailer, :created)
          end

          it "returns an error" do
            expect(service_result).not_to be_success
            expect(service_result.error).to be_a(BaseService::ForbiddenFailure)
          end

          it_behaves_like "does not produce a security log" do
            before { service_result }
          end
        end
      end
    end
  end
end
