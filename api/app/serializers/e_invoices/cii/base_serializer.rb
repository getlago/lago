# frozen_string_literal: true

module EInvoices
  module Cii
    class BaseSerializer < EInvoices::BaseSerializer
      ROOT_NAMESPACES = {
        "xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
        "xmlns:qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
        "xmlns:ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
        "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
      }.freeze

      DATEFORMAT = "%Y%m%d"

      # More date formats for UNTDID 2379 here
      # https://service.unece.org/trade/untdid/d15a/tred/tred2379.htm
      CCYYMMDD = 102
    end
  end
end
