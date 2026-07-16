# frozen_string_literal: true

class InvoiceMailer < DocumentMailer
  before_action :ensure_pdf

  def document
    @document ||= params[:invoice]
  end

  private

  def ensure_pdf
    Invoices::GeneratePdfService.new(invoice: document).call
  end

  def create_mail
    @invoice = document
    @billing_entity = document.billing_entity
    @customer = document.customer
    @show_lago_logo = !@billing_entity.organization.remove_branding_watermark_enabled?

    recipients = params[:to].presence || [@customer.email].compact_blank
    return if @billing_entity.email.blank?
    return if recipients.empty?
    return if document.fees_amount_cents.zero?

    I18n.locale = @customer.preferred_document_locale

    if @pdfs_enabled
      document.file.open do |file|
        attachments["invoice-#{document.number}.pdf"] = file.read
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
          "email.invoice.finalized.subject",
          billing_entity_name: @billing_entity.name,
          invoice_number: document.number
        )
      )
    end
  end
end
