# frozen_string_literal: true

module Api
  module V1
    module Wallets
      class BaseController < Api::BaseController
        before_action :find_wallet

        private

        attr_reader :wallet

        def find_wallet
          @wallet = current_organization.wallets.find_by!(id: params[:wallet_id])
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
