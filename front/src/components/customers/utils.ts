import {
  Customer,
  CustomerMainInfosFragment,
  CustomerTypeEnum,
  IntegrationsListForCustomerMainInfosQuery,
} from '~/generated/graphql'

type RawIntegration = NonNullable<
  NonNullable<IntegrationsListForCustomerMainInfosQuery['integrations']>['collection']
>[number]

type Integration = Exclude<RawIntegration, { __typename?: 'OktaIntegration' }>

export const getInitials = (str: string) =>
  str.split(' ').reduce((acc, n) => (acc = acc + n[0]), '')

export const computeCustomerInitials = (
  customer?: Pick<Customer, 'name' | 'firstname' | 'lastname'> | null,
) => {
  const { name = '', firstname = '', lastname = '' } = customer ?? {}

  if (name) {
    return getInitials(name)
  }

  if (firstname || lastname) {
    return getInitials(`${firstname} ${lastname}`.trim())
  }

  return '-'
}

export const TRANSLATIONS_MAP_CUSTOMER_TYPE: Record<CustomerTypeEnum, string> = {
  [CustomerTypeEnum.Individual]: 'text_1726129457108txzr4gdkvcz',
  [CustomerTypeEnum.Company]: 'text_1726129457108raohiy4kkt3',
}

export function getConnectedIntegrations<
  TType extends Integration['__typename'],
  TResult extends Extract<Integration, { __typename: TType }>,
>(
  data: IntegrationsListForCustomerMainInfosQuery | undefined,
  customer: CustomerMainInfosFragment,
  typename: TType,
  customerKey: keyof typeof customer,
): TResult | undefined {
  if (!data) return undefined

  const integrationId = (customer?.[customerKey] as { integrationId?: string | null })
    ?.integrationId

  return data?.integrations?.collection
    ?.filter((i): i is TResult => i.__typename === typename)
    ?.find((integration) => integration.id === integrationId)
}
