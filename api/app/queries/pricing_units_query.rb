# frozen_string_literal: true

class PricingUnitsQuery < BaseQuery
  Result = BaseResult[:pricing_units]

  def call
    pricing_units = base_scope.result
    pricing_units = paginate(pricing_units)
    pricing_units = apply_consistent_ordering(
      pricing_units,
      default_order: {name: :asc, created_at: :desc}
    )

    result.pricing_units = pricing_units
    result
  end

  private

  def base_scope
    PricingUnit.where(organization:).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      name_cont: search_term,
      code_cont: search_term
    }
  end
end
