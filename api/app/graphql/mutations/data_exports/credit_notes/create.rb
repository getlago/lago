# frozen_string_literal: true

module Mutations
  module DataExports
    module CreditNotes
      class Create < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        REQUIRED_PERMISSION = "credit_notes:export"

        graphql_name "CreateCreditNotesDataExport"
        description "Request data export of credit notes"

        input_object_class Types::DataExports::CreditNotes::CreateInput

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
