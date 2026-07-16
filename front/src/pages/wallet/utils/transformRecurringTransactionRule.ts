import { GetWalletInfosForWalletFormQuery } from '~/generated/graphql'

type RecurringTransactionRuleFromQuery = NonNullable<
  NonNullable<GetWalletInfosForWalletFormQuery['wallet']>['recurringTransactionRules']
>[number]

export const transformRecurringTransactionRule = (rule: RecurringTransactionRuleFromQuery) => {
  // Extract and exclude fields that are not part of CreateRecurringTransactionRuleInput/UpdateRecurringTransactionRuleInput
  // These fields come from the GraphQL query but should not be included in the form values
  const fieldsToExclude = [
    'paymentMethodType',
    'skipInvoiceCustomSections',
    'selectedInvoiceCustomSections',
  ]

  const rules = Object.fromEntries(
    Object.entries(rule).filter(([key]) => !fieldsToExclude.includes(key)),
  ) as typeof rule

  return {
    ...rules,
    paymentMethod: {
      paymentMethodType: rule.paymentMethodType,
      paymentMethodId: rule.paymentMethod?.id,
    },
    invoiceCustomSection: {
      invoiceCustomSections: rule.selectedInvoiceCustomSections || [],
      skipInvoiceCustomSections: rule.skipInvoiceCustomSections || false,
    },
  }
}
