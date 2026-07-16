# frozen_string_literal: true

# Custom mail delivery job to support activity logging for email events in ClickHouse.
#
# == Usage scenarios
#
# The job accepts optional params that control how the email event is logged:
#
# 1. Automatic/scheduled sending (activity_source: :system)
#    When the system sends emails automatically (e.g., invoice finalization):
#
#      InvoiceMailer.with(invoice:).created.deliver_later
#
# 2. Resend from UI by a user (activity_source: :front)
#    When a user manually resends an email from the frontend:
#
#      InvoiceMailer.with(
#        invoice:,
#        resend: true,
#        user_id: current_user.id
#      ).created.deliver_later
#
# 3. API-triggered sending (activity_source: :api)
#    When email is triggered via API request:
#
#      CreditNoteMailer.with(
#        credit_note:,
#        api_key_id: CurrentContext.api_key_id
#      ).created.deliver_later
#
class SendEmailJob < ActionMailer::MailDeliveryJob
  queue_as "mailers"

  after_perform :log

  retry_on ActiveJob::DeserializationError, wait: :polynomially_longer, attempts: 6
  retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 6
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 6
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 6
  retry_on EOFError, wait: :polynomially_longer, attempts: 6
  retry_on Net::SMTPServerBusy, wait: :polynomially_longer, attempts: 25
  retry_on PaymentReceipts::FilesNotReadyError, wait: :polynomially_longer, attempts: 8

  after_discard { |job, error| job.log(error:) }

  def perform(mailer_name, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    @log_options = params&.extract!(:user_id, :api_key_id, :resend).to_h.compact

    mailer_class = params ? mailer_name.constantize.with(params) : mailer_name.constantize
    message = if kwargs
      mailer_class.public_send(mail_method, *args, **kwargs)
    else
      mailer_class.public_send(mail_method, *args)
    end

    # We have to reload the whole method `ActionMailer::MailDeliveryJob::perform`
    # to have access to the mailer instance with a cached `document` and `created` methods.
    @mailer = message.send(:processed_mailer)

    message.public_send(delivery_method)
  end

  protected

  attr_reader :mailer, :log_options

  def log(error: nil)
    mailer&.log(error:, **log_options)
  end
end
