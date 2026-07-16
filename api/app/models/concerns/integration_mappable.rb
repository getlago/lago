# frozen_string_literal: true

module IntegrationMappable
  extend ActiveSupport::Concern

  included do
    has_many :integration_mappings, as: :mappable, class_name: "IntegrationMappings::BaseMapping", dependent: :destroy
    has_many :netsuite_mappings, as: :mappable, class_name: "IntegrationMappings::NetsuiteMapping", dependent: :destroy
    has_many :xero_mappings, as: :mappable, class_name: "IntegrationMappings::XeroMapping", dependent: :destroy
  end
end
