# frozen_string_literal: true

module ChargeModels
  module FilterProperties
    class BaseService < ::BaseService
      Result = BaseResult[:properties]

      def initialize(chargeable:, properties:)
        @chargeable = chargeable
        @properties = properties&.with_indifferent_access || {}

        super
      end

      def call
        result.properties = slice_properties || {}

        if result.properties[:custom_properties].present? && result.properties[:custom_properties].is_a?(String)
          result.properties[:custom_properties] = begin
            JSON.parse(result.properties[:custom_properties])
          rescue JSON::ParserError
            {}
          end
        end

        result
      end

      protected

      attr_reader :chargeable, :properties

      def slice_properties
        attributes = base_attributes + charge_model_attributes
        sliced_attributes = properties.slice(*attributes)

        # TODO(pricing_group_keys):Deprecate grouped_by attribute
        grouped_by = sliced_attributes[:grouped_by]
        pricing_group_keys = sliced_attributes[:pricing_group_keys]

        pricing_group_keys = grouped_by if grouped_by.present? && pricing_group_keys.blank?
        sliced_attributes[:pricing_group_keys] = pricing_group_keys.reject(&:empty?) if pricing_group_keys.present?
        sliced_attributes.delete(:grouped_by)

        sliced_attributes
      end

      def base_attributes
        []
      end

      def charge_model_attributes
        attributes = case charge_model&.to_sym
        when :standard
          %i[amount]
        when :graduated
          %i[graduated_ranges]
        when :volume
          %i[volume_ranges]
        else
          []
        end

        if charge_model
          attributes << :grouped_by if properties[:grouped_by].present? && properties[:pricing_group_keys].blank?
          attributes << :pricing_group_keys if properties[:pricing_group_keys].present?
          attributes << :presentation_group_keys if properties[:presentation_group_keys].present?
        end

        attributes
      end

      def charge_model
        @charge_model ||= chargeable.charge_model
      end
    end
  end
end
