# frozen_string_literal: true

module Charges
  class UpdateChildrenService < BaseService
    Result = BaseResult[:charge]

    def initialize(charge:, params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:, child_ids:)
      @charge = charge
      @params = params
      @old_parent = Charge.new(old_parent_attrs)
      @child_ids = child_ids

      if old_parent_applied_pricing_unit_attrs.present?
        @old_parent.build_applied_pricing_unit(old_parent_applied_pricing_unit_attrs)
      end

      super
    end

    def call
      return result unless charge

      # Acquire an advisory lock on the parent charge to prevent concurrent
      # cascades from overlapping (e.g. parent updated twice in quick succession).
      # timeout_seconds: 0 fails immediately if another cascade is running;
      # the job's retry_on will pick it up later.
      Charge.with_advisory_lock!("update_children_charge_#{charge.id}", timeout_seconds: 0) do
        # skip touching to avoid deadlocks and redundant cascading updates
        Charge.no_touching do
          Plan.no_touching do
            charge.children.where(id: child_ids).find_each do |child_charge|
              Charges::UpdateService.call!(
                charge: child_charge,
                params:,
                cascade_options: {
                  cascade: true,
                  equal_properties: old_parent.equal_properties?(child_charge),
                  equal_applied_pricing_unit_rate: old_parent.equal_applied_pricing_unit_rate?(child_charge)
                }
              )
            end
          end
        end
      end

      result.charge = charge
      result
    end

    private

    attr_reader :charge, :params, :old_parent, :child_ids
  end
end
