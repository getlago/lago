# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::CreateOrUpdateBatchService do
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }
  let(:subsidiary_id) { "1" }
  let(:integration_customers) do
    [
      {
        integration_type: "netsuite",
        integration_code:,
        sync_with_provider:,
        external_customer_id:,
        subsidiary_id:
      }
    ]
  end

  describe "#call" do
    subject(:service_call) { described_class.call(integration_customers:, customer:, new_customer:) }

    context "without integration" do
      let(:integration_code) { "not_exists" }
      let(:sync_with_provider) { true }
      let(:external_customer_id) { nil }
      let(:new_customer) { true }

      it "does not call create job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::CreateJob)
      end

      it "does not call update job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::UpdateJob)
      end
    end

    context "without customer" do
      let(:integration_code) { integration.code }
      let(:sync_with_provider) { true }
      let(:external_customer_id) { nil }
      let(:new_customer) { true }
      let(:customer) { nil }

      it "does not call create job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::CreateJob)
      end

      it "does not call update job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::UpdateJob)
      end
    end

    context "without external fields set" do
      let(:integration_code) { integration.code }
      let(:sync_with_provider) { false }
      let(:external_customer_id) { nil }
      let(:new_customer) { true }

      it "does not call create job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::CreateJob)
      end

      it "does not call update job" do
        expect { service_call }.not_to have_enqueued_job(IntegrationCustomers::UpdateJob)
      end
    end

    context "when removing integration customer" do
      let(:integration_customer) { create(:netsuite_customer, customer:, integration:) }
      let(:integration_customers) { [] }
      let(:new_customer) { false }

      before do
        IntegrationCustomers::BaseCustomer.destroy_all

        integration_customer
      end

      it "removes integration customer object" do
        service_call

        expect(IntegrationCustomers::BaseCustomer.count).to eq(0)
      end

      context "with existing integration customers that should be removed and updating ones" do
        let(:integration_anrok) { create(:anrok_integration, organization:) }
        let(:anrok_customer) { create(:anrok_customer, customer:, integration: integration_anrok) }
        let(:integration_customers) do
          [
            {
              id: anrok_customer.id,
              integration_type: "anrok",
              integration_code: integration_anrok.code,
              sync_with_provider: true,
              external_customer_id: nil
            }
          ]
        end

        before { anrok_customer }

        it "calls update job" do
          expect { service_call }.to have_enqueued_job(IntegrationCustomers::UpdateJob)
        end

        it "removes netsuite integration customer" do
          service_call

          expect(IntegrationCustomers::BaseCustomer.count).to eq(1)
        end
      end

      context "with existing integration customers that should be removed and new ones" do
        let(:integration_anrok) { create(:anrok_integration, organization:) }
        let(:integration_customers) do
          [
            {
              integration_type: "anrok",
              integration_code: integration_anrok.code,
              sync_with_provider: true,
              external_customer_id: nil
            }
          ]
        end

        it "calls create job" do
          expect { service_call }.to have_enqueued_job(IntegrationCustomers::CreateJob)
        end

        it "removes netsuite integration customer" do
          service_call

          expect(IntegrationCustomers::BaseCustomer.count).to eq(0)
        end
      end
    end

    context "when updating integration customer" do
      let(:integration_customer) { create(:netsuite_customer, customer:, integration:) }
      let(:integration_code) { integration.code }
      let(:sync_with_provider) { true }
      let(:external_customer_id) { "12345" }
      let(:new_customer) { false }

      before do
        integration_customer
        integration_customers.first[:id] = integration_customer.id
      end

      it "calls update job" do
        expect { service_call }.to have_enqueued_job(IntegrationCustomers::UpdateJob)
      end

      it "does not remove any integration customers" do
        service_call

        expect(IntegrationCustomers::BaseCustomer.count).to eq(1)
      end
    end

    context "when creating integration customer" do
      let(:integration_code) { integration.code }
      let(:sync_with_provider) { true }
      let(:external_customer_id) { nil }
      let(:new_customer) { true }

      let(:integration_two) { create(:netsuite_integration, organization: organization_two, code: integration.code) }
      let(:organization_two) { create(:organization) }

      before { integration_two }

      it "calls create job" do
        expect do
          service_call
        end.to have_enqueued_job(IntegrationCustomers::CreateJob).with(hash_including(integration:))
      end

      context "when updating existing customer without integration customer" do
        let(:new_customer) { false }

        it "calls create job" do
          expect { service_call }.to have_enqueued_job(IntegrationCustomers::CreateJob)
        end
      end

      context "with multiple integration customers" do
        let(:integration_anrok) { create(:anrok_integration, organization:) }
        let(:integration_customers) do
          [
            {
              integration_type: "netsuite",
              integration_code:,
              sync_with_provider:,
              external_customer_id:,
              subsidiary_id:
            },
            {
              integration_type: "anrok",
              integration_code: integration_anrok.code,
              sync_with_provider: true,
              external_customer_id: nil
            }
          ]
        end

        it "calls create job" do
          expect { service_call }.to have_enqueued_job(IntegrationCustomers::CreateJob).exactly(:twice)
        end
      end

      context "when adding one new integration customer" do
        let(:integration_anrok) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:netsuite_customer, customer:, integration:) }
        let(:new_customer) { false }

        let(:integration_customers) do
          [
            {
              id: integration_customer.id,
              integration_type: "netsuite",
              integration_code:,
              sync_with_provider:,
              external_customer_id:,
              subsidiary_id:
            },
            {
              integration_type: "anrok",
              integration_code: integration_anrok.code,
              sync_with_provider: true,
              external_customer_id: nil
            }
          ]
        end

        before do
          integration_anrok

          IntegrationCustomers::BaseCustomer.destroy_all

          integration_customer
        end

        it "calls create job" do
          expect { service_call }.to have_enqueued_job(IntegrationCustomers::CreateJob).exactly(:once)
        end
      end

      context "when adding a sync integration customer" do
        let(:integration_salesforce) { create(:salesforce_integration, organization:) }
        let(:integration_customers) do
          [
            {
              integration_type: "salesforce",
              integration_code: integration_salesforce.code,
              sync_with_provider: true,
              external_customer_id: "12345"
            }
          ]
        end

        before do
          IntegrationCustomers::BaseCustomer.destroy_all
        end

        it "processes the job immediately" do
          expect { service_call }.to change(IntegrationCustomers::BaseCustomer, :count).by(1).and(not_have_enqueued_job(IntegrationCustomers::CreateJob))
        end
      end
    end
  end
end
