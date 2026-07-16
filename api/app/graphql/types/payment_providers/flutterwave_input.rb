# frozen_string_literal: true

module Types
  module PaymentProviders
    class FlutterwaveInput < BaseInputObject
      description "Flutterwave input arguments"

      argument :code, String, required: true
      argument :name, String, required: true
      argument :secret_key, String, required: true
      argument :success_redirect_url, String, required: false
    end
  end
end
