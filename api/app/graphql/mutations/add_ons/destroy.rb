# frozen_string_literal: true

module Mutations
  module AddOns
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "addons:delete"

      graphql_name "DestroyAddOn"
      description "Deletes an add-on"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        add_on = current_organization.add_ons.find_by(id:)
        result = ::AddOns::DestroyService.call(add_on:)

        result.success? ? result.add_on : result_error(result)
      end
    end
  end
end
