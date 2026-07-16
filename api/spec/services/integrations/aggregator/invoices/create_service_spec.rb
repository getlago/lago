# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::CreateService do
  subject(:service_call) { described_class.call(invoice:) }

  let(:service) { described_class.new(invoice:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/netsuite/invoices" }
  let(:add_on) { create(:add_on, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, billable_metric:) }
  let(:current_time) { Time.current }

  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:integration_collection_mapping2) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :coupon,
      settings: {external_id: "2", external_account_code: "22", external_name: ""}
    )
  end
  let(:integration_collection_mapping3) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :subscription_fee,
      settings: {external_id: "3", external_account_code: "33", external_name: ""}
    )
  end
  let(:integration_collection_mapping4) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :minimum_commitment,
      settings: {external_id: "4", external_account_code: "44", external_name: ""}
    )
  end
  let(:integration_collection_mapping5) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :tax,
      settings: {external_id: "5", external_account_code: "55", external_name: ""}
    )
  end
  let(:integration_collection_mapping6) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :prepaid_credit,
      settings: {external_id: "6", external_account_code: "66", external_name: ""}
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
  let(:integration_mapping_bm) do
    create(
      :netsuite_mapping,
      integration:,
      mappable_type: "BillableMetric",
      mappable_id: billable_metric.id,
      settings: {external_id: "m2", external_account_code: "m22", external_name: ""}
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 8000
    )
  end
  let(:fee_sub) do
    create(
      :fee,
      invoice:,
      created_at: current_time - 3.seconds
    )
  end
  let(:minimum_commitment_fee) do
    create(
      :minimum_commitment_fee,
      invoice:,
      created_at: current_time - 2.seconds
    )
  end
  let(:charge_fee) do
    create(
      :charge_fee,
      invoice:,
      charge:,
      units: 2,
      precise_unit_amount: 4.12121212123337777,
      created_at: current_time
    )
  end

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "netsuite-tba"
    }
  end

  let(:invoice_url) do
    url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

    URI.join(url, "/#{invoice.customer.organization.slug}/customer/#{invoice.customer.id}/", "invoice/#{invoice.id}/overview").to_s
  end

  let(:due_date) { invoice.payment_due_date.strftime("%-m/%-d/%Y") }
  let(:issuing_date) { invoice.issuing_date.strftime("%-m/%-d/%Y") }

  let(:params) do
    {
      "type" => "invoice",
      "isDynamic" => true,
      "columns" => {
        "tranid" => invoice.number,
        "taxregoverride" => true,
        "taxdetailsoverride" => true,
        "entity" => integration_customer.external_customer_id,
        "custbody_lago_id" => invoice.id,
        "custbody_ava_disable_tax_calculation" => true,
        "custbody_lago_invoice_link" => invoice_url,
        "trandate" => anything,
        "duedate" => due_date,
        "lago_plan_codes" => invoice.invoice_subscriptions.map(&:subscription).map(&:plan).map(&:code).join(",")
      },
      "lines" => [
        {
          "sublistId" => "item",
          "lineItems" => [
            {
              "item" => "3",
              "account" => "33",
              "quantity" => 0.0,
              "rate" => 0.0,
              "amount" => 2.0,
              "taxdetailsreference" => anything,
              "custcol_service_period_date_from" => anything,
              "custcol_service_period_date_to" => anything,
              "description" => anything,
              "item_source" => anything
            },
            {
              "item" => "4",
              "account" => "44",
              "quantity" => 0.0,
              "rate" => 0.0,
              "amount" => 2.0,
              "taxdetailsreference" => anything,
              "custcol_service_period_date_from" => anything,
              "custcol_service_period_date_to" => anything,
              "description" => anything,
              "item_source" => anything
            },
            {
              "item" => "m2",
              "account" => "m22",
              "quantity" => 2,
              "rate" => 4.1212121212334,
              "amount" => 2.0,
              "taxdetailsreference" => anything,
              "custcol_service_period_date_from" => anything,
              "custcol_service_period_date_to" => anything,
              "description" => anything,
              "item_source" => anything
            },
            {
              "item" => "2",
              "account" => "22",
              "quantity" => 1,
              "rate" => -20.0,
              "taxdetailsreference" => "coupon_item",
              "description" => anything,
              "item_source" => anything
            },
            {
              "item" => "6",
              "account" => "66",
              "quantity" => 1,
              "rate" => -40.0,
              "taxdetailsreference" => "credit_item",
              "description" => anything,
              "item_source" => anything
            },
            {
              "item" => "1", # Fallback item instead of credit note
              "account" => "11",
              "quantity" => 1,
              "rate" => -60.0,
              "taxdetailsreference" => "credit_note_item",
              "description" => anything,
              "item_source" => anything
            }
          ]
        }
      ],
      "options" => {
        "ignoreMandatoryFields" => false,
        "fullInvoicePayload" => {
          "invoice_payload" => hash_including(
            lago_id: invoice.id,
            billing_entity_code: anything,
            sequential_id: invoice.sequential_id,
            number: invoice.number,
            issuing_date: invoice.issuing_date&.iso8601,
            payment_due_date: invoice.payment_due_date&.iso8601,
            net_payment_term: invoice.net_payment_term,
            invoice_type: invoice.invoice_type,
            status: invoice.status,
            payment_status: invoice.payment_status,
            currency: invoice.currency,
            fees_amount_cents: invoice.fees_amount_cents,
            taxes_amount_cents: invoice.taxes_amount_cents,
            coupons_amount_cents: invoice.coupons_amount_cents,
            credit_notes_amount_cents: invoice.credit_notes_amount_cents,
            prepaid_credit_amount_cents: invoice.prepaid_credit_amount_cents,
            total_amount_cents: invoice.total_amount_cents,
            total_due_amount_cents: invoice.total_due_amount_cents,
            version_number: invoice.version_number,
            self_billed: invoice.self_billed,
            customer: hash_including(
              lago_id: customer.id,
              external_id: customer.external_id,
              name: customer.name,
              integration_customers: anything
            ),
            fees: invoice.fees.map do |fee|
              hash_including(
                lago_id: fee.id,
                lago_invoice_id: fee.invoice_id,
                lago_subscription_id: fee.subscription_id,
                lago_customer_id: fee.customer&.id,
                amount_cents: fee.amount_cents,
                amount_currency: fee.amount_currency,
                taxes_amount_cents: fee.taxes_amount_cents,
                total_amount_cents: fee.total_amount_cents,
                units: fee.units,
                precise_unit_amount: fee.precise_unit_amount,
                item: hash_including(
                  type: fee.fee_type,
                  code: fee.item_code,
                  name: fee.item_name
                )
              )
            end,
            credits: anything,
            metadata: anything,
            applied_taxes: anything,
            billing_periods: anything
          )
        }
      }
    }
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)

    integration_customer
    charge
    integration_collection_mapping1
    integration_collection_mapping2
    integration_collection_mapping3
    integration_collection_mapping4
    integration_collection_mapping5
    integration_collection_mapping6
    integration_mapping_add_on
    integration_mapping_bm
    fee_sub
    minimum_commitment_fee
    charge_fee

    integration.sync_invoices = true
    integration.save!
  end

  describe "#call_async" do
    subject(:service_call_async) { described_class.new(invoice:).call_async }

    context "when invoice exists" do
      it "enqueues invoice create job with find_first: false by default" do
        expect { service_call_async }
          .to enqueue_job(Integrations::Aggregator::Invoices::CreateJob)
          .with(invoice:, find_first: false)
      end

      context "when find_first: true is passed" do
        subject(:service_call_async) { described_class.new(invoice:, find_first: true).call_async }

        it "forwards find_first: true to the job" do
          expect { service_call_async }
            .to enqueue_job(Integrations::Aggregator::Invoices::CreateJob)
            .with(invoice:, find_first: true)
        end
      end
    end

    context "when invoice does not exist" do
      let(:invoice) { nil }

      it "returns an error" do
        result = service_call_async

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end
  end

  describe "#call" do
    context "when integration_invoice exists" do
      let(:integration_invoice) { create(:integration_resource, integration:, syncable: invoice) }
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        integration_invoice
      end

      it "returns result without making an API call" do
        expect(lago_client).not_to have_received(:post_with_response)
        result = service_call

        expect(result).to be_success
        expect(result.external_id).to be_nil
      end
    end

    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when response is a hash" do
        context "when invoice is succesfully created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/invoices/success_hash_response.json")
            File.read(path)
          end

          it "returns external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to eq("cc1576cf-7b1c-480e-8f25-ae10fa34d6d1")
          end

          it "creates integration resource object" do
            expect { service_call }.to change(IntegrationResource, :count).by(1)

            integration_resource = IntegrationResource.order(created_at: :desc).first

            expect(integration_resource.syncable_id).to eq(invoice.id)
            expect(integration_resource.syncable_type).to eq("Invoice")
            expect(integration_resource.resource_type).to eq("invoice")
          end

          it_behaves_like "throttles!", :anrok, :netsuite, :xero
        end

        context "when invoice is not created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/invoices/failure_hash_response.json")
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

          it_behaves_like "throttles!", :anrok, :netsuite, :xero
        end
      end

      context "when response is a string" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/invoices/success_string_response.json")
          File.read(path)
        end

        it "returns external id" do
          result = service_call

          expect(result).to be_success
          expect(result.external_id).to eq("456")
        end

        it "creates integration resource object" do
          expect { service_call }
            .to change(IntegrationResource, :count).by(1)

          integration_resource = IntegrationResource.order(created_at: :desc).first

          expect(integration_resource.syncable_id).to eq(invoice.id)
          expect(integration_resource.syncable_type).to eq("Invoice")
          expect(integration_resource.resource_type).to eq("invoice")
        end

        it_behaves_like "throttles!", :anrok, :netsuite, :xero
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
      end

      context "when it is a server error" do
        let(:error_code) { 500 }

        it "returns an error" do
          expect do
            service_call
          end.to raise_error(http_error)
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob).and raise_error(http_error)
        end
      end

      context "when it is a client error" do
        let(:error_code) { 400 }

        it "does not raise an error" do
          expect { service_call }.not_to raise_error
        end

        it "returns a failure result" do
          result = service_call
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NonRetryableFailure)
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob)
        end
      end
    end

    context "when there is payload error" do
      let(:integration) { create(:xero_integration, organization:) }
      let(:integration_customer) { create(:xero_customer, integration:, customer:) }
      let(:lago_client) { instance_double(LagoHttpClient::Client) }
      let(:endpoint) { "https://api.nango.dev/v1/xero/invoices" }
      let(:integration_collection_mapping1) { nil }
      let(:integration_collection_mapping2) { nil }
      let(:integration_collection_mapping3) { nil }
      let(:integration_collection_mapping4) { nil }
      let(:integration_collection_mapping5) { nil }
      let(:integration_collection_mapping6) { nil }
      let(:integration_mapping_add_on) { nil }
      let(:integration_mapping_bm) { nil }
      let(:response) { instance_double(Net::HTTPOK) }
      let(:headers) do
        {
          "Connection-Id" => integration.connection_id,
          "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
          "Provider-Config-Key" => "xero"
        }
      end
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/invoices/success_hash_response.json")
        File.read(path)
      end

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      it "sends error webhook" do
        expect { service_call }.to have_enqueued_job(SendWebhookJob)
      end

      it "returns a failure result" do
        result = service_call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NonRetryableFailure)
      end

      it_behaves_like "throttles!", :anrok, :netsuite, :xero
    end
  end
end
