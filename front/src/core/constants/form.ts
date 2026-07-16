import {
  BillingTimeEnum,
  ChargeModelEnum,
  CouponFrequency,
  CouponTypeEnum,
  FixedChargeChargeModelEnum,
  HubspotTargetedObjectsEnum,
  InvoiceAppliedTaxOnWholeInvoiceCodeEnum,
  PlanInterval,
  PrivilegeValueTypeEnum,
} from '~/generated/graphql'

/**** Errors ****/
export enum FORM_ERRORS_ENUM {
  existingCode = 'existingCode',
  invalidGroupValue = 'invalidGroupValue',
}
export const dateErrorCodes = {
  wrongFormat: 'wrongFormat',
  shouldBeInFuture: 'shouldBeInFuture',
  shouldBeFutureAndBiggerThanSubscriptionAt: 'shouldBeFutureAndBiggerThanSubscriptionAt',
  shouldBeFutureAndBiggerThanFromDatetime: 'shouldBeFutureAndBiggerThanFromDatetime',
} as const
export const MIN_AMOUNT_SHOULD_BE_LOWER_THAN_MAX_ERROR = 'minAmountShouldBeLowerThanMax'

/**** Selectors ****/
export const MUI_INPUT_BASE_ROOT_CLASSNAME = 'MuiInputBase-root'
export const MUI_BUTTON_BASE_ROOT_CLASSNAME = 'MuiButtonBase-root'
// Plans
export const SEARCH_ADD_ON_IN_FIXED_CHARGE_DRAWER_INPUT_CLASSNAME =
  'searchAddOnInFixedChargeDrawerInput'
export const SEARCH_BILLABLE_METRIC_IN_USAGE_CHARGE_DRAWER_INPUT_CLASSNAME =
  'searchBillableMetricInUsageChargeDrawerInput'
export const SEARCH_TAX_INPUT_FOR_PLAN_CLASSNAME = 'searchTaxForPlanInput'
export const SEARCH_TAX_INPUT_FOR_CHARGE_CLASSNAME = 'searchTaxForChargeInput'
export const SEARCH_TAX_INPUT_FOR_MIN_COMMITMENT_CLASSNAME = 'searchTaxForMinCommitmentInput'
export const SEARCH_FILTER_FOR_CHARGE_CLASSNAME = 'searchFilterForChargeInput'
export const SEARCH_PRICING_GROUP_KEY_INPUT_CLASSNAME = 'searchPricingGroupKeyInput'
export const SEARCH_FEATURE_SELECT_OPTIONS_INPUT_CLASSNAME = 'searchFeatureSelectOptionsInput'
export const SEARCH_FEATURE_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME =
  'searchFeaturePrivilegeSelectOptionsInput'
export const SEARCH_SUBSCRIPTION_ENTITLEMENT_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME =
  'searchSubscriptionEntitlementPrivilegeSelectOptionsInput'
export const ONE_TIER_EXAMPLE_UNITS = 10
// AddOns
export const SEARCH_TAX_INPUT_FOR_ADD_ON_CLASSNAME = 'searchTaxForAddOnInput'
// Invoices
export const SEARCH_TAX_INPUT_FOR_INVOICE_ADD_ON_CLASSNAME = 'searchTaxForInvoiceAddOnInput'
export const ADD_ITEM_FOR_INVOICE_INPUT_NAME = 'addItemInput'
// Customer
export const SEARCH_TAX_INPUT_FOR_CUSTOMER_CLASSNAME = 'searchTaxForCustomerInput'
export const ADD_CUSTOMER_PAYMENT_PROVIDER_ACCORDION = 'addCustomerPaymentProviderAccordion'
export const ADD_CUSTOMER_ACCOUNTING_PROVIDER_ACCORDION = 'addCustomerAccountingProviderAccordion'
export const ADD_CUSTOMER_TAX_PROVIDER_ACCORDION = 'addCustomerTaxProviderAccordion'
export const ADD_CUSTOMER_CRM_PROVIDER_ACCORDION = 'addCustomerCrmProviderAccordion'
// Wallets
export const SEARCH_APPLIES_TO_FEE_TYPE_CLASSNAME = 'searchAppliesToFeeTypeInput'
export const SEARCH_APPLIES_TO_BILLABLE_METRIC_CLASSNAME = 'searchAppliesToBillableMetricInput'
// Features
export const SEARCH_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME = 'searchPrivilegeSelectOptionsInput'

/**** DATA ****/
// Plan form types
export const FORM_TYPE_ENUM = {
  creation: 'creation',
  edition: 'edition',
  duplicate: 'duplicate',
  upgradeDowngrade: 'upgradeDowngrade',
} as const
// Charges
export const ALL_CHARGE_MODELS = {
  ...ChargeModelEnum,
  ...FixedChargeChargeModelEnum,
} as const

export type AnyChargeModel = ChargeModelEnum | FixedChargeChargeModelEnum
// Filters
export const ALL_FILTER_VALUES = '__ALL_FILTER_VALUES__'

/**** Translations ****/
export const getIntervalTranslationKey = {
  [PlanInterval.Monthly]: 'text_624453d52e945301380e49aa',
  [PlanInterval.Quarterly]: 'text_64d6357b00dea100ad1cb9e9',
  [PlanInterval.Weekly]: 'text_62b32ec6b0434070791c2d4c',
  [PlanInterval.Semiannual]: 'text_1756372772688xutwcgyvjhw',
  [PlanInterval.Yearly]: 'text_624453d52e945301380e49ac',
}

export const getCouponTypeTranslationKey = {
  [CouponTypeEnum.FixedAmount]: 'text_632d68358f1fedc68eed3e60',
  [CouponTypeEnum.Percentage]: 'text_632d68358f1fedc68eed3e66',
}

export const getCouponFrequencyTranslationKey = {
  [CouponFrequency.Once]: 'text_632d68358f1fedc68eed3ea3',
  [CouponFrequency.Recurring]: 'text_632d68358f1fedc68eed3e64',
  [CouponFrequency.Forever]: 'text_63c83a3476e46bc6ab9d85d6',
}

export enum LocalTaxProviderErrorsEnum {
  CurrencyCodeNotSupported = 'text_17238318811308wqpult4i7r',
  CustomerAddressError = 'text_1723831881130x4cfh6qr6o8',
  ProductExternalIdUnknown = 'text_1723831881130g8hv6qzqe57',
  GenericErrorMessage = 'text_17238318811307ghoc4v7mt9',
}

export const chargeModelLookupTranslation: Record<AnyChargeModel, string> = {
  graduated: 'text_65201b8216455901fe273e11',
  graduated_percentage: 'text_65201b8216455901fe273e32',
  package: 'text_65201b8216455901fe273de5',
  percentage: 'text_65201b8216455901fe273df8',
  standard: 'text_65201b8216455901fe273dd6',
  volume: 'text_65201b8216455901fe273e4f',
  custom: 'text_6641dd21c0cffd005b5e2a8b',
  dynamic: 'text_1727770512968tj58xr3h64p',
}

export const getChargeModelHelpTextTranslationKey = {
  [ChargeModelEnum.Percentage]: 'text_62ff5d01a306e274d4ffcc06',
  [ChargeModelEnum.Graduated]: 'text_62793bbb599f1c01522e91a1',
  [ChargeModelEnum.GraduatedPercentage]: 'text_64de472463e2da6b31737db8',
  [ChargeModelEnum.Package]: 'text_6282085b4f283b010265586c',
  [ChargeModelEnum.Standard]: 'text_624d9adba93343010cd14ca7',
  [ChargeModelEnum.Volume]: 'text_6304e74aab6dbc18d615f38a',
  [ChargeModelEnum.Custom]: 'text_663dea5702b60301d8d064fe',
  [ChargeModelEnum.Dynamic]: 'text_1727711757973zhs7w84v44t',
}

export const appliedTaxEnumedTaxCodeTranslationKey: Record<
  InvoiceAppliedTaxOnWholeInvoiceCodeEnum,
  string
> = {
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.CustomerExempt]: 'text_1724857130376douaqt98pna',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.TransactionExempt]: 'text_1724857130376douaqt98pna',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.ReverseCharge]: 'text_1724857130376w85w86kutdb',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.JurisNotTaxed]: 'text_1724857130376u3cph3amxmh',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.NotCollecting]: 'text_1724857130376u3cph3amxmh',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.JurisHasNoTax]: 'text_1724857130376u3cph3amxmh',
  [InvoiceAppliedTaxOnWholeInvoiceCodeEnum.UnknownTaxation]: 'text_17250100329108guatmyl9tj',
}

export const getHubspotTargetedObjectTranslationKey: Record<HubspotTargetedObjectsEnum, string> = {
  [HubspotTargetedObjectsEnum.Companies]: 'text_1727190044775zgd0l3fpwdj',
  [HubspotTargetedObjectsEnum.Contacts]: 'text_1727190044775keiwznwv16s',
}

export const getTargetedObjectTranslationKey: Record<HubspotTargetedObjectsEnum, string> = {
  [HubspotTargetedObjectsEnum.Companies]: 'text_1727281892403pmg1yza7x1e',
  [HubspotTargetedObjectsEnum.Contacts]: 'text_1729003289241opvevwwhr7n',
}

export const getPrivilegeValueTypeTranslationKey: Record<PrivilegeValueTypeEnum, string> = {
  [PrivilegeValueTypeEnum.Boolean]: 'text_1752846323920oit5ijknakw',
  [PrivilegeValueTypeEnum.Integer]: 'text_1752846323920cemx0vj1r16',
  [PrivilegeValueTypeEnum.String]: 'text_1752846323920ueyo3sru7na',
  [PrivilegeValueTypeEnum.Select]: 'text_1752846323920ry5qxxvzrg7',
}

export const getBillingTimeEnumTranslationKey: Record<BillingTimeEnum, string> = {
  [BillingTimeEnum.Anniversary]: 'text_1776883338722o7e5us2iq7h',
  [BillingTimeEnum.Calendar]: 'text_177688333872224m25xpq3m2',
}
