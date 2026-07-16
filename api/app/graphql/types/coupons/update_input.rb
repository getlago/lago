# frozen_string_literal: true

module Types
  module Coupons
    class UpdateInput < Types::Coupons::CreateInput
      graphql_name "UpdateCouponInput"

      argument :code, String, required: false
      argument :id, String, required: true
    end
  end
end
