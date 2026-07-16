# frozen_string_literal: true

class CreditNoteMailer < DocumentMailer
  before_action :ensure_pdf

  def document
    @document ||= params[:credit_note]
  end

  private

  def ensure_pdf
    CreditNotes::GeneratePdfService.call(credit_note: document)
  end

  def create_mail
    @credit_note = document
    @customer = document.customer
    @billing_entity = document.billing_entity
    @show_lago_logo = !@billing_entity.organization.remove_branding_watermark_enabled?

    recipients = params[:to].presence || [@customer.email].compact_blank
    return if @billing_entity.email.blank?
    return if recipients.empty?

    if @pdfs_enabled
      document.file.open do |file|
        attachments["credit_note-#{document.number}.pdf"] = file.read
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
          "email.credit_note.created.subject",
          billing_entity_name: @billing_entity.name,
          credit_note_number: document.number
        )
      )
    end
  end
end
