# frozen_string_literal: true

class CreateExportsPaymentRequests < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_payment_requests
  end
end
