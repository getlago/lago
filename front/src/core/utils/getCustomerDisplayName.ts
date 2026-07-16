import { Customer } from '~/generated/graphql'

interface GetCustomerDisplayNameArgs {
  customer: Partial<Pick<Customer, 'name' | 'firstname' | 'lastname'>> | null | undefined
  fallback?: string
}

export const getCustomerDisplayName = ({
  customer,
  fallback = '',
}: GetCustomerDisplayNameArgs): string => {
  if (!customer) return fallback

  return (
    customer.name || [customer.firstname, customer.lastname].filter(Boolean).join(' ') || fallback
  )
}
