# frozen_string_literal: true

module Mutations
  module DataExports
    module Invoices
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "invoices:export"

        graphql_name "CreateInvoicesDataExport"
        description "Request data export of invoices"

        input_object_class Types::DataExports::Invoices::CreateInput

        type Types::DataExports::Object

        def resolve(format:, filters:, resource_type:)
          result = ::DataExports::CreateService
            .call(
              organization: current_organization,
              user: context[:current_user],
              format:,
              resource_type:,
              resource_query: filters
            )

          result.success? ? result.data_export : result_error(result)
        end
      end
    end
  end
end
