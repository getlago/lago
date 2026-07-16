# frozen_string_literal: true

module Utils
  class EmailActivityLog
    ACTIVITY_TYPE = "email.sent"
    TOPIC = ENV["LAGO_KAFKA_ACTIVITY_LOGS_TOPIC"]
    AVAILABLE = ENV["LAGO_CLICKHOUSE_ENABLED"].present? &&
      ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"].present? &&
      TOPIC.present?
    BODY_PREVIEW_LENGTH = 500

    def self.produce(document:, message:, organization_id: nil, resend: false, user_id: nil, api_key_id: nil, error: nil)
      new(document:, message:, organization_id:, resend:, user_id:, api_key_id:, error:).produce
    end

    def initialize(document:, message:, organization_id: nil, resend: false, user_id: nil, api_key_id: nil, error: nil)
      @document = document
      @organization_id = organization_id || document&.organization_id
      @message = message
      @resend = resend
      @user_id = user_id
      @api_key_id = api_key_id
      @error = error
      @activity_id = SecureRandom.uuid
      @current_time = Time.current.iso8601[...-1]
    end

    def produce
      enqueue_task if AVAILABLE && message.present? && organization_id.present?
    end

    private

    attr_reader :document, :organization_id, :message, :user_id, :api_key_id, :error, :activity_id, :current_time

    def status
      @status ||= if error
        "failed"
      elsif @resend
        "resent"
      else
        "sent"
      end
    end

    def enqueue_task
      payload = {
        activity_source:,
        api_key_id:,
        user_id:,
        activity_type: ACTIVITY_TYPE,
        activity_id:,
        logged_at: current_time,
        created_at: current_time,
        resource_id: resource.id,
        resource_type: resource.class.name,
        organization_id:,
        activity_object:,
        activity_object_changes: {},
        external_customer_id:,
        external_subscription_id: nil
      }
      KafkaProducer.produce_async(
        topic: TOPIC,
        key: "#{organization_id}--#{activity_id}",
        payload: payload.to_json
      )
    end

    def activity_source
      return "api" if api_key_id
      return "front" if user_id

      "system"
    end

    def activity_object
      result = {
        status:,
        email: email_metadata.to_json,
        document: document_reference.to_json
      }
      result[:error] = error_info.to_json if error
      result
    end

    def email_metadata
      {
        subject: message.subject,
        to: Array(message.to),
        cc: Array(message.cc),
        bcc: Array(message.bcc),
        body_preview: extract_body_preview
      }
    end

    def extract_body_preview
      raw = ((message.text_part || message.html_part)&.body || message.body)&.decoded.to_s
      sanitize(raw).truncate(BODY_PREVIEW_LENGTH)
    end

    def sanitize(html)
      spaced = html.gsub("<", " <")
      Rails::Html::FullSanitizer.new.sanitize(spaced).to_s.gsub(/\s+/, " ").strip
    end

    def document_reference
      if document.present?
        {
          type: document.class.name,
          number: document_number,
          lago_id: document.id
        }
      end
    end

    def document_number
      case document
      when Invoice, CreditNote, PaymentReceipt
        document.number
      end
    end

    def error_info
      {
        class: error.class.name,
        message: error.message
      }
    end

    def resource
      document
    end

    def external_customer_id
      document&.customer&.external_id
    end
  end
end
