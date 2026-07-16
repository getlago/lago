# frozen_string_literal: true

class AddPreciseUnitAmountToPricingUnitUsages < ActiveRecord::Migration[8.0]
  def change
    add_column :pricing_unit_usages,
      :precise_unit_amount,
      :decimal,
      precision: 30,
      scale: 15,
      default: 0.0,
      null: false
  end
end
