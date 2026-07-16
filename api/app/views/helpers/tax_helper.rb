# frozen_string_literal: true

class TaxHelper
  def self.applied_taxes(object)
    template = if object.nil?
      'div = "0.0%"'
    else
      <<~SLIM_TEMPLATE
        - (applied_taxes.present? ? applied_taxes.order(tax_rate: :desc).pluck(:tax_rate) : [0.0]).each do |tax|
          div = tax.to_s + "%"
      SLIM_TEMPLATE
    end

    Slim::Template.new { template }.render(object)
  end
end
