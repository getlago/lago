# frozen_string_literal: true

module Utils
  class Base64File
    Decoded = Data.define(:io, :content_type)

    def self.decode(data_uri)
      metadata, data = data_uri.to_s.split(",", 2)
      return if data.nil?

      content_type = metadata.split(";").first&.split(":")&.second
      return if content_type.blank?

      Decoded.new(io: StringIO.new(Base64.decode64(data)), content_type:)
    end
  end
end
