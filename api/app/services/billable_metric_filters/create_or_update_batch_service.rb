# frozen_string_literal: true

module BillableMetricFilters
  class CreateOrUpdateBatchService < BaseService
    Result = BaseResult[:filters]

    BATCH_SIZE = 1_000

    def initialize(billable_metric:, filters_params:)
      @billable_metric = billable_metric
      @filters_params = filters_params

      super
    end

    def call
      result.filters = []

      if filters_params.empty?
        discard_all_filters

        return result
      end

      return result.validation_failure!(errors: {values: ["value_is_mandatory"]}) if any_filter_params_values_blank?

      ActiveRecord::Base.transaction do
        filters_params.each do |filter_param|
          filter = billable_metric.filters
            .create_with(organization_id: billable_metric.organization_id)
            .find_or_initialize_by(key: filter_param[:key])
          new_values = (filter_param[:values] || []).uniq

          if filter.persisted?
            deleted_values = filter.values - filter_param[:values]

            if deleted_values.present?
              filter_values = filter.filter_values
                .where(
                  deleted_values.map { "? = ANY(values)" }.join(" OR "),
                  *deleted_values
                )

              discard_filter_values_in_batches(filter_values, new_values:)
            end
          end

          filter.values = new_values
          filter.save!

          result.filters << filter
        end

        # NOTE: discard all filters that were not created or updated
        billable_metric.filters.where.not(id: result.filters.map(&:id)).unscope(:order).find_each do
          discard_filter(it)
        end
      end

      BillableMetricFilters::RefreshDraftInvoicesJob.perform_after_commit(billable_metric.id)

      result
    end

    private

    attr_reader :billable_metric, :filters_params

    def any_filter_params_values_blank?
      filters_params.any? do |filter_param|
        filter_param[:values].blank?
      end
    end

    def discard_all_filters
      ActiveRecord::Base.transaction do
        billable_metric.filters.each { discard_filter(it) }
      end
    end

    def discard_filter(filter)
      discard_filter_values_in_batches(filter.filter_values)

      filter.discard!
    end

    def discard_filter_values_in_batches(filter_values, new_values: [])
      filter_values.unscope(:order).in_batches(of: BATCH_SIZE) do |filter_value_batch|
        values_to_trim, values_to_discard = filter_value_batch.partition { |fv| trimmable?(fv, new_values) }

        bulk_update_trimmed_filter_values(values_to_trim, new_values)
        discard_filter_values_and_emptied_charge_filters(values_to_discard)
      end
    end

    def trimmable?(filter_value, new_values)
      filter_value.values.intersect?(new_values)
    end

    def bulk_update_trimmed_filter_values(filter_values, new_values)
      return if filter_values.empty?

      filter_values.group_by { |fv| fv.values & new_values }.each do |result_values, group|
        ChargeFilterValue.where(id: group.map(&:id)).update_all( # rubocop:disable Rails/SkipsModelValidations
          values: result_values, updated_at: Time.current
        )
      end
    end

    def discard_filter_values_and_emptied_charge_filters(filter_values)
      return if filter_values.empty?

      filter_value_ids = filter_values.map(&:id)
      bulk_discard_filter_values(filter_value_ids)
      bulk_discard_emptied_charge_filters_for(filter_value_ids)
    end

    def bulk_discard_filter_values(filter_value_ids)
      ChargeFilterValue
        .where(id: filter_value_ids)
        .update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def bulk_discard_emptied_charge_filters_for(filter_value_ids)
      charge_filter_ids = ChargeFilterValue
        .with_discarded
        .where(id: filter_value_ids)
        .unscope(:order)
        .distinct
        .pluck(:charge_filter_id)

      return if charge_filter_ids.empty?

      ChargeFilter
        .where(id: charge_filter_ids, deleted_at: nil)
        .where(
          "NOT EXISTS (SELECT 1 FROM charge_filter_values" \
          " WHERE charge_filter_values.charge_filter_id = charge_filters.id" \
          " AND charge_filter_values.deleted_at IS NULL)"
        )
        .unscope(:order)
        .update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
