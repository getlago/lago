# frozen_string_literal: true

module Types
  module Organizations
    class DocumentNumberingEnum < Types::BaseEnum
      description "Document numbering type"

      Organization::DOCUMENT_NUMBERINGS.each do |type|
        value type
      end
    end
  end
end
