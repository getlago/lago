# frozen_string_literal: true

module Types
  module PaymentProviders
    class CashfreeInput < BaseInputObject
      description "Cashfree input arguments"

      argument :client_id, String, required: true
      argument :client_secret, String, required: true
      argument :code, String, required: true
      argument :name, String, required: true
      argument :success_redirect_url, String, required: false
    end
  end
end
