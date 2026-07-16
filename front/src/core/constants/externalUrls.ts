import { HubspotTargetedObjectsEnum } from '~/generated/graphql'

export const DOCUMENTATION_URL = 'https://docs.getlago.com/'
export const LAGO_TAX_DOCUMENTATION_URL =
  'https://docs.getlago.com/integrations/taxes/lago-eu-taxes'
export const DOCUMENTATION_AIRBYTE = 'https://docs.airbyte.com/integrations/sources/getlago/'
export const DOCUMENTATION_SEGMENT = 'https://docs.getlago.com/integrations/usage/segment'
export const DOCUMENTATION_HIGHTTOUCH = 'https://docs.getlago.com/integrations/usage/hightouch'
export const DOCUMENTATION_OSO =
  'https://www.osohq.com/docs/develop/policies/patterns/entitlements#entitlements'
export const DOCUMENTATION_ENV_VARS =
  'https://docs.getlago.com/guide/lago-self-hosted/docker#environment-variables'
export const DOCUMENTATION_EINVOICING =
  'https://docs.getlago.com/guide/invoicing/e-invoicing/overview'
export const FEATURE_REQUESTS_URL = 'https://getlago.canny.io/feature-requests'
export const ADYEN_SUCCESS_LINK_SPEC_URL =
  'https://docs.adyen.com/api-explorer/Checkout/latest/post/payments#request-returnUrl'
export const AVALARA_TAX_CODE_DOCUMENTATION_URL = 'https://taxcode.avatax.avalara.com/'
export const buildNetsuiteCustomerUrl = (
  connectionAccountId?: string | null,
  netsuiteCustomerId?: string | null,
) => {
  return `https://${connectionAccountId}.app.netsuite.com/app/common/entity/custjob.nl?id=${netsuiteCustomerId}`
}
export const buildNetsuiteInvoiceUrl = (
  connectionAccountId?: string | null,
  netsuiteInvoiceId?: string | null,
) => {
  return `https://${connectionAccountId}.app.netsuite.com/app/accounting/transactions/custinvc.nl?id=${netsuiteInvoiceId}`
}
export const buildAnrokInvoiceUrl = (
  connectionAccountId?: string | null,
  anrokInvoiceId?: string | null,
) => {
  return `https://app.anrok.com/${connectionAccountId}/transactions/${anrokInvoiceId}`
}
export const buildAnrokCreditNoteUrl = (
  connectionAccountId?: string | null,
  anrokTaxProviderId?: string | null,
) => {
  return `https://app.anrok.com/${connectionAccountId}/transactions/${anrokTaxProviderId}`
}
export const buildNetsuiteCreditNoteUrl = (
  connectionAccountId?: string | null,
  netsuiteCreditNoteId?: string | null,
) => {
  return `https://${connectionAccountId}.app.netsuite.com/app/accounting/transactions/custcred.nl?id=${netsuiteCreditNoteId}`
}
export const buildGocardlessAuthUrl = (proxyUrl: string, lagoName: string, lagoCode: string) => {
  return `${proxyUrl}/gocardless/auth?lago_name=${lagoName}&lago_code=${lagoCode}`
}
export const buildAnrokCustomerUrl = (
  connectionAccountId?: string | null,
  anrokCustomerId?: string | null,
) => {
  return `https://app.anrok.com/${connectionAccountId}/customers/${anrokCustomerId}`
}
export const buildAvalaraCustomerUrl = (externalCustomerId?: string | null) => {
  return `https://sbx.exemptions.avalara.com/customer/${externalCustomerId}`
}
export const buildXeroCustomerUrl = (xeroCustomerId?: string | null) => {
  return `https://go.xero.com/app/contacts/contact/${xeroCustomerId}`
}
export const buildXeroInvoiceUrl = (xeroInvoiceId?: string | null) => {
  return `https://go.xero.com/app/invoicing/view/${xeroInvoiceId}`
}
export const buildXeroCreditNoteUrl = (xeroCreditNoteId?: string | null) => {
  return `https://go.xero.com/AccountsReceivable/ViewCreditNote.aspx?creditNoteID=${xeroCreditNoteId}`
}
export const buildHubspotObjectUrl = ({
  portalId,
  objectId,
  targetedObject,
}: {
  portalId: string
  objectId: string
  targetedObject: HubspotTargetedObjectsEnum
}) => {
  const targetedObjectMap = {
    [HubspotTargetedObjectsEnum.Contacts]: '0-1',
    [HubspotTargetedObjectsEnum.Companies]: '0-2',
  }

  return `https://app.hubspot.com/contacts/${portalId}/record/${targetedObjectMap[targetedObject]}/${objectId}`
}

export const buildHubspotInvoiceUrl = ({
  portalId,
  resourceId,
  externalHubspotIntegrationId,
}: {
  portalId?: string | null
  resourceId?: string | null
  externalHubspotIntegrationId?: string | null
}) => {
  return `https://app.hubspot.com/contacts/${portalId}/record/${resourceId}/${externalHubspotIntegrationId}`
}

export const buildSalesforceUrl = ({
  instanceId,
  externalCustomerId,
}: {
  instanceId: string
  externalCustomerId: string
}) => {
  // Remove last slash if it exists
  const baseUrl = instanceId.replace(RegExp('/$'), '')

  return `${baseUrl}/${externalCustomerId}`
}

export const buildStripeCustomerUrl = (stripeCustomerId: string) => {
  return `https://dashboard.stripe.com/customers/${stripeCustomerId}`
}

export const buildStripePaymentUrl = (stripePaymentId: string) => {
  return `https://dashboard.stripe.com/payments/${stripePaymentId}`
}

export const buildGoCardlessPaymentUrl = (goCardlessPaymentId: string) => {
  return `https://manage.gocardless.com/payments/${goCardlessPaymentId}`
}
export const buildAvalaraObjectId = ({
  accountId,
  companyId,
  objectId,
  isSandbox,
}: {
  accountId: string | null | undefined
  companyId: string
  objectId: string
  isSandbox: boolean
}) => {
  const sandboxDomain = isSandbox ? 'sandbox.' : ''

  return `https://${sandboxDomain}admin.avalara.com/cup/a/${accountId}/c/${companyId}/transactions/${objectId}`
}
