# frozen_string_literal: true

module Quotes
  class AddImageService < BaseService
    include OrderForms::Premium

    Result = BaseResult[:image_url, :image_id]

    def initialize(quote:, image:)
      @quote = quote
      @image = image

      super
    end

    def call
      return result.not_found_failure!(resource: "quote") unless quote
      return result.forbidden_failure! unless order_forms_enabled?(quote.organization)

      blob = image_blob
      return result if result.failure?

      quote.images.attach(blob)
      quote.save!

      result.image_id = blob.id
      result.image_url = Rails.application.routes.url_helpers.rails_blob_url(
        blob,
        host: ENV["LAGO_API_URL"]
      )
      result
    rescue ActiveRecord::RecordInvalid => e
      blob&.purge_later
      errors = e.record.errors.messages.transform_keys { |key| (key == :images) ? :image : key }
      result.validation_failure!(errors:)
    end

    private

    attr_reader :quote, :image

    def image_blob
      decoded = Utils::Base64File.decode(image)

      if decoded.nil?
        result.single_validation_failure!(field: :image, error_code: "invalid_format")
        return
      end

      if decoded.io.size > Quote::IMAGE_MAX_SIZE
        result.single_validation_failure!(field: :image, error_code: "file_too_large")
        return
      end

      ActiveStorage::Blob.create_and_upload!(
        io: decoded.io,
        filename: filename(decoded.content_type),
        content_type: decoded.content_type
      )
    end

    def filename(content_type)
      "quote-image-#{SecureRandom.uuid}.#{content_type.split("/").last}"
    end
  end
end
