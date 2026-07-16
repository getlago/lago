# frozen_string_literal: true

class CreateExportsIntegrationCustomers < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_integration_customers
  end
end
