# frozen_string_literal: true

class CreateExportsPayments < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_payments
  end
end
