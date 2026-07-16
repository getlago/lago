# frozen_string_literal: true

module Charges
  module Validators
    class PackageService < Charges::Validators::BaseService
      def valid?
        validate_amount
        validate_free_units
        validate_package_size

        super
      end

      private

      def amount
        properties["amount"]
      end

      def validate_amount
        return if ::Validators::DecimalAmountService.new(amount).valid_amount?

        add_error(field: :amount, error_code: "invalid_amount")
      end

      def package_size
        properties["package_size"]
      end

      def validate_package_size
        return if package_size.present? && package_size.is_a?(Integer) && package_size.positive?

        add_error(field: :package_size, error_code: "invalid_package_size")
      end

      def free_units
        properties["free_units"]
      end

      def validate_free_units
        return if free_units.present? && free_units.is_a?(Integer) && free_units >= 0

        add_error(field: :free_units, error_code: "invalid_free_units")
      end
    end
  end
end
