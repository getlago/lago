# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::Hubspot do
  let(:payload) { described_class.new(integration_customer:, invoice:) }
  let(:integration_customer) { FactoryBot.create(:hubspot_customer, integration:, customer:) }
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:file_url) { Faker::Internet.url }
  let(:invoice_url) do
    url = ENV["LAGO_FRONT_URL"].presence || "https://app.getlago.com"

    URI.join(url, "/#{customer.organization.slug}/customer/#{customer.id}/", "invoice/#{invoice.id}/overview").to_s
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 200,
      issuing_date: DateTime.new(2024, 7, 8)
    )
  end

  let(:integration_invoice) do
    create(:integration_resource, integration:, resource_type: "invoice", syncable: invoice)
  end

  before do
    integration_invoice
    allow(invoice).to receive(:file_url).and_return(file_url)
  end

  describe "#create_body" do
    subject(:body_call) { payload.create_body }

    let(:create_body) do
      {
        "objectType" => integration.invoices_object_type_id,
        "input" => {
          "associations" => [],
          "properties" => {
            "lago_invoice_id" => invoice.id,
            "lago_invoice_number" => invoice.number,
            "lago_invoice_purchase_order_number" => invoice.purchase_order_number,
            "lago_invoice_issuing_date" => invoice.issuing_date.strftime("%Y-%m-%d"),
            "lago_invoice_payment_due_date" => invoice.payment_due_date.strftime("%Y-%m-%d"),
            "lago_invoice_payment_overdue" => invoice.payment_overdue,
            "lago_invoice_type" => invoice.invoice_type,
            "lago_invoice_status" => invoice.status,
            "lago_invoice_payment_status" => invoice.payment_status,
            "lago_invoice_currency" => invoice.currency,
            "lago_invoice_total_amount" => invoice.total_amount_cents / 100.0,
            "lago_invoice_total_due_amount" => invoice.total_due_amount_cents / 100.0,
            "lago_invoice_subtotal_excluding_taxes" => invoice.sub_total_including_taxes_amount_cents / 100.0,
            "lago_invoice_file_url" => invoice.file_url,
            "lago_invoice_url" => invoice_url
          }
        }
      }
    end

    it "returns payload body" do
      expect(subject).to eq(create_body)
    end

    context "when invoice file_url is missing" do
      before { allow(invoice).to receive(:file_url).and_return(nil) }

      it "raises an error" do
        expect { subject }.to raise_error(Integrations::Aggregator::BasePayload::Failure, "invoice.file_url missing")
      end
    end
  end

  describe "#update_body" do
    subject(:body_call) { payload.update_body }

    let(:update_body) do
      {
        "objectId" => integration_invoice.external_id,
        "objectType" => integration.invoices_object_type_id,
        "input" => {
          "properties" => {
            "lago_invoice_id" => invoice.id,
            "lago_invoice_number" => invoice.number,
            "lago_invoice_purchase_order_number" => invoice.purchase_order_number,
            "lago_invoice_issuing_date" => invoice.issuing_date.strftime("%Y-%m-%d"),
            "lago_invoice_payment_due_date" => invoice.payment_due_date.strftime("%Y-%m-%d"),
            "lago_invoice_payment_overdue" => invoice.payment_overdue,
            "lago_invoice_type" => invoice.invoice_type,
            "lago_invoice_status" => invoice.status,
            "lago_invoice_payment_status" => invoice.payment_status,
            "lago_invoice_currency" => invoice.currency,
            "lago_invoice_total_amount" => invoice.total_amount_cents / 100.0,
            "lago_invoice_total_due_amount" => invoice.total_due_amount_cents / 100.0,
            "lago_invoice_subtotal_excluding_taxes" => invoice.sub_total_including_taxes_amount_cents / 100.0,
            "lago_invoice_file_url" => invoice.file_url,
            "lago_invoice_url" => invoice_url
          }
        }
      }
    end

    it "returns payload body" do
      expect(subject).to eq(update_body)
    end

    context "when invoice file_url is missing" do
      before { allow(invoice).to receive(:file_url).and_return(nil) }

      it "raises an error" do
        expect { subject }.to raise_error(Integrations::Aggregator::BasePayload::Failure, "invoice.file_url missing")
      end
    end
  end

  describe "#customer_association_body" do
    subject(:body_call) { payload.customer_association_body }

    let(:customer_association_body) do
      {
        "objectType" => integration.invoices_object_type_id,
        "objectId" => integration_invoice.external_id,
        "toObjectType" => integration_customer.object_type,
        "toObjectId" => integration_customer.external_customer_id,
        "input" => []
      }
    end

    it "returns payload body" do
      expect(subject).to eq(customer_association_body)
    end
  end
end
