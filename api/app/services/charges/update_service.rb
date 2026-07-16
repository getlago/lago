# frozen_string_literal: true

module Charges
  class UpdateService < BaseService
    include CascadeUpdatable

    Result = BaseResult[:charge]

    def initialize(charge:, params:, cascade_options: {}, cascade_updates: false)
      @charge = charge
      @params = params.to_h.deep_symbolize_keys
      @cascade_options = cascade_options
      @cascade = cascade_options[:cascade]
      @cascade_updates = cascade_updates

      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge
      return result if cascade && charge.charge_model != params[:charge_model]

      old_filters_attrs = capture_old_filters_attrs
      old_parent_attrs = charge.attributes.deep_dup
      old_applied_pricing_unit_attrs = charge.applied_pricing_unit&.attributes&.deep_dup

      ActiveRecord::Base.transaction do
        charge.charge_model = params[:charge_model] unless plan.attached_to_subscriptions?
        charge.invoice_display_name = params[:invoice_display_name] unless cascade
        charge.code = params[:code] if cascade && params[:code].present?

        # Make sure that pricing group keys and presentation group keys are cascaded even if properties are overridden
        if cascade
          cascade_pricing_group_keys
          cascade_presentation_group_keys
        end

        if !cascade || cascade_options[:equal_properties]
          properties = params.delete(:properties).presence || ChargeModels::BuildDefaultPropertiesService.call(
            params[:charge_model]
          )
          charge.properties = ChargeModels::FilterPropertiesService.call(chargeable: charge, properties:).properties
        end

        accepts_target_wallet = params.delete(:accepts_target_wallet)
        if plan.organization.events_targeting_wallets_enabled?
          charge.accepts_target_wallet = accepts_target_wallet unless accepts_target_wallet.nil?
        end

        charge.save!

        AppliedPricingUnits::UpdateService.call!(
          charge:,
          cascade_options:,
          params: params.delete(:applied_pricing_unit).presence
        )

        filters = params.delete(:filters)
        if filters && !cascade
          ChargeFilters::CreateOrUpdateBatchService.call(
            charge:,
            filters_params: filters.map(&:with_indifferent_access)
          ).raise_if_error!
        end

        result.charge = charge

        # In cascade mode it is allowed only to change properties
        unless cascade
          tax_codes = params.delete(:tax_codes)
          if tax_codes
            taxes_result = Charges::ApplyTaxesService.call(charge:, tax_codes:)
            taxes_result.raise_if_error!
          end

          # NOTE: charges cannot be edited if plan is attached to a subscription
          unless plan.attached_to_subscriptions?
            invoiceable = params.delete(:invoiceable)
            min_amount_cents = params.delete(:min_amount_cents)
            code = params.delete(:code)

            charge.invoiceable = invoiceable if License.premium? && !invoiceable.nil?
            charge.min_amount_cents = min_amount_cents || 0 if License.premium?
            charge.code = code if code.present?

            charge.update!(params)
          end
        end
      end

      trigger_cascade(old_filters_attrs, old_parent_attrs:, old_applied_pricing_unit_attrs:)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :code, error_code: "value_already_exist")
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_reader :charge, :params, :cascade_options, :cascade, :cascade_updates

    delegate :plan, to: :charge

    def cascade_presentation_group_keys
      presentation_group_keys = params.dig(:properties, :presentation_group_keys)

      if presentation_group_keys
        charge.properties["presentation_group_keys"] = presentation_group_keys
      elsif charge.properties["presentation_group_keys"].present?
        charge.properties.delete("presentation_group_keys")
      end
    end

    def cascade_pricing_group_keys
      pricing_group_keys = params.dig(:properties, :pricing_group_keys) || params.dig(:properties, :grouped_by)

      if pricing_group_keys
        charge.properties["pricing_group_keys"] = pricing_group_keys
        charge.properties.delete("grouped_by")
      elsif charge.pricing_group_keys.present?
        charge.properties.delete("pricing_group_keys")
        charge.properties.delete("grouped_by")
      end
    end
  end
end
