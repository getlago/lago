# frozen_string_literal: true

module Emails
  class ResendService < BaseService
    Result = BaseResult

    def initialize(resource:, to: nil, cc: nil, bcc: nil)
      @resource = resource
      @to = to
      @cc = cc
      @bcc = bcc
      super
    end

    def call
      return result.not_found_failure!(resource: resource_type) unless resource
      return result.not_allowed_failure!(code: "#{resource_type}_not_finalized") unless valid_status?
      return result.forbidden_failure!(code: "premium_license_required") unless License.premium?
      return result.not_allowed_failure!(code: "email_settings_disabled") unless email_settings_enabled?
      return result.validation_failure!(errors: validation_errors) if validation_errors.any?

      send_email
      result
    end

    private

    attr_reader :resource, :to, :cc, :bcc

    def send_email
      mailer_class
        .with(mailer_params)
        .created
        .deliver_later
    end

    def mailer_class
      case resource
      when Invoice then InvoiceMailer
      when CreditNote then CreditNoteMailer
      when PaymentReceipt then PaymentReceiptMailer
      end
    end

    def mailer_params
      param_key = resource.class.name.underscore.to_sym
      {param_key => resource, :resend => true, :to => recipients_to, :cc => recipients_cc, :bcc => recipients_bcc}
    end

    def valid_status?
      return true if resource.is_a?(PaymentReceipt)

      resource.finalized?
    end

    def billing_entity
      case resource
      when Invoice, PaymentReceipt
        resource.billing_entity
      when CreditNote
        resource.invoice.billing_entity
      end
    end

    def customer
      return resource.payment.payable.customer if resource.is_a?(PaymentReceipt)

      resource.customer
    end

    def email_settings_enabled?
      billing_entity.email_settings.include?(email_settings_key)
    end

    def email_settings_key
      {
        "Invoice" => "invoice.finalized",
        "CreditNote" => "credit_note.created",
        "PaymentReceipt" => "payment_receipt.created"
      }[resource.class.name]
    end

    def resource_type
      resource&.class&.name&.underscore || "resource"
    end

    def recipients_to
      return Array(to) if to.present?

      [customer.email].compact
    end

    def recipients_cc
      Array(cc)
    end

    def recipients_bcc
      Array(bcc)
    end

    def validation_errors
      errors = {}
      errors[:billing_entity] = ["must have email configured"] if billing_entity.email.blank?
      errors[:to] = ["must have at least one recipient"] if recipients_to.empty?

      invalid_to = recipients_to.reject { |email| valid_email?(email) }
      errors[:to] = ["invalid email format: #{invalid_to.join(", ")}"] if invalid_to.any?

      invalid_cc = recipients_cc.reject { |email| valid_email?(email) }
      errors[:cc] = ["invalid email format: #{invalid_cc.join(", ")}"] if invalid_cc.any?

      invalid_bcc = recipients_bcc.reject { |email| valid_email?(email) }
      errors[:bcc] = ["invalid email format: #{invalid_bcc.join(", ")}"] if invalid_bcc.any?

      errors
    end

    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end
  end
end
