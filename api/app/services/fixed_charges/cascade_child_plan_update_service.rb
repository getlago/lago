# frozen_string_literal: true

module FixedCharges
  class CascadeChildPlanUpdateService < BaseService
    Result = BaseResult[:plan]
    UnknownActionError = Class.new(StandardError)

    def initialize(plan:, cascade_fixed_charges_payload:, timestamp:)
      @plan = plan
      @cascade_fixed_charges_payload = cascade_fixed_charges_payload.map(&:deep_symbolize_keys)
      @timestamp = timestamp.to_i

      super
    end

    def call
      return result if cascade_fixed_charges_payload.empty?

      ActiveRecord::Base.transaction do
        # skip touching to avoid deadlocks
        Plan.no_touching do
          cascade_fixed_charges_payload.each do |payload|
            case payload[:action]&.to_sym
            when :create
              FixedCharges::CreateService.call!(plan:, params: payload, timestamp:)

            when :update
              fixed_charge = plan.fixed_charges.find_by!(parent_id: payload[:id])

              old_parent = FixedCharge.new(payload[:old_parent_attrs])

              FixedCharges::UpdateService.call!(
                fixed_charge:,
                params: payload,
                timestamp:,
                cascade_options: {
                  cascade: true,
                  equal_properties: old_parent.equal_properties?(fixed_charge)
                },
                trigger_billing: false
              )
            else
              raise UnknownActionError, "Unknown action #{payload[:action]} for fixed charge cascade"
            end
          end
        end
      end

      if plan.fixed_charges.pay_in_advance.exists?
        Invoices::CreateAllPayInAdvanceFixedChargesJob.perform_after_commit(plan, timestamp)
      end

      result.plan = plan
      result
    rescue UnknownActionError => e
      result.fail_with_error!(e.message)
    rescue ActiveRecord::RecordNotFound => e
      result.not_found_failure!(resource: e.model.underscore)
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :plan, :cascade_fixed_charges_payload, :timestamp
  end
end
