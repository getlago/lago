# frozen_string_literal: true

class ChangePresentationBreakdownsUnitsDecimal < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      remove_column :presentation_breakdowns, :units # rubocop:disable Lago/NoDropColumnOrTable
    end
    add_column :presentation_breakdowns, :units, :decimal, null: false, default: 0
  end

  def down
    safety_assured do
      remove_column :presentation_breakdowns, :units # rubocop:disable Lago/NoDropColumnOrTable
    end

    add_column :presentation_breakdowns, :units, :decimal, precision: 30, scale: 10, null: false, default: 0
  end
end
