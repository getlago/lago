# frozen_string_literal: true

module ChargeModels
  class PackageService < ChargeModels::BaseService
    protected

    def compute_amount
      return 0 if paid_units.negative?

      # NOTE: Check how many packages (groups of units) are consumed
      # It's rounded up, because a group counts from its first unit
      package_count = paid_units.fdiv(per_package_size).ceil
      package_count * per_package_unit_amount
    end

    def compute_projected_amount
      return 0 if projected_units.zero?

      # Calculate projected paid units (after free units)
      proj_paid_units = projected_units - BigDecimal(free_units.to_s)
      return 0 if proj_paid_units <= 0

      # Calculate how many packages are needed for projected usage
      proj_package_count = (proj_paid_units / BigDecimal(per_package_size.to_s)).ceil
      proj_package_count * per_package_unit_amount
    end

    def unit_amount
      return 0 if paid_units <= 0

      compute_amount / paid_units
    end

    def amount_details
      if units.zero?
        return {free_units: "0.0", paid_units: "0.0", per_package_size: 0, per_package_unit_amount: "0.0"}
      end

      if paid_units.negative?
        return {
          free_units: BigDecimal(free_units).to_s,
          paid_units: "0.0",
          per_package_size:,
          per_package_unit_amount:
        }
      end

      {
        free_units: BigDecimal(free_units).to_s,
        paid_units: BigDecimal(paid_units).to_s,
        per_package_size:,
        per_package_unit_amount:
      }
    end

    def paid_units
      @paid_units ||= units - free_units
    end

    def free_units
      @free_units ||= properties["free_units"] || 0
    end

    def per_package_size
      @per_package_size ||= properties["package_size"]
    end

    def per_package_unit_amount
      @per_package_unit_amount ||= BigDecimal(properties["amount"])
    end
  end
end
