# frozen_string_literal: true

class Webhook < ApplicationRecord
  include RansackUuidSearch

  STATUS = %i[pending succeeded failed retrying].freeze

  belongs_to :webhook_endpoint
  belongs_to :object, polymorphic: true, optional: true
  belongs_to :organization

  enum :status, STATUS

  def self.ransackable_attributes(_auth_object = nil)
    %w[id object_id]
  end

  def self.payload_storage
    ActiveStorage::Blob.service
  end

  def payload
    if payload_key.present?
      stored_payload
    else
      legacy_payload
    end
  end

  def response
    if response_key.present?
      stored_response
    else
      super
    end
  end

  def store_payload(content)
    self.payload_key ||= storage_key("payload.json.gz")
    @stored_payload = upload_json(payload_key, content)
    payload_key
  end

  def store_response(content)
    self.response_key ||= storage_key("response.json.gz")
    @stored_response = upload_json(response_key, content)
    response_key
  rescue => e
    # Fallback to storing the response in the database if the upload fails,
    # so the webhook keeps an accurate state even when storage is unavailable.
    Sentry.capture_exception(e) if defined?(Sentry)
    self.response_key = nil
    @stored_response = nil
    self.response = content
  end

  def generate_headers
    signature = case webhook_endpoint.signature_algo&.to_sym
    when :jwt
      jwt_signature
    when :hmac
      hmac_signature
    end

    {
      "X-Lago-Signature" => signature,
      "X-Lago-Signature-Algorithm" => webhook_endpoint.signature_algo.to_s,
      "X-Lago-Unique-Key" => id
    }
  end

  def jwt_signature
    JWT.encode(
      {
        data: payload.to_json,
        iss: issuer
      },
      RsaPrivateKey,
      "RS256"
    )
  end

  def hmac_signature
    hmac = OpenSSL::HMAC.digest("sha-256", organization.hmac_key, payload.to_json)
    Base64.strict_encode64(hmac)
  end

  def issuer
    ENV["LAGO_API_URL"]
  end

  private

  def stored_payload
    @stored_payload ||= download_json(payload_key)
  end

  def stored_response
    @stored_response ||= download_json(response_key)
  end

  def legacy_payload
    attr = self[:payload]
    if attr.is_a?(String)
      JSON.parse(attr)
    else
      attr
    end
  end

  def upload_json(key, content)
    json = content.to_json
    self.class.payload_storage.upload(
      key,
      StringIO.new(ActiveSupport::Gzip.compress(json)),
      content_type: "application/gzip"
    )
    JSON.parse(json)
  end

  def download_json(key)
    JSON.parse(ActiveSupport::Gzip.decompress(self.class.payload_storage.download(key)))
  end

  def storage_key(filename)
    "#{storage_directory}/#{filename}"
  end

  def storage_directory
    @storage_directory ||= begin
      reference = payload_key || response_key
      if reference.present?
        File.dirname(reference)
      else
        self.id ||= SecureRandom.uuid
        "webhooks/#{Time.current.utc.strftime("%Y/%m/%d")}/#{id}"
      end
    end
  end
end

# == Schema Information
#
# Table name: webhooks
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  endpoint            :string
#  http_status         :integer
#  last_retried_at     :datetime
#  object_type         :string
#  payload             :json
#  payload_key         :string
#  response            :json
#  response_key        :string
#  retries             :integer          default(0), not null
#  status              :integer          default("pending"), not null
#  webhook_type        :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  object_id           :uuid
#  organization_id     :uuid             not null
#  webhook_endpoint_id :uuid
#
# Indexes
#
#  index_webhooks_for_query                                      (organization_id,webhook_endpoint_id,webhook_type,updated_at)
#  index_webhooks_on_endpoint_and_timestamps                     (webhook_endpoint_id,updated_at,created_at)
#  index_webhooks_on_endpoint_status_and_timestamps              (webhook_endpoint_id,status,updated_at)
#  index_webhooks_on_object_type_and_object_id_and_webhook_type  (object_type,object_id,webhook_type)
#  index_webhooks_on_organization_id                             (organization_id)
#  index_webhooks_on_updated_at_for_cleanup                      (updated_at)
#  index_webhooks_on_webhook_endpoint_id                         (webhook_endpoint_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (webhook_endpoint_id => webhook_endpoints.id)
#
