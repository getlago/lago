# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::UpdateService do
  let(:integration) { create(:netsuite_integration, organization:) }

  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }

  describe "#call" do
    subject(:service_call) { described_class.call(params:, integration:, integration_customer:) }

    let(:params) do
      {
        integration_type: "netsuite",
        integration_code:,
        sync_with_provider:,
        external_customer_id:,
        subsidiary_id:
      }
    end

    let(:subsidiary_id) { "1111" }
    let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }

    before { integration_customer }

    context "with netsuite premium integration present", :premium do
      let(:integration_code) { integration.code }
      let(:external_customer_id) { nil }
      let(:sync_with_provider) { true }
      let(:contact_id) { SecureRandom.uuid }
      let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }

      let(:update_result) do
        result = BaseService::Result.new
        result.contact_id = contact_id
        result
      end

      before do
        organization.update!(premium_integrations: ["netsuite"])

        integration_customer

        allow(Integrations::Aggregator::Contacts::UpdateService)
          .to receive(:call).and_return(update_result)
      end

      context "when sync with provider is true" do
        let(:sync_with_provider) { true }

        context "when external customer id is present" do
          let(:external_customer_id) { SecureRandom.uuid }

          it "returns integration customer" do
            result = service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).to have_received(:call)
            expect(result).to be_success
            expect(result.integration_customer).to eq(integration_customer)
            expect(result.integration_customer.external_customer_id).to eq(external_customer_id)
          end
        end

        context "when subsidiary id is present" do
          it "returns integration customer" do
            result = service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).to have_received(:call)
            expect(result).to be_success
            expect(result.integration_customer).to eq(integration_customer)
          end
        end

        context "when customer external id is not present" do
          let(:external_customer_id) { nil }

          it "returns integration customer" do
            result = service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).to have_received(:call)
            expect(result).to be_success
            expect(result.integration_customer).to eq(integration_customer)
          end
        end

        context "with anrok customer" do
          let(:external_customer_id) { SecureRandom.uuid }
          let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

          it "does not calls aggregator update service" do
            service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).not_to have_received(:call)
          end

          it "does not update integration customer" do
            service_call

            expect(integration_customer.reload.external_customer_id).not_to eq(external_customer_id)
          end
        end

        context "with salesforce customer" do
          let(:external_customer_id) { SecureRandom.uuid }
          let(:integration) { create(:salesforce_integration, organization:) }
          let(:integration_customer) { create(:salesforce_customer, integration:, customer:) }

          it "does not calls aggregator update service" do
            service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).not_to have_received(:call)
          end

          it "does not update integration customer" do
            service_call

            expect(integration_customer.reload.external_customer_id).not_to eq(external_customer_id)
          end
        end
      end

      context "when sync with provider is false" do
        let(:sync_with_provider) { false }

        context "when customer external id is present" do
          let(:external_customer_id) { SecureRandom.uuid }

          it "calls aggregator update service" do
            service_call

            expect(Integrations::Aggregator::Contacts::UpdateService).to have_received(:call)
          end

          it "updates integration customer" do
            result = service_call

            expect(result.integration_customer.external_customer_id).to eq(external_customer_id)
          end
        end

        context "when customer external id is not present" do
          let(:external_customer_id) { nil }

          it "does not calls aggregator update service" do
            expect(Integrations::Aggregator::Contacts::UpdateService).not_to have_received(:call)
          end

          it "does not update integration customer" do
            result = service_call

            expect(result.integration_customer.external_customer_id).not_to eq(external_customer_id)
          end
        end
      end
    end
  end
end
