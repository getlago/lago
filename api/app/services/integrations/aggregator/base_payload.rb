# frozen_string_literal: true

module Integrations
  module Aggregator
    class BasePayload
      class Failure < BaseService::FailedResult
        attr_reader :code

        def initialize(result, code:)
          @code = code

          super(result, code)
        end
      end

      def initialize(integration:, billing_entity:)
        @integration = integration
        @billing_entity = billing_entity
      end

      def billable_metric_item(fee)
        lookup_mapping("BillableMetric", fee.billable_metric.id)
      end

      def add_on_item(fee)
        lookup_mapping("AddOn", fee.add_on_id)
      end

      def fixed_charge_item(fee)
        lookup_mapping("AddOn", fee.fixed_charge_add_on.id)
      end

      def account_item
        lookup_collection_mapping(:account)
      end

      def tax_item
        lookup_collection_mapping(:tax, with_fallback_item: false)
      end

      def commitment_item
        lookup_collection_mapping(:minimum_commitment)
      end

      def subscription_item
        lookup_collection_mapping(:subscription_fee)
      end

      def coupon_item
        lookup_collection_mapping(:coupon)
      end

      def credit_item
        lookup_collection_mapping(:prepaid_credit)
      end

      def credit_note_item
        lookup_collection_mapping(:credit_note)
      end

      def amount(amount_cents, resource:)
        currency = resource.total_amount.currency

        amount_cents.round.fdiv(currency.subunit_to_unit)
      end

      private

      attr_reader :integration, :billing_entity

      def fallback_item(scope)
        mappings = integration.integration_collection_mappings
        fallback_items = mappings.filter { |mapping| mapping.mapping_type.to_sym == :fallback_item }
        if scope == :billing_entity && billing_entity
          return fallback_items.find { |mapping| mapping.billing_entity_id == billing_entity.id }
        end

        fallback_items.find { |mapping| mapping.billing_entity_id.nil? }
      end

      def lookup_collection_mapping(mapping_type, with_fallback_item: true)
        mappings = integration.integration_collection_mappings
        matching_mappings = mappings.filter { |mapping| mapping.mapping_type.to_sym == mapping_type.to_sym }
        billing_entity_mapping = matching_mappings.find { |mapping| mapping.billing_entity_id == billing_entity.id }
        organization_mapping = matching_mappings.find { |mapping| mapping.billing_entity_id.nil? }
        if with_fallback_item
          return billing_entity_mapping ||
              fallback_item(:billing_entity) ||
              organization_mapping ||
              fallback_item(:organization)
        end

        billing_entity_mapping ||
          organization_mapping
      end

      def lookup_mapping(mappable_type, mappable_id)
        mappings = integration.integration_mappings
        matching_mappings = mappings.filter { |mapping| mapping.mappable_type == mappable_type && mapping.mappable_id == mappable_id }
        billing_entity_mapping = matching_mappings.find { |mapping| mapping.billing_entity_id == billing_entity.id }
        organization_mapping = matching_mappings.find { |mapping| mapping.billing_entity_id.nil? }
        billing_entity_mapping ||
          fallback_item(:billing_entity) ||
          organization_mapping ||
          fallback_item(:organization)
      end

      def tax_item_complete?
        tax_item&.tax_nexus.present? && tax_item&.tax_type.present? && tax_item&.tax_code.present?
      end

      def formatted_date(date)
        date&.strftime("%Y-%m-%d")
      end
    end
  end
end
