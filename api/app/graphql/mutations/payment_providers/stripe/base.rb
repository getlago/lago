# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Stripe
      class Base < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        def resolve(**args)
          result = ::PaymentProviders::StripeService
            .new(context[:current_user])
            .create_or_update(**args.merge(organization_id: current_organization.id))

          result.success? ? result.stripe_provider : result_error(result)
        end
      end
    end
  end
end
