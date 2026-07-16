import { BillingEntityLabel } from '~/components/billingEntity/BillingEntityLabel'
import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { InvoiceCustomSectionDisplay } from '~/components/invoceCustomFooter/InvoiceCustomSectionDisplay'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { useDisplayedPaymentMethod } from '~/components/paymentMethodSelection/useDisplayedPaymentMethod'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import PremiumFeature from '~/components/premium/PremiumFeature'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { formatPaymentMethodDetails } from '~/core/formats/formatPaymentMethodDetails'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount, getCurrencyPrecision } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  FeatureFlagEnum,
  RecurringTransactionMethodEnum,
  RecurringTransactionTriggerEnum,
  WalletDetailsFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useCustomerInvoiceCustomSections } from '~/hooks/useCustomerInvoiceCustomSections'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { tw } from '~/styles/utils'

export const WALLET_INFORMATIONS_CONTAINER_TEST_ID = 'wallet-informations-container'
export const WALLET_INFORMATIONS_NO_RECURRING_TEST_ID = 'wallet-informations-no-recurring'
const WALLET_INFORMATIONS_TOPUP_TYPE_TEST_ID = 'wallet-informations-topup-type'

type WalletInformationsProps = {
  wallet?: WalletDetailsFragment | null
}

const SectionTitle = ({ title, subtitle }: { title: string; subtitle: string }) => (
  <div className="flex flex-col">
    <Typography variant="bodyHl" color="grey700">
      {title}
    </Typography>

    <Typography variant="caption" color="grey600">
      {subtitle}
    </Typography>
  </div>
)

const WalletInformations = ({ wallet }: WalletInformationsProps) => {
  const { translate } = useInternationalization()
  const {
    intlFormatDateTimeOrgaTZ,
    hasFeatureFlag,
    organization: { defaultCurrency } = {},
  } = useOrganizationInfos()
  const { isPremium } = useCurrentUser()

  const showBillingEntityRow = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

  const { data: paymentMethodsList } = usePaymentMethodsList({
    externalCustomerId: wallet?.customer?.externalId || '',
    withDeleted: false,
  })

  const displayedPaymentMethod = useDisplayedPaymentMethod(
    {
      paymentMethodType: wallet?.paymentMethodType,
      paymentMethodId: wallet?.paymentMethod?.id,
    },
    paymentMethodsList,
  )

  // Customer-level ICS data, used to decide whether to show the invoice custom
  // sections row even when the wallet has no explicit selection (fallback).
  const { data: customerIcsData } = useCustomerInvoiceCustomSections(wallet?.customer?.id || '')

  const formatAmount = (cents?: string | null) =>
    cents
      ? intlFormatNumber(Number(deserializeAmount(cents, currency) || 0), {
          currency,
          minimumFractionDigits: getCurrencyPrecision(currency),
          currencyDisplay: 'symbol',
        })
      : null

  const formatCredits = (credits?: string) =>
    credits && Number(credits) !== 0
      ? `${translate(
          'text_62da6ec24a8e24e44f812896',
          {
            amount: Number(credits),
          },
          Number(credits || 0),
        )} • ${intlFormatNumber(
          isNaN(Number(credits)) ? 0 : Number(credits) * Number(wallet?.rateAmount),

          {
            currencyDisplay: 'symbol',
            currency: wallet?.currency,
          },
        )}`
      : '-'

  if (!wallet) {
    return
  }

  const recurring = wallet?.recurringTransactionRules?.[0]

  const hasRecurringTopUpType = recurring?.method === RecurringTransactionMethodEnum.Target

  const recurringTopUpType = translate(
    recurring?.grantsTargetTopUp
      ? 'text_17800474832056s97uz7bjy7'
      : 'text_178004748320594nw5fau04a',
  )

  const currency = wallet?.currency || defaultCurrency || CurrencyEnum.Usd

  const paidTopUpMinAmountCents = formatAmount(wallet?.paidTopUpMinAmountCents)

  const paidTopUpMaxAmountCents = formatAmount(wallet?.paidTopUpMaxAmountCents)

  const sectionClassName = 'flex flex-col gap-6 pb-12 shadow-b'
  const chipContainerClassName = 'flex gap-3 mt-1'

  // Resolve the displayed payment method exactly like the subscription overview
  // (PaymentInvoiceDetails): the `paymentMethodId` lets a specific provider card
  // resolve from the customer's list (isInherited=false), so the inherited badge
  // only shows for an actual customer-default fallback.
  const inheritedSuffix = displayedPaymentMethod.isInherited
    ? ` (${translate('text_1764327933607jgtpungo2pp')})`
    : ''

  const paymentMethodValue = (() => {
    if (displayedPaymentMethod.isManual) {
      return `${translate('text_173799550683709p2rqkoqd5')}${inheritedSuffix}`
    }

    if (displayedPaymentMethod.paymentMethod) {
      const formatted =
        formatPaymentMethodDetails(displayedPaymentMethod.paymentMethod.details) ||
        translate('text_1771854080250kv3j6oa9nxj', {
          date: intlFormatDateTimeOrgaTZ(displayedPaymentMethod.paymentMethod.createdAt).date,
        })

      return `${formatted}${inheritedSuffix}`
    }

    return '-'
  })()

  // Show the invoice custom sections row whenever there is content to display —
  // explicit selection, an explicit skip, or an inherited customer/billing-entity
  // fallback — mirroring the subscription overview (instead of only when selected).
  const hasInvoiceCustomSectionsContent = (() => {
    if (wallet?.skipInvoiceCustomSections === true) return true
    if (wallet?.selectedInvoiceCustomSections?.length) return true
    if (!customerIcsData) return false

    const {
      configurableInvoiceCustomSections: sections,
      hasOverwrittenInvoiceCustomSectionsSelection: hasOverwritten,
      skipInvoiceCustomSections: customerSkip,
    } = customerIcsData

    return (!hasOverwritten && !!customerSkip) || (!customerSkip && sections.length > 0)
  })()

  return (
    <div data-test={WALLET_INFORMATIONS_CONTAINER_TEST_ID} className="flex flex-col gap-12">
      <section className={sectionClassName}>
        <SectionTitle
          title={translate('text_1772536695408sm7gfyxpi58')}
          subtitle={translate('text_1772536695408zb493jkuibc')}
        />

        <DetailsPage.InfoGrid
          grid={[
            { label: translate('text_1772536695408sddzumtfq2t'), value: wallet?.name },
            {
              label: translate('text_1772536695408yflknt6y6q4'),
              value: wallet?.code ? (
                <TypographyWithCopy variant="body" color="grey700">
                  {wallet.code}
                </TypographyWithCopy>
              ) : undefined,
            },
            {
              label: translate('text_1750411499858su5b7bbp5t9'),
              value: translate('text_62da6ec24a8e24e44f812872', {
                rateAmount: intlFormatNumber(wallet.rateAmount, {
                  currency,
                  minimumFractionDigits: getCurrencyPrecision(currency),
                  currencyDisplay: 'symbol',
                }),
              }),
            },
            {
              label: translate('text_1755697949545w7vb1hox4n5'),
              value: wallet?.priority || '-',
            },
            {
              label: translate('text_1772536695408pz0actopowa'),
              value: wallet?.expirationAt
                ? intlFormatDateTimeOrgaTZ(wallet?.expirationAt)?.date
                : '-',
            },
            showBillingEntityRow
              ? {
                  label: translate('text_17436114971570doqrwuwhf0'),
                  value: (
                    <BillingEntityLabel
                      ownId={wallet?.billingEntityId}
                      customerEntity={wallet?.customer?.billingEntity}
                    />
                  ),
                }
              : { label: '', value: '' },
            {
              label: translate('text_1758286730208kztcznofxvr'),
              value: paidTopUpMinAmountCents || translate('text_1772536695408bfc3c38pg36'),
              valueClassName: !paidTopUpMinAmountCents ? 'text-grey-600' : '',
            },
            {
              label: translate('text_1758286730208ey87jz8nzuz'),
              value: paidTopUpMaxAmountCents || translate('text_1772536695408bfc3c38pg36'),
              valueClassName: !paidTopUpMaxAmountCents ? 'text-grey-600' : '',
            },
          ]}
        />
      </section>

      {(!!wallet?.appliesTo?.feeTypes?.length || !!wallet?.appliesTo?.billableMetrics?.length) && (
        <section className={sectionClassName}>
          <SectionTitle
            title={translate('text_1772536695408hukog0udwpx')}
            subtitle={translate('text_1772536695408txbgkg82nhy')}
          />

          <DetailsPage.InfoGrid
            grid={[
              ...(!!wallet?.appliesTo?.feeTypes?.length
                ? [
                    {
                      label: translate('text_17730433243428xpil56gqtb'),
                      value: (
                        <div className={chipContainerClassName}>
                          {wallet.appliesTo.feeTypes.map((feeType) => (
                            <Chip key={`wallet-applies-to-fee-type-${feeType}`} label={feeType} />
                          ))}
                        </div>
                      ),
                    },
                    { label: '', value: '' },
                  ]
                : []),
              ...(!!wallet?.appliesTo?.billableMetrics?.length
                ? [
                    {
                      label: translate('text_17730433243428xpil56gqtb'),
                      value: (
                        <div className={chipContainerClassName}>
                          {wallet.appliesTo.billableMetrics.map((bm) => (
                            <Chip
                              key={`wallet-applies-to-billable-metric-${bm.name}`}
                              label={bm.name}
                            />
                          ))}
                        </div>
                      ),
                    },
                  ]
                : []),
            ]}
          />
        </section>
      )}

      {(paymentMethodValue !== '-' || hasInvoiceCustomSectionsContent) && (
        <section className={sectionClassName}>
          <SectionTitle
            title={translate('text_1772536695408rpehpvkgn9s')}
            subtitle={translate('text_1772536695408eev9wm37z9t')}
          />

          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_1773043324341qj7t72i7qnk'),
                value: paymentMethodValue,
              },
              { label: '', value: '' },
              ...(hasInvoiceCustomSectionsContent
                ? [
                    {
                      label: translate('text_1773043324342n1x2iltnxvw'),
                      value: (
                        <InvoiceCustomSectionDisplay
                          selectedSections={wallet?.selectedInvoiceCustomSections}
                          skipSections={wallet?.skipInvoiceCustomSections}
                          customerId={wallet?.customer?.id}
                          viewType={ViewTypeEnum.WalletTopUp}
                        />
                      ),
                    },
                  ]
                : []),
            ]}
          />
        </section>
      )}

      <section className={tw(sectionClassName, 'shadow-b-none')}>
        <SectionTitle
          title={translate('text_1772536695409spdoskvq4w5')}
          subtitle={translate('text_1773043324341of5enpi3z28')}
        />

        {!isPremium && (
          <PremiumFeature
            title={translate('text_1773043324341b2vsoaxinkl')}
            description={translate('text_17730433243413krwjwou222')}
            feature={translate('text_1773043324341c2yyjb2fjwu')}
          />
        )}

        {isPremium && !recurring && (
          <Typography
            data-test={WALLET_INFORMATIONS_NO_RECURRING_TEST_ID}
            variant="caption"
            color="grey600"
          >
            {translate('text_1773043324341vyv0cdxzlys')}
          </Typography>
        )}

        {isPremium && recurring && (
          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_6657c29c84ad4500ad764ed7'),
                value:
                  recurring?.method === RecurringTransactionMethodEnum.Fixed
                    ? translate('text_6657cdd8cea6bf010e1ce128')
                    : translate('text_6657c34670561c0127132da4'),
              },
              {
                label: translate('text_1773043324341gpkiojxh628'),
                value: recurring?.transactionName || '-',
              },
              {
                label: translate('text_1773043324341q5g4muycilq'),
                value: formatCredits(recurring?.paidCredits),
              },
              {
                label: translate('text_1773043324341cnkdf7j5dmp'),
                value: formatCredits(recurring?.grantedCredits),
              },
              ...(recurring?.trigger === RecurringTransactionTriggerEnum.Interval
                ? [
                    {
                      label: translate('text_6657c29c84ad4500ad764ee1'),
                      value: translate('text_1773043324341kgvvw9ykx6a'),
                    },
                    {
                      label: translate('text_1773043324341ht718cwl1ub'),
                      value: recurring?.interval
                        ? translate(getIntervalTranslationKey[recurring?.interval])
                        : '-',
                    },
                  ]
                : [
                    {
                      label: translate('text_6657c29c84ad4500ad764ee1'),
                      value: translate('text_1773043324341dd9c0u4ilhg'),
                    },
                    {
                      label: translate('text_6560809c38fb9de88d8a5315'),
                      value: recurring.thresholdCredits
                        ? translate(
                            'text_62da6ec24a8e24e44f812896',
                            {
                              amount: Number(recurring?.thresholdCredits),
                            },
                            Number(recurring?.thresholdCredits || 0),
                          )
                        : '-',
                    },
                  ]),
              ...(hasRecurringTopUpType
                ? [
                    {
                      label: translate('text_1780047483204bk0fhgkeisn'),
                      value: (
                        <span data-test={WALLET_INFORMATIONS_TOPUP_TYPE_TEST_ID}>
                          {recurringTopUpType}
                        </span>
                      ),
                    },
                  ]
                : []),
              {
                label: translate('text_1772536695408pz0actopowa'),
                value: recurring?.expirationAt
                  ? intlFormatDateTimeOrgaTZ(recurring?.expirationAt)?.date
                  : '-',
              },
            ]}
          />
        )}
      </section>
    </div>
  )
}

export default WalletInformations
