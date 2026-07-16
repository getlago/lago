# frozen_string_literal: true

class EnqueueUpdateAllEuTaxesJob < ActiveRecord::Migration[7.1]
  def up
    Taxes::UpdateAllEuTaxesJob.perform_later
  end

  def down
  end
end
