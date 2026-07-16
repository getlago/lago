# frozen_string_literal: true

module Mutations
  module AddOns
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "addons:update"

      graphql_name "UpdateAddOn"
      description "Update an existing add-on"

      input_object_class Types::AddOns::UpdateInput

      type Types::AddOns::Object

      def resolve(**args)
        add_on = current_organization.add_ons.find_by(id: args[:id])
        result = ::AddOns::UpdateService.call(add_on:, params: args)

        result.success? ? result.add_on : result_error(result)
      end
    end
  end
end
