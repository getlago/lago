# frozen_string_literal: true

class DocumentMailer < ApplicationMailer
  def loggable?
    true
  end

  def log(**context)
    super(document:, message: created, **context) if created.present? && document.present?
  end

  def created
    @created ||= create_mail
  end

  def document
  end
end
