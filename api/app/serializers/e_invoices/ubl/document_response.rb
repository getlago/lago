# frozen_string_literal: true

module EInvoices
  module Ubl
    class DocumentResponse < BaseSerializer
      Response = Data.define(
        :code,
        :description,
        :date
      )
      Document = Data.define(
        :id,
        :issue_date,
        :type_code,
        :type,
        :description
      )

      def initialize(xml:, response:, document:, resource: nil)
        super(xml:, resource:)

        @response = response
        @document = document
      end

      def serialize
        xml.comment "Document Response"
        xml["cac"].DocumentResponse do
          xml["cac"].Response do
            xml["cbc"].ResponseCode response.code
            xml["cbc"].Description response.description
            xml["cbc"].EffectiveDate formatted_date(response.date)
          end
          xml["cac"].DocumentReference do
            xml["cbc"].ID document.id
            xml["cbc"].IssueDate formatted_date(document.issue_date)
            xml["cbc"].DocumentTypeCode document.type_code
            xml["cbc"].DocumentType document.type
            xml["cbc"].DocumentDescription document.description
          end
        end
      end

      private

      attr_accessor :response, :document
    end
  end
end
