# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::CreateService do
  subject(:service_call) { described_class.call(integration:, customer:, subsidiary_id:) }

  let(:service) { described_class.new(integration:, customer:, subsidiary_id:) }
  let(:customer) { create(:customer, :with_same_billing_and_shipping_address, organization:) }
  let(:subsidiary_id) { "1" }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/#{integration_type}/contacts" }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => integration_type_key
    }
  end

  let(:customer_link) do
    url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

    URI.join(url, "/#{customer.organization.slug}/customer/", customer.id).to_s
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
  end

  describe "#call" do
    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when response is a string" do
        let(:integration) { create(:netsuite_integration, organization:) }
        let(:integration_type) { "netsuite" }
        let(:integration_type_key) { "netsuite-tba" }

        let(:params) do
          {
            "type" => "customer",
            "isDynamic" => true,
            "columns" => {
              "companyname" => customer.name,
              "isperson" => "F",
              "subsidiary" => subsidiary_id,
              "custentity_lago_id" => customer.id,
              "custentity_lago_sf_id" => customer.external_salesforce_id,
              "custentity_lago_customer_link" => customer_link,
              "email" => customer.email,
              "phone" => customer.phone,
              "entityid" => customer.external_id,
              "autoname" => false
            },
            "options" => {
              "ignoreMandatoryFields" => false
            },
            "lines" => [
              {
                "lineItems" => [
                  {
                    "defaultshipping" => true,
                    "defaultbilling" => true,
                    "subObjectId" => "addressbookaddress",
                    "subObject" => {
                      "addr1" => customer.address_line1,
                      "addr2" => customer.address_line2,
                      "city" => customer.city,
                      "zip" => customer.zipcode,
                      "state" => customer.state,
                      "country" => customer.country
                    }
                  }
                ],
                "sublistId" => "addressbook"
              }
            ]
          }
        end

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/contacts/success_string_response.json")
          File.read(path)
        end

        it "returns contact id" do
          result = service_call

          expect(result).to be_success
          expect(result.contact_id).to eq("1")
        end

        it "delivers a success webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.accounting_provider_created",
              customer
            ).on_queue(webhook_queue)
        end

        it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero
      end

      context "when response is a hash" do
        let(:integration) { create(:xero_integration, organization:) }
        let(:integration_type) { "xero" }
        let(:integration_type_key) { "xero" }

        let(:params) do
          [
            {
              "name" => customer.name,
              "firstname" => customer.firstname,
              "lastname" => customer.lastname,
              "email" => customer.email,
              "city" => customer.city,
              "zip" => customer.zipcode,
              "country" => customer.country,
              "state" => customer.state,
              "phone" => customer.phone
            }
          ]
        end

        context "when contact is succesfully created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/contacts/success_hash_response.json")
            File.read(path)
          end

          it "returns contact id" do
            result = service_call

            expect(result).to be_success
            expect(result.contact_id).to eq("2e50c200-9a54-4a66-b241-1e75fb87373f")
          end

          it "delivers a success webhook" do
            expect { service_call }.to enqueue_job(SendWebhookJob)
              .with(
                "customer.accounting_provider_created",
                customer
              ).on_queue(webhook_queue)
          end

          it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero
        end

        context "when contact is not created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/contacts/failure_hash_response.json")
            File.read(path)
          end

          it "does not return contact id" do
            result = service_call

            expect(result).to be_success
            expect(result.contact).to be(nil)
          end

          it "does not create integration resource object" do
            expect { service_call }.not_to change(IntegrationResource, :count)
          end

          it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero
        end
      end
    end

    context "when service call is not successful" do
      let(:integration) { create(:netsuite_integration, organization:) }
      let(:integration_type) { "netsuite" }
      let(:integration_type_key) { "netsuite-tba" }

      let(:params) do
        {
          "type" => "customer",
          "isDynamic" => true,
          "columns" => {
            "companyname" => customer.name,
            "isperson" => "F",
            "subsidiary" => subsidiary_id,
            "custentity_lago_id" => customer.id,
            "custentity_lago_sf_id" => customer.external_salesforce_id,
            "custentity_lago_customer_link" => customer_link,
            "email" => customer.email,
            "phone" => customer.phone,
            "entityid" => customer.external_id,
            "autoname" => false
          },
          "options" => {
            "ignoreMandatoryFields" => false
          },
          "lines" => [
            {
              "lineItems" => [
                {
                  "defaultshipping" => true,
                  "defaultbilling" => true,
                  "subObjectId" => "addressbookaddress",
                  "subObject" => {
                    "addr1" => customer.address_line1,
                    "addr2" => customer.address_line2,
                    "city" => customer.city,
                    "zip" => customer.zipcode,
                    "state" => customer.state,
                    "country" => customer.country
                  }
                }
              ],
              "sublistId" => "addressbook"
            }
          ]
        }
      end

      let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(http_error)
      end

      context "when it is a server error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
          File.read(path)
        end

        it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero

        [
          {
            ctx: "when the error is not handled specifically",
            payload: {
              error: "An unexpected error occurred"
            },
            code: "unexpected_error",
            message: "{\"error\":\"An unexpected error occurred\"}"
          },
          {
            ctx: "when error is nested in `error.payload`",
            payload: {
              error: {
                message: "The action script failed with an error: {}",
                code: "action_script_failure",
                payload: {
                  error: "Error starting integration 'netsuite-customer-create': {\n  \"name\": \"TRPCClientError\",\n  \"message\": \"fetch failed\"\n}"
                }
              }
            },
            code: "action_script_failure",
            message: "Error starting integration 'netsuite-customer-create': {\n  \"name\": \"TRPCClientError\",\n  \"message\": \"fetch failed\"\n}"
          },
          {
            ctx: "when error is nested in `error.payload.error`",
            payload: {
              integration: "netsuite-tba",
              action: "netsuite-create-contact",
              connection: "netsuite-tba-xyz",
              error: {
                message: "An error occurred during an HTTP call",
                payload: {
                  error: {
                    code: "INVALID_LOGIN_ATTEMPT",
                    message: "Invalid login attempt."
                  }
                }
              }
            },
            code: "INVALID_LOGIN_ATTEMPT",
            message: "Invalid login attempt."
          },
          {
            ctx: "when error is nested in `payload.message`",
            payload: {
              type: "action_script_runtime_error",
              payload: {
                message: "submitFields: Missing a required argument: type"
              }
            },
            code: "action_script_runtime_error",
            message: "submitFields: Missing a required argument: type"
          }
        ].each do |test_case|
          ctx, payload, code, message = test_case.values_at(:ctx, :payload, :code, :message)
          context ctx do
            let(:body) { payload.to_json }
            let(:error_code) { 500 }
            let(:result) { service_call }

            it "returns an error" do
              expect { result }.to enqueue_job(SendWebhookJob)
                .with(
                  "customer.accounting_provider_error",
                  customer,
                  provider: "netsuite",
                  provider_code: integration.code,
                  provider_error: {
                    message:,
                    error_code: code
                  }
                )

              expect(result).not_to be_success
              expect(result.error.code).to eq(code)
              expect(result.error.message).to eq("#{code}: #{message}")
            end
          end
        end
      end

      context "when it is a server payload error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }
        let(:code) { "TypeError" }
        let(:message) { "Please enter value(s) for: Company Name" }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_payload_response.json")
          File.read(path)
        end

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error.code).to eq(code)
          expect(result.error.message).to eq("#{code}: #{message}")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.accounting_provider_error",
              customer,
              provider: "netsuite",
              provider_code: integration.code,
              provider_error: {
                message:,
                error_code: code
              }
            )
        end

        it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero
      end

      context "when it is a client error" do
        let(:error_code) { 404 }
        let(:code) { "invalid_secret_key_format" }
        let(:message) { "Authentication failed. The provided secret key is not a UUID v4." }

        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_auth_response.json")
          File.read(path)
        end

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.error.code).to eq(code)
          expect(result.error.message).to eq("#{code}: #{message}")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.accounting_provider_error",
              customer,
              provider: "netsuite",
              provider_code: integration.code,
              provider_error: {
                message:,
                error_code: code
              }
            )
        end

        it_behaves_like "throttles!", :anrok, :hubspot, :netsuite, :xero
      end
    end
  end

  describe "#process_hash_result" do
    subject(:process_hash_result) { service.send(:process_hash_result, body) }

    let(:result) { service.instance_variable_get(:@result) }
    let(:integration) { create(:hubspot_integration, organization:) }
    let(:integration_type) { "hubspot" }
    let(:integration_type_key) { "hubspot" }

    before do
      allow(service).to receive(:deliver_error_webhook)
    end

    context "when contact is successfully created" do
      let(:body) do
        {
          "succeededContacts" => [
            {
              "id" => "2e50c200-9a54-4a66-b241-1e75fb87373f",
              "email" => "billing@example.com"
            }
          ]
        }
      end

      it "sets the contact_id and email in the result" do
        process_hash_result

        expect(result.contact_id).to eq("2e50c200-9a54-4a66-b241-1e75fb87373f")
        expect(result.email).to eq("billing@example.com")
      end
    end

    context "when contact creation fails" do
      let(:body) do
        {
          "failedContacts" => [
            {
              "validation_errors" => [
                {"Message" => "Email is invalid"},
                {"Message" => "Name is required"}
              ]
            }
          ]
        }
      end

      it "delivers an error webhook" do
        process_hash_result

        expect(service).to have_received(:deliver_error_webhook).with(
          customer:,
          code: "Validation error",
          message: "Email is invalid. Name is required"
        )
      end
    end

    context "when there is a general error" do
      let(:body) do
        {
          "error" => {
            "payload" => {
              "message" => "An unexpected error occurred"
            }
          }
        }
      end

      it "delivers an error webhook" do
        process_hash_result

        expect(service).to have_received(:deliver_error_webhook).with(
          customer:,
          code: "Validation error",
          message: "An unexpected error occurred"
        )
      end
    end
  end
end
