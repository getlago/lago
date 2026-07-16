# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Moneyhash
      class Base < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        def resolve(**args)
          result = ::PaymentProviders::MoneyhashService
            .new(context[:current_user])
            .create_or_update(**args.merge(organization: current_organization))

          result.success? ? result.moneyhash_provider : result_error(result)
        end
      end
    end
  end
end
