# frozen_string_literal: true

module IdempotencyRecords
  class CreateService < BaseService
    Result = BaseResult[:idempotency_record]

    def initialize(idempotency_key:, resource: nil)
      @idempotency_key = idempotency_key
      @resource = resource

      super
    end

    def call
      ApplicationRecord.transaction do
        idempotency_record = IdempotencyRecord.create!(
          organization_id: resource&.organization_id,
          idempotency_key: idempotency_key,
          resource: resource
        )

        result.idempotency_record = idempotency_record
      end
      result
    rescue ActiveRecord::RecordNotUnique
      # Return an error when a record with this idempotency key already exists
      result.single_validation_failure!(
        field: :idempotency_key,
        error_code: "already_exists"
      )
    end

    private

    attr_reader :idempotency_key, :resource
  end
end
