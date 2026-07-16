# frozen_string_literal: true

module Mutations
  module Orders
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "orders:update"

      graphql_name "UpdateOrder"
      description "Update an order's execution settings"

      input_object_class Types::Orders::UpdateInput

      type Types::Orders::Object

      def resolve(**args)
        order = current_organization.orders.find_by(id: args[:id])
        result = ::Orders::UpdateService.call(order:, params: args.except(:id))

        result.success? ? result.order : result_error(result)
      end
    end
  end
end
