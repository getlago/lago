# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::CreateService do
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }
  let(:integration_type) { "netsuite" }

  describe "#call" do
    subject(:service_call) { described_class.call(params:, integration:, customer:) }

    let(:params) do
      {
        integration_type:,
        integration_code:,
        sync_with_provider:,
        external_customer_id:,
        subsidiary_id:
      }
    end

    let(:subsidiary_id) { "1" }

    context "with netsuite premium integration present", :premium do
      let(:integration_code) { integration.code }
      let(:external_customer_id) { nil }
      let(:sync_with_provider) { true }
      let(:contact_id) { SecureRandom.uuid }

      let(:create_result) do
        result = BaseService::Result.new
        result.contact_id = contact_id
        result
      end

      let(:integration_customer) { IntegrationCustomers::BaseCustomer.last }

      before do
        organization.update!(premium_integrations: ["netsuite"])

        allow(Integrations::Aggregator::Contacts::CreateService)
          .to receive(:call).and_return(create_result)
      end

      context "when sync with provider is true" do
        let(:sync_with_provider) { true }

        context "when customer external id is present" do
          let(:external_customer_id) { SecureRandom.uuid }

          it "returns integration customer" do
            result = service_call

            expect(Integrations::Aggregator::Contacts::CreateService).not_to have_received(:call)
            expect(result).to be_success
            expect(result.integration_customer).to eq(integration_customer)
            expect(result.integration_customer.external_customer_id).to eq(external_customer_id)
          end

          it "creates integration customer" do
            expect { service_call }.to change(IntegrationCustomers::BaseCustomer, :count).by(1)
          end

          context "when the integration type is salesforce" do
            let(:integration) { create(:salesforce_integration, organization:) }
            let(:integration_type) { "salesforce" }

            it "returns integration customer with sync_with_provider true" do
              result = service_call

              expect(Integrations::Aggregator::Contacts::CreateService).not_to have_received(:call)
              expect(result).to be_success
              expect(result.integration_customer).to eq(integration_customer)
              expect(result.integration_customer.external_customer_id).to eq(external_customer_id)
              expect(result.integration_customer.sync_with_provider).to eq(true)
            end
          end
        end

        context "when customer external id is not present" do
          let(:external_customer_id) { nil }

          it "returns integration customer" do
            result = service_call

            expect(Integrations::Aggregator::Contacts::CreateService).to have_received(:call)
            expect(result).to be_success
            expect(result.integration_customer).to eq(integration_customer)
          end

          it "creates integration customer" do
            expect { service_call }.to change(IntegrationCustomers::NetsuiteCustomer, :count).by(1)
          end

          context "with anrok integration" do
            let(:integration) { create(:anrok_integration, organization:) }
            let(:params) do
              {
                integration_type: "anrok",
                integration_code:,
                sync_with_provider:,
                external_customer_id:
              }
            end

            it "creates integration customer" do
              expect { service_call }.to change(IntegrationCustomers::AnrokCustomer, :count).by(1)
            end
          end
        end
      end

      context "when sync with provider is false" do
        let(:sync_with_provider) { false }

        context "when customer external id is present" do
          let(:external_customer_id) { SecureRandom.uuid }

          it "does not calls aggregator create service" do
            service_call

            expect(Integrations::Aggregator::Contacts::CreateService).not_to have_received(:call)
          end

          it "creates integration customer" do
            expect { service_call }.to change(IntegrationCustomers::BaseCustomer, :count).by(1)
          end
        end

        context "when customer external id is not present" do
          let(:external_customer_id) { nil }

          it "does not calls aggregator create service" do
            service_call

            expect(Integrations::Aggregator::Contacts::CreateService).not_to have_received(:call)
          end

          it "does not create integration customer" do
            expect { service_call }.not_to change(IntegrationCustomers::BaseCustomer, :count)
          end
        end
      end
    end
  end
end
