# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Hubspot::CreateService do
  subject(:service_call) { service.call }

  let(:service) { described_class.new(subscription:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:plan) { create(:plan, organization:) }
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:lago_properties_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/hubspot/records" }
  let(:properties_endpoint) { "https://api.nango.dev/v1/hubspot/properties" }
  let(:subscription_file_url) { subscription.file_url }
  let(:file_url) { Faker::Internet.url }
  let(:due_date) { subscription.payment_due_date.strftime("%Y-%m-%d") }
  let(:params) { service.__send__(:payload).create_body }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "hubspot"
    }
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(LagoHttpClient::Client).to receive(:new)
      .with(properties_endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_properties_client)

    integration_customer
    integration.sync_subscriptions = true
    integration.save!
  end

  describe "#call_async" do
    subject(:service_call_async) { described_class.new(subscription:).call_async }

    context "when subscription exists" do
      it "enqueues subscription create job" do
        expect { service_call_async }.to enqueue_job(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
      end
    end

    context "when subscription does not exist" do
      let(:subscription) { nil }

      it "returns an error" do
        result = service_call_async

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("subscription_not_found")
      end
    end
  end

  describe "#call" do
    context "when sync_subscriptions is false" do
      before { integration.update!(sync_subscriptions: false) }

      it "does not return external id" do
        result = service_call

        expect(result).to be_success
        expect(result.external_id).to be(nil)
      end

      it "does not create integration resource object" do
        expect { service_call }.not_to change(IntegrationResource, :count)
      end
    end

    context "when sync_subscriptions is true" do
      context "when service call is successful" do
        let(:response) { instance_double(Net::HTTPOK) }

        before do
          allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
          allow(lago_properties_client).to receive(:post_with_response)
          allow(response).to receive(:body).and_return(body)
        end

        context "when subscription is succesfully created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/subscriptions/hubspot/success_hash_response.json")
            File.read(path)
          end

          it "returns external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to eq("123456789123")
          end

          it "creates integration resource object" do
            expect { service_call }.to change(IntegrationResource, :count).by(1)

            integration_resource = IntegrationResource.order(created_at: :desc).first

            expect(integration_resource.syncable_id).to eq(subscription.id)
            expect(integration_resource.syncable_type).to eq("Subscription")
            expect(integration_resource.resource_type).to eq("subscription")
          end

          it_behaves_like "throttles!", :hubspot
        end

        context "when subscription is not created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/subscriptions/hubspot/failure_hash_response.json")
            File.read(path)
          end

          it "does not return external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to be(nil)
          end

          it "does not create integration resource object" do
            expect { service_call }.not_to change(IntegrationResource, :count)
          end

          it_behaves_like "throttles!", :hubspot
        end
      end

      context "when service call is not successful" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
          File.read(path)
        end

        let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

        before do
          allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(http_error)
          allow(lago_properties_client).to receive(:post_with_response)
        end

        context "when it is a server error" do
          let(:error_code) { Faker::Number.between(from: 500, to: 599) }

          it "does not return an error" do
            expect { service_call }.not_to raise_error
          end

          it "enqueues a SendWebhookJob" do
            expect { service_call }.to have_enqueued_job(SendWebhookJob)
          end

          it_behaves_like "throttles!", :hubspot
        end

        context "when it is a client error" do
          let(:error_code) { Faker::Number.between(from: 400, to: 499) }

          it "does not return an error" do
            expect { service_call }.not_to raise_error
          end

          it "returns result" do
            expect(service_call).to be_a(BaseService::Result)
          end

          it "enqueues a SendWebhookJob" do
            expect { service_call }.to have_enqueued_job(SendWebhookJob)
          end

          it_behaves_like "throttles!", :hubspot
        end
      end
    end
  end
end
