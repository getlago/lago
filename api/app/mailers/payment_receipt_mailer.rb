# frozen_string_literal: true

class PaymentReceiptMailer < DocumentMailer
  before_action :ensure_pdf

  def document
    @document ||= params[:payment_receipt]
  end

  private

  def ensure_pdf
    PaymentReceipts::GeneratePdfService.new(payment_receipt: document).call

    invoices = document.payment.payable.is_a?(Invoice) ? [document.payment.payable] : document.payment.payable.invoices

    raise PaymentReceipts::FilesNotReadyError unless document.file.attached?
    raise PaymentReceipts::FilesNotReadyError unless invoices.all? { |invoice| invoice.file.attached? }
  end

  def create_mail
    @payment_receipt = document
    @billing_entity = document.billing_entity
    @customer = document.payment.payable.customer
    @show_lago_logo = !@billing_entity.organization.remove_branding_watermark_enabled?
    @total_due_amount = document.payment.payable.is_a?(Invoice) ?
      document.payment.payable.total_due_amount :
      document.payment.payable.amount - document.payment.amount

    recipients = params[:to].presence || [@customer.email].compact_blank
    return if @billing_entity.email.blank?
    return if recipients.empty?

    @invoices = if document.payment.payable.is_a?(Invoice)
      [document.payment.payable]
    else
      document.payment.payable.invoices
    end

    I18n.locale = @customer.preferred_document_locale

    if @pdfs_enabled
      document.file.open { |file| attachments["receipt-#{document.number}.pdf"] = file.read }

      @invoices.each do |invoice|
        invoice.file.open { |file| attachments["invoice-#{invoice.number}.pdf"] = file.read }
      end
    end

    I18n.with_locale(@customer.preferred_document_locale) do
      mail(
        to: recipients,
        cc: params[:cc],
        bcc: params[:bcc],
        from: email_address_with_name(@billing_entity.from_email_address, @billing_entity.name),
        reply_to: email_address_with_name(@billing_entity.email, @billing_entity.name),
        subject: I18n.t(
          "email.payment_receipt.created.subject",
          billing_entity_name: @billing_entity.name,
          payment_receipt_number: document.number
        )
      )
    end
  end
end
