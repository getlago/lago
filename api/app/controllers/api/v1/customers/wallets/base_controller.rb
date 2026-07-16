# frozen_string_literal: true

module Api
  module V1
    module Customers
      module Wallets
        class BaseController < Api::V1::Customers::BaseController
          before_action :find_wallet

          private

          attr_reader :wallet

          def find_wallet
            @wallet = customer.wallets.order(:status).find_by!(code: params[:wallet_code])
          rescue ActiveRecord::RecordNotFound
            not_found_error(resource: "wallet")
          end

          def resource_name
            "wallet"
          end
        end
      end
    end
  end
end
