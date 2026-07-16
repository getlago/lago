# frozen_string_literal: true

module Types
  module DataExports
    module CreditNotes
      class CreateInput < Types::BaseInputObject
        graphql_name "CreateDataExportsCreditNotesInput"

        argument :filters, Types::DataExports::CreditNotes::FiltersInput
        argument :format, Types::DataExports::FormatTypeEnum
        argument :resource_type, Types::DataExports::CreditNotes::ExportTypeEnum
      end
    end
  end
end
