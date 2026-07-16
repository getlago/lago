# frozen_string_literal: true

module Types
  class PermissionsType < Types::BaseObject
    description "Permissions Type"

    # NOTE: GraphQL field names cannot contain colons, so we convert them to underscores
    #       `billing_metrics:view` becomes `billing_metrics_view` which becomes `billingMetricsView`
    #       https://spec.graphql.org/October2021/#sec-Punctuators
    #       https://spec.graphql.org/October2021/#sec-Names
    Permission.permissions_hash.keys.each do |permissions|
      field permissions.tr(":", "_"), Boolean, null: false
    end
  end
end
