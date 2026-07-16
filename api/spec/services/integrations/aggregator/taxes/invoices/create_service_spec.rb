# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::Invoices::CreateService do
  subject(:service_call) { described_class.call(invoice:) }

  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:, external_customer_id: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
  let(:add_on) { create(:add_on, organization:) }
  let(:add_on_two) { create(:add_on, organization:) }
  let(:current_time) { Time.current }

  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:integration_mapping_add_on) do
    create(
      :netsuite_mapping,
      integration:,
      mappable_type: "AddOn",
      mappable_id: add_on.id,
      settings: {external_id: "m1", external_account_code: "m11", external_name: ""}
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:
    )
  end
  let(:fee_add_on) do
    create(
      :fee,
      invoice:,
      add_on:,
      created_at: current_time - 3.seconds
    )
  end
  let(:fee_add_on_two) do
    create(
      :fee,
      invoice:,
      add_on: add_on_two,
      created_at: current_time - 2.seconds
    )
  end

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "anrok"
    }
  end
  let(:response_status) { 200 }

  let(:params) do
    [
      {
        "issuing_date" => invoice.issuing_date.to_s,
        "currency" => invoice.currency,
        "contact" => {
          "external_id" => customer.external_id,
          "name" => customer.name,
          "address_line_1" => customer.address_line1,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "taxable" => false,
          "tax_number" => nil
        },
        "fees" => [
          {
            "item_key" => fee_add_on.item_key,
            "item_id" => fee_add_on.id,
            "item_code" => "m1",
            "amount_cents" => 200
          },
          {
            "item_key" => fee_add_on_two.item_key,
            "item_id" => fee_add_on_two.id,
            "item_code" => "1",
            "amount_cents" => 200
          }
        ],
        "tax_date" => invoice.issuing_date.to_s,
        "id" => invoice.id
      }
    ]
  end

  before do
    integration_customer
    integration_collection_mapping1
    integration_mapping_add_on
    fee_add_on
    fee_add_on_two

    stub_request(:post, endpoint).with(body: params.to_json, headers:)
      .and_return(status: response_status, body:)
  end

  describe "#call" do
    context "when service call is successful" do
      context "when taxes are successfully fetched for finalized invoice" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
          File.read(path)
        end

        it "returns fees" do
          result = service_call

          expect(result).to be_success
          expect(result.fees.first.tax_breakdown.first.rate).to eq("0.10")
          expect(result.fees.first.tax_breakdown.first.name).to eq("GST/HST")
          expect(result.fees.first.tax_breakdown.last.name).to eq("Reverse charge")
          expect(result.fees.first.tax_breakdown.last.type).to eq("exempt")
          expect(result.fees.first.tax_breakdown.last.rate).to eq("0.00")
        end

        it "sets integration customer external id" do
          service_call

          expect(integration_customer.reload.external_customer_id).to eq(customer.external_id)
        end

        it "does not create integration resource" do
          expect { service_call }.not_to change { invoice.reload.integration_resources.count }
        end
      end

      context "when Avalara taxes are successfully fetched for finalized invoice" do
        let(:integration) { create(:avalara_integration, organization:) }
        let(:integration_customer) { create(:avalara_customer, integration:, customer:, external_customer_id: "123") }
        let(:endpoint) { "https://api.nango.dev/v1/avalara/finalized_invoices" }
        let(:params) do
          [
            {
              "issuing_date" => invoice.issuing_date,
              "currency" => invoice.currency,
              "contact" => {
                "external_id" => "123",
                "name" => customer.name,
                "address_line_1" => customer.address_line1,
                "city" => customer.city,
                "zip" => customer.zipcode,
                "region" => customer.state,
                "country" => customer.country,
                "taxable" => false,
                "tax_number" => nil
              },
              "billing_entity" => {
                "address_line_1" => customer.billing_entity&.address_line1,
                "city" => customer.billing_entity&.city,
                "zip" => customer.billing_entity&.zipcode,
                "region" => customer.billing_entity&.state,
                "country" => customer.billing_entity&.country
              },
              "fees" => [
                {
                  "item_key" => fee_add_on.item_key,
                  "item_id" => fee_add_on.id,
                  "item_code" => "m1",
                  "unit" => "0.0",
                  "amount" => "2.0"
                },
                {
                  "item_key" => fee_add_on_two.item_key,
                  "item_id" => fee_add_on_two.id,
                  "item_code" => "1",
                  "unit" => "0.0",
                  "amount" => "2.0"
                }
              ],
              "id" => invoice.id,
              "type" => "salesInvoice"
            }
          ]
        end
        let(:headers) do
          {
            "Connection-Id" => integration.connection_id,
            "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
            "Provider-Config-Key" => "avalara-sandbox"
          }
        end
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
          File.read(path)
        end

        it "returns fees" do
          result = service_call

          expect(result).to be_success
          expect(result.fees.first.tax_breakdown.first.rate).to eq("0.10")
          expect(result.fees.first.tax_breakdown.first.name).to eq("GST/HST")
          expect(result.fees.first.tax_breakdown.last.name).to eq("Reverse charge")
          expect(result.fees.first.tax_breakdown.last.type).to eq("exempt")
          expect(result.fees.first.tax_breakdown.last.rate).to eq("0.00")
        end

        it "creates integration resource" do
          expect { service_call }.to change { invoice.reload.integration_resources.count }.by(1)
        end

        context "when invoice is voided" do
          let(:params) do
            [
              {
                "issuing_date" => invoice.issuing_date,
                "currency" => invoice.currency,
                "contact" => {
                  "external_id" => "123",
                  "name" => customer.name,
                  "address_line_1" => customer.address_line1,
                  "city" => customer.city,
                  "zip" => customer.zipcode,
                  "region" => customer.state,
                  "country" => customer.country,
                  "taxable" => false,
                  "tax_number" => nil
                },
                "billing_entity" => {
                  "address_line_1" => customer.billing_entity&.address_line1,
                  "city" => customer.billing_entity&.city,
                  "zip" => customer.billing_entity&.zipcode,
                  "region" => customer.billing_entity&.state,
                  "country" => customer.billing_entity&.country
                },
                "fees" => [
                  {
                    "item_key" => fee_add_on.item_key,
                    "item_id" => fee_add_on.id,
                    "item_code" => "m1",
                    "unit" => "0.0",
                    "amount" => "-2.0"
                  },
                  {
                    "item_key" => fee_add_on_two.item_key,
                    "item_id" => fee_add_on_two.id,
                    "item_code" => "1",
                    "unit" => "0.0",
                    "amount" => "-2.0"
                  }
                ],
                "id" => invoice.id,
                "type" => "returnInvoice"
              }
            ]
          end

          before { invoice.voided! }

          it "returns fees for valid request payload" do
            result = service_call

            expect(result).to be_success
          end
        end
      end

      context "when taxes are not successfully fetched for finalized invoice" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
          File.read(path)
        end

        it "does not return fees" do
          result = service_call

          expect(result).not_to be_success
          expect(result.fees).to be(nil)
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("taxDateTooFarInFuture")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.tax_provider_error",
              customer,
              provider: "anrok",
              provider_code: integration.code,
              provider_error: {
                message: "Service failure",
                error_code: "taxDateTooFarInFuture"
              }
            )
        end

        it "does not set integration customer external id" do
          service_call

          expect(integration_customer.reload.external_customer_id).to eq(nil)
        end

        context "when the body contains a bad gateway error" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/bad_gateway_error.html")
            File.read(path)
          end

          it "raises an HTTP error" do
            expect { service_call }.to raise_error(Integrations::Aggregator::BadGatewayError)
          end
        end

        context "when it is an out of memory error" do
          let(:body) do
            {"succeededInvoices" => [], "failedInvoices" => [{"validation_errors" => "function_runtime_out_of_memory"}]}.to_json
          end

          it "raises OutOfMemoryError" do
            expect { service_call }.to raise_error(Integrations::Aggregator::OutOfMemoryError)
          end
        end

        context "when it is a server contention error" do
          let(:body) do
            {"succeededInvoices" => [], "failedInvoices" => [{"validation_errors" => "API limit exceeded"}]}.to_json
          end

          it "raises ServerContentionError" do
            expect { service_call }.to raise_error(Integrations::Aggregator::ServerContentionError)
          end
        end
      end
    end

    context "when service call is not successful" do
      context "when the error code is 502" do
        let(:response_status) { 502 }
        let(:body) { "" }

        it "raises an HTTP error" do
          expect { service_call }.to raise_error(Integrations::Aggregator::BadGatewayError)
        end
      end

      context "when it is a server error" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
          File.read(path)
        end
        let(:response_status) { 500 }

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.fees).to be(nil)
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("action_script_runtime_error")
        end
      end

      context "when it is a task in progress error" do
        let(:response_status) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "Task abc12345-1234-1234-1234-abc123456789 is in progress"}}.to_json }

        it "raises TaskInProgressError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TaskInProgressError)
        end
      end

      context "when it is a task expired error" do
        let(:response_status) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "Task abc12345-1234-1234-1234-abc123456789 expired"}}.to_json }

        it "raises TaskExpiredError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TaskExpiredError)
        end
      end

      context "when it is an orchestrator failure error" do
        let(:response_status) { 500 }
        let(:body) { {error: {code: "action_script_failure", message: "POST http://nango-orchestrator-svc.nango/v1/immediate failed"}}.to_json }

        it "raises OrchestratorFailureError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::OrchestratorFailureError)
        end
      end

      context "when a network timeout occurs" do
        let(:body) { "" }

        before { stub_request(:post, endpoint).to_raise(Net::ReadTimeout) }

        it "raises TimeoutError" do
          expect { service_call }.to raise_error(Integrations::Aggregator::TimeoutError)
        end
      end
    end
  end
end
