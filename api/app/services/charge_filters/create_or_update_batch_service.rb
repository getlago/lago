# frozen_string_literal: true

module ChargeFilters
  class CreateOrUpdateBatchService < BaseService
    Result = BaseResult[:filters]

    def initialize(charge:, filters_params:)
      @charge = charge
      @filters_params = filters_params
      @organization = charge.organization
      @new_filter_rows = []
      @new_filter_value_rows = []
      @new_filter_ids = []

      # We only care about order when you have less than 100 filters.
      @should_touch = filters_params.size < 100

      super
    end

    def call
      result.filters = []

      if filters_params.empty?
        remove_all

        return result
      end

      return result.single_validation_failure!(field: :values, error_code: "value_is_mandatory") if empty_filter_values?

      ActiveRecord::Base.transaction do
        filters_params.each do |filter_param|
          values_params = filter_param[:values].transform_keys(&:to_s)

          # NOTE: since a filter could be a refinement of another one, we have to make sure
          #       that we are targeting the right one
          existing_filter = filters_by_values_key[values_params.sort]

          properties = ChargeModels::FilterPropertiesService.call(
            chargeable: charge,
            properties: filter_param[:properties]&.deep_symbolize_keys&.except(:presentation_group_keys)
          ).properties

          if existing_filter
            update_existing_filter(existing_filter, filter_param, values_params, properties)
          else
            accumulate_new_filter(filter_param, values_params, properties)
          end
        end

        bulk_insert_new_filters

        # NOTE: remove old filters that were not created or updated
        charge.filters.where.not(id: result.filters.map(&:id)).unscope(:order).find_each do
          remove_filter(it)
        end
      end

      result
    end

    private

    attr_reader :charge, :filters_params, :organization, :should_touch, :new_filter_rows, :new_filter_value_rows, :new_filter_ids

    def update_existing_filter(filter, filter_param, values_params, properties)
      filter.charge = charge
      filter.organization = organization

      filter.invoice_display_name = filter_param[:invoice_display_name]
      filter.properties = properties

      filter.save! if filter.changed?

      if should_touch && !filter.saved_changes?
        PaperTrail.request.disable_model(filter.class)
        # NOTE: Make sure updated_at is touched even if not changed to keep the right order.
        filter.touch # rubocop:disable Rails/SkipsModelValidations
        PaperTrail.request.enable_model(filter.class)
      end

      filter_values_indexed = filter.values.index_by(&:billable_metric_filter_id)

      values_params.each do |key, values|
        billable_metric_filter = billable_metric_filters_by_key[key]
        filter_value = filter_values_indexed[billable_metric_filter&.id]
        filter_value ||= filter.values.build
        filter_value.charge_filter = filter
        filter_value.billable_metric_filter = billable_metric_filter
        filter_value.organization = organization

        filter_value.values = values
        filter_value.save! if filter_value.changed?

        if should_touch && !filter_value.saved_changes?
          PaperTrail.request.disable_model(filter_value.class)
          # NOTE: Make sure update_at is touched even if not changed to keep the right order
          filter_value.touch # rubocop:disable Rails/SkipsModelValidations
          PaperTrail.request.enable_model(filter_value.class)
        end
      end

      result.filters << filter
    end

    def accumulate_new_filter(filter_param, values_params, properties)
      # NOTE: pre-generate the UUID so we can wire ChargeFilterValue rows to their parent
      #       without a round-trip after the ChargeFilter insert_all.
      filter_id = SecureRandom.uuid

      # NOTE: build an in-memory AR instance only to run validations
      filter_instance = ChargeFilter.new(
        id: filter_id,
        charge:,
        organization:,
        invoice_display_name: filter_param[:invoice_display_name],
        properties: properties
      )
      filter_instance.validate!

      new_filter_rows << {
        id: filter_id,
        charge_id: charge.id,
        organization_id: organization.id,
        invoice_display_name: filter_param[:invoice_display_name],
        properties: properties
      }
      new_filter_ids << filter_id

      values_params.each do |key, values|
        billable_metric_filter = billable_metric_filters_by_key[key]

        value_instance = ChargeFilterValue.new(
          charge_filter: filter_instance,
          billable_metric_filter:,
          organization:,
          values: values
        )
        value_instance.validate!

        new_filter_value_rows << {
          charge_filter_id: filter_id,
          billable_metric_filter_id: billable_metric_filter&.id,
          organization_id: organization.id,
          values: values
        }
      end
    end

    def bulk_insert_new_filters
      return if new_filter_rows.empty?

      # NOTE: insert_all stamps every row with the same created_at/updated_at within
      #       a single call. The model's default_scope orders by updated_at, so we
      #       assign monotonically-increasing per-row offsets to preserve input order.
      now = Time.current
      new_filter_rows.each_with_index do |row, idx|
        timestamp = now + (idx / 1_000_000.0)
        row[:created_at] = timestamp
        row[:updated_at] = timestamp
      end

      returned = ChargeFilter.insert_all!(new_filter_rows, returning: ChargeFilter.column_names) # rubocop:disable Rails/SkipsModelValidations
      returned.each { |attrs| result.filters << ChargeFilter.instantiate(attrs) }

      if new_filter_value_rows.any?
        new_filter_value_rows.each_with_index do |row, idx|
          timestamp = now + (idx / 1_000_000.0)
          row[:created_at] = timestamp
          row[:updated_at] = timestamp
        end
        ChargeFilterValue.insert_all!(new_filter_value_rows) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    def filters
      @filters ||= charge.filters.includes(values: :billable_metric_filter)
    end

    def filters_by_values_key
      @filters_by_values_key ||= filters.index_by { |f| f.to_h.sort }
    end

    def billable_metric_filters_by_key
      @billable_metric_filters_by_key ||= charge.billable_metric.filters.index_by(&:key)
    end

    def remove_all
      ActiveRecord::Base.transaction do
        charge.filters.each { remove_filter(it) }
      end
    end

    def remove_filter(filter)
      filter.values.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      filter.discard!
    end

    def empty_filter_values?
      filters_params.any? { |filter_param| filter_param[:values].blank? }
    end
  end
end
