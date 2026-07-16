# frozen_string_literal: true

module Api
  module V1
    module Customers
      module Wallets
        class MetadataController < BaseController
          include WalletMetadataActions

          def create
            metadata_create(wallet)
          end

          def update
            metadata_update(wallet)
          end

          def destroy
            metadata_destroy(wallet)
          end

          def destroy_key
            metadata_destroy_key(wallet)
          end
        end
      end
    end
  end
end
