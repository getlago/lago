# frozen_string_literal: true

module Types
  module BillingEntities
    class DocumentNumberingEnum < Types::BaseEnum
      graphql_name "BillingEntityDocumentNumberingEnum"
      description "Document numbering type"

      ::BillingEntity::DOCUMENT_NUMBERINGS.keys.each do |code|
        value code
      end
    end
  end
end
