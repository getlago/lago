# frozen_string_literal: true

module ChargeFilters
  class CascadeService < BaseService
    Result = BaseResult

    def initialize(charge:, action:, filter_values:, old_properties: nil, new_properties: nil, invoice_display_name: nil)
      @charge = charge
      @action = action
      @filter_values = filter_values
      @old_properties = old_properties
      @new_properties = new_properties
      @invoice_display_name = invoice_display_name

      super
    end

    BATCH_SIZE = 1_000

    def call
      # NOTE: The cascade runs one job per changed filter
      # Each job has a single target (filter_values), so the matching child filter
      # is resolved for a whole batch of children in one query rather than loading
      # every child's full filter set, which keeps each job lightweight.
      child_ids.each_slice(BATCH_SIZE) do |ids|
        matches = matching_child_filters(ids)

        Charge.where(id: ids).includes(:billable_metric).find_each do |child_charge|
          Charge.no_touching do
            Plan.no_touching do
              child_filter = matches[child_charge.id]

              case action
              when "update" then update_child_filter(child_charge, child_filter)
              when "create" then create_child_filter(child_charge, child_filter)
              when "destroy" then destroy_child_filter(child_filter)
              end
            end
          end
        end
      end

      result
    end

    private

    attr_reader :charge, :action, :filter_values, :old_properties, :new_properties, :invoice_display_name

    def child_ids
      @child_ids ||= charge.children
        .joins(plan: :subscriptions)
        .where(subscriptions: {status: %w[active pending]})
        .distinct.pluck(:id)
    end

    # Resolve the child filter matching filter_values for an entire batch of
    # children in two bounded queries: narrow candidates by a shared value via the
    # database, then confirm the exact match in Ruby. This avoids both loading each
    # child's full filter set (memory) and querying once per child (N+1).
    def matching_child_filters(batch_child_ids)
      _key, values = filter_values.first
      return {} if values.blank?

      candidate_ids = ChargeFilter
        .where(charge_id: batch_child_ids)
        .joins(:values)
        .where("charge_filter_values.values && ARRAY[?]::varchar[]", values)
        .unscope(:order)
        .distinct
        .pluck(:id)
      return {} if candidate_ids.empty?

      ChargeFilter
        .where(id: candidate_ids)
        .includes(values: :billable_metric_filter)
        .select { |filter| filter.to_h == filter_values }
        .index_by(&:charge_id)
    end

    def update_child_filter(child_charge, child_filter)
      return unless child_filter

      if filter_customized?(child_filter)
        cascade_group_keys(child_filter)
        child_filter.save! if child_filter.changed?
        return
      end

      child_filter.properties = ChargeModels::FilterPropertiesService.call(
        chargeable: child_charge,
        properties: new_properties
      ).properties
      child_filter.invoice_display_name = invoice_display_name
      child_filter.save!
    end

    def create_child_filter(child_charge, existing_filter)
      return if existing_filter

      # NOTE: Resolve against the current state of the billable metric filters
      # to avoid any changes that may have occurred since the job was enqueued
      return if resolved_filter_values.empty?

      ActiveRecord::Base.transaction do
        child_filter = child_charge.filters.new(
          organization_id: child_charge.organization_id,
          invoice_display_name:,
          properties: ChargeModels::FilterPropertiesService.call(
            chargeable: child_charge,
            properties: new_properties
          ).properties
        )
        child_filter.save!

        resolved_filter_values.each do |billable_metric_filter, values|
          child_filter.values.create!(
            billable_metric_filter_id: billable_metric_filter.id,
            organization_id: child_charge.organization_id,
            values:
          )
        end
      end
    end

    def resolved_filter_values
      @resolved_filter_values ||= filter_values.filter_map do |key, values|
        billable_metric_filter = billable_metric_filters_by_key[key]
        next if billable_metric_filter.nil?

        valid_values = values & billable_metric_filter.values
        next if valid_values.empty?

        [billable_metric_filter, valid_values]
      end
    end

    def billable_metric_filters_by_key
      @billable_metric_filters_by_key ||= charge.billable_metric.filters
        .where(key: filter_values.keys)
        .index_by(&:key)
    end

    def destroy_child_filter(child_filter)
      return unless child_filter

      child_filter.values.update_all(deleted_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      child_filter.discard!
    end

    def filter_customized?(child_filter)
      return false unless old_properties

      normalize_properties(old_properties) != normalize_properties(child_filter.properties)
    end

    # Cascade group keys even for customized filters — group keys are structural
    # (they affect how events are bucketed), not pricing overrides.
    def cascade_group_keys(child_filter)
      pricing_group_keys = new_properties&.dig("pricing_group_keys") || new_properties&.dig("grouped_by")
      if pricing_group_keys
        child_filter.properties["pricing_group_keys"] = pricing_group_keys
        child_filter.properties.delete("grouped_by")
      elsif child_filter.pricing_group_keys.present?
        child_filter.properties.delete("pricing_group_keys")
        child_filter.properties.delete("grouped_by")
      end
    end

    def normalize_properties(props)
      return props unless props.is_a?(Hash)

      props.transform_values do |v|
        (v.is_a?(String) && v.match?(/\A-?\d+(\.\d+)?\z/)) ? v.to_f : v
      end
    end
  end
end
