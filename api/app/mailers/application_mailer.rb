# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  self.delivery_job = SendEmailJob

  before_action :set_shared_variables

  def set_shared_variables
    @show_lago_logo = true
    @lago_logo_url = "https://assets.getlago.com/lago-logo-email.png"
    @pdfs_enabled = !ActiveModel::Type::Boolean.new.cast(ENV["LAGO_DISABLE_PDF_GENERATION"])
  end

  # Shared interface for logging purposes

  # Define if sending this email should be logged
  def loggable?
    false
  end

  def log(**options)
    Utils::EmailActivityLog.produce(**options) if loggable?
  end
end
