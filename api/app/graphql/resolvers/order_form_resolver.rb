# frozen_string_literal: true

module Resolvers
  class OrderFormResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "order_forms:view"

    description "Query a single order form"

    argument :id, ID, required: true, description: "Uniq ID of the order form"

    type Types::OrderForms::Object, null: true

    def resolve(id:)
      current_organization.order_forms.find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "order_form")
    end
  end
end
