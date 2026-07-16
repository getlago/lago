# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequestMailer do
  subject(:mailer) { described_class.with(payment_request:).requested }

  let(:organization) { create(:organization, document_number_prefix: "ORG-123B") }
  let(:billing_entity) { organization.default_billing_entity }
  let(:customer) { create(:customer, organization:) }
  let(:first_invoice) { create(:invoice, total_amount_cents: 1000, total_paid_amount_cents: 1, organization:, customer:) }
  let(:second_invoice) { create(:invoice, total_amount_cents: 2000, total_paid_amount_cents: 2, organization:, customer:) }
  let(:payment_request) { create(:payment_request, organization:, invoices: [first_invoice, second_invoice], customer:) }

  before do
    first_invoice.file.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
      filename: "invoice.pdf",
      content_type: "application/pdf"
    )
    second_invoice.file.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
      filename: "invoice.pdf",
      content_type: "application/pdf"
    )
  end

  describe "#requested" do
    let(:payment_url) { Faker::Internet.url }
    let(:payment_url_result) do
      BaseService::Result.new.tap do |result|
        result.payment_url = payment_url
      end
    end

    before do
      allow(::PaymentRequests::Payments::GeneratePaymentUrlService)
        .to receive(:call)
        .and_return(payment_url_result)
    end

    specify do
      expect(mailer.to).to eq([payment_request.email])
      expect(mailer.reply_to).to eq([payment_request.billing_entity.email])
      expect(mailer.bcc).to be_nil
      expect(mailer.body.encoded).to include(CGI.escapeHTML(first_invoice.number))
      expect(mailer.body.encoded).to include(CGI.escapeHTML(second_invoice.number))
      expect(mailer.body.encoded).to include(CGI.escapeHTML(MoneyHelper.format(first_invoice.total_due_amount)))
      expect(mailer.body.encoded).to include(CGI.escapeHTML(MoneyHelper.format(second_invoice.total_due_amount)))
    end

    it "calls the generate payment url service" do
      parsed_body = Nokogiri::HTML(mailer.body.encoded)

      expect(parsed_body.at_css("a#payment_link")["href"]).to eq(payment_url)
      expect(mailer.body.encoded).to include("Pay balance")
      expect(PaymentRequests::Payments::GeneratePaymentUrlService)
        .to have_received(:call)
        .with(payable: payment_request)
    end

    context "when payment request has dunning campaign attached and there are 2 addresses in bcc_emails" do
      let(:bcc_emails) { %w[bcc1@example.com bcc2@example.com] }
      let(:dunning_campaign) { create(:dunning_campaign, organization:, bcc_emails:) }

      before do
        payment_request.update!(dunning_campaign:)
      end

      it "includes the BCC email addresses in the mailer" do
        expect(mailer.bcc).to match_array(bcc_emails)
      end
    end

    context "when payment request email is nil" do
      before { payment_request.update!(email: nil) }

      it "returns a mailer with nil values" do
        expect(mailer.to).to be_nil
      end
    end

    context "when billing_entity email is nil" do
      before { billing_entity.update!(email: nil) }

      it "returns a mailer with nil values" do
        expect(mailer.to).to be_nil
      end
    end

    context "when no payment url is available" do
      let(:payment_url_result) do
        BaseService::Result.new.tap do |result|
          result.single_validation_failure!(error_code: "invalid_payment_provider")
        end
      end

      it "does not include the payment link" do
        parsed_body = Nokogiri::HTML(mailer.body.encoded)

        expect(parsed_body.css("a#payment_link")).not_to be_present
        expect(mailer.body.encoded).not_to include("Pay balance")
      end
    end
  end
end
