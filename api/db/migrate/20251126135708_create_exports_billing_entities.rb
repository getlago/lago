# frozen_string_literal: true

class CreateExportsBillingEntities < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_billing_entities
  end
end
