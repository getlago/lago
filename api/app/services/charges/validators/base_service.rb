# frozen_string_literal: true

module Charges
  module Validators
    class BaseService < BaseValidator
      ALLOWED_PRESENTATION_GROUP_KEYS_OPTIONS_KEYS = %i[display_in_invoice].freeze
      ALLOWED_PRESENTATION_GROUP_KEYS_KEYS = %i[value options].freeze

      def initialize(charge:, properties: nil)
        @charge = charge
        @properties = properties || charge.properties
        @result = ::BaseService::Result.new

        super(result)
      end

      def valid?
        # NOTE: override and add validation rules

        validate_pricing_group_keys
        validate_presentation_group_keys

        if errors?
          result.validation_failure!(errors:)
          return false
        end

        true
      end

      attr_reader :result, :properties

      private

      attr_reader :charge

      def pricing_group_keys
        @pricing_group_keys ||= properties[grouped_key]
      end

      # NOTE: keep accepting grouped_by until the end of the deprecation period
      def grouped_key
        return "pricing_group_keys" unless properties["pricing_group_keys"].nil?

        "grouped_by"
      end

      def validate_pricing_group_keys
        return if pricing_group_keys.nil? || pricing_group_keys.is_a?(Array) && pricing_group_keys.blank?

        if pricing_group_keys.is_a?(Array)
          return if pricing_group_keys.all? { it.is_a?(String) } && pricing_group_keys.all?(&:present?)
        end

        add_error(field: grouped_key, error_code: "invalid_type")
      end

      def validate_presentation_group_keys
        raw_keys = properties["presentation_group_keys"]
        return if raw_keys.blank?

        values = []
        valid_presentation_group_keys = raw_keys.is_a?(Array) && raw_keys.all? do |key|
          next false unless key.is_a?(Hash)

          key = key.deep_symbolize_keys
          keys_valid = (key.keys - ALLOWED_PRESENTATION_GROUP_KEYS_KEYS).empty?
          value_key_present = key.key?(:value)

          value_valid = key[:value].is_a?(String) && key[:value].present?

          options_key_valid = true

          if key.key?(:options)
            options = key[:options]

            options_key_valid = if options.is_a?(Hash)
              options.keys == ALLOWED_PRESENTATION_GROUP_KEYS_OPTIONS_KEYS && [true, false].include?(options[:display_in_invoice])
            else
              false
            end
          end

          values << key[:value] if value_valid

          keys_valid && value_key_present && value_valid && options_key_valid
        end

        unless valid_presentation_group_keys
          add_error(
            field: "presentation_group_keys",
            error_code: "invalid_type"
          )
        end

        if raw_keys.size > 2
          add_error(field: "presentation_group_keys", error_code: "too_many_keys")
        end

        if values.size != values.uniq.size
          add_error(field: "presentation_group_keys", error_code: "value_is_duplicated")
        end
      end
    end
  end
end
