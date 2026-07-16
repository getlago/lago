# frozen_string_literal: true

class FixedChargeChargeModel < ActiveRecord::Migration[8.0]
  def change
    create_enum :fixed_charge_charge_model, %w[standard graduated volume]
  end
end
