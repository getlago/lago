# frozen_string_literal: true

class PaymentRequestMailerPreview < BasePreviewMailer
  def requested
    first_invoice = FactoryBot.create(:invoice, total_amount_cents: 1000, total_paid_amount_cents: 100)
    second_invoice = FactoryBot.create(:invoice, total_amount_cents: 2000, total_paid_amount_cents: 200)

    payment_request = FactoryBot.create(
      :payment_request,
      amount_cents: 2700,
      invoices: [first_invoice, second_invoice]
    )

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

    PaymentRequestMailer.with(payment_request:).requested
  end

  def requested_with_payment_url
    first_invoice = FactoryBot.create(:invoice, total_amount_cents: 1000)
    second_invoice = FactoryBot.create(:invoice, total_amount_cents: 2000)

    payment_request = FactoryBot.create(
      :payment_request,
      amount_cents: 3000,
      invoices: [first_invoice, second_invoice]
    )

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

    ::PaymentRequests::Payments::GeneratePaymentUrlService.class_eval do
      def self.call(payable:)
        BaseService::Result.new.tap do |result|
          result.payment_url = "https://stripe.com/payment_url"
        end
      end
    end

    PaymentRequestMailer.with(payment_request:).requested
  end
end
