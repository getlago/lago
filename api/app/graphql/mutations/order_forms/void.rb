# frozen_string_literal: true

module Mutations
  module OrderForms
    class Void < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "order_forms:void"

      graphql_name "VoidOrderForm"
      description "Void an order form"

      input_object_class Types::OrderForms::VoidInput

      type Types::OrderForms::Object

      def resolve(**args)
        order_form = current_organization.order_forms.find_by(id: args[:id])
        result = ::OrderForms::VoidService.call(order_form:)

        result.success? ? result.order_form : result_error(result)
      end
    end
  end
end
