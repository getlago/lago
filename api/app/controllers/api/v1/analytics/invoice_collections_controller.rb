# frozen_string_literal: true

module Api
  module V1
    module Analytics
      class InvoiceCollectionsController < BaseController
        def index
          @result = ::Analytics::InvoiceCollectionsService.call(current_organization, **filters)

          super
        end

        private

        def filters
          {
            currency: params[:currency]&.upcase,
            months: params[:months],
            billing_entity_id: billing_entity&.id
          }
        end
      end
    end
  end
end
