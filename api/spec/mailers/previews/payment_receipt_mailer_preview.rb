# frozen_string_literal: true

class PaymentReceiptMailerPreview < BasePreviewMailer
  def created
    payment = FactoryBot.create(:payment)
    payment_receipt = FactoryBot.create(
      :payment_receipt,
      payment:,
      organization: payment.payable.organization
    )

    payment_receipt.file.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
      filename: "receipt.pdf",
      content_type: "application/pdf"
    )

    payment_receipt.payment.payable.file.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
      filename: "invoice.pdf",
      content_type: "application/pdf"
    )

    PaymentReceiptMailer.with(payment_receipt:).created
  end
end
