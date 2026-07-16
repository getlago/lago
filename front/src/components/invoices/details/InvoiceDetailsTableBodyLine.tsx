import { gql } from '@apollo/client'
import Stack from '@mui/material/Stack'
import { tw } from 'lago-design-system'
import { memo, RefObject, useMemo } from 'react'
import { useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { useViewFeeDetailsDrawer } from '~/components/invoices/details/ViewFeeDetailsDrawer'
import { FeeMetadata } from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import {
  AdjustedFeeTypeEnum,
  ChargeModelEnum,
  CurrencyEnum,
  FeeForCreateFeeDrawerFragment,
  FeeForDeleteAdjustmentFeeDialogFragmentDoc,
  FeeForEditfeeDrawerFragmentDoc,
  FeeForInvoiceDetailsTableBodyLineFragment,
  FeeForInvoiceDetailsTableBodyLineGraduatedFragmentDoc,
  FeeForInvoiceDetailsTableBodyLineGraduatedPercentageFragmentDoc,
  FeeForInvoiceDetailsTableBodyLinePackageFragmentDoc,
  FeeForInvoiceDetailsTableBodyLinePercentageFragmentDoc,
  FeeForInvoiceDetailsTableBodyLineVolumeFragmentDoc,
  FeeForViewFeeDetailsDrawerFragmentDoc,
  FeeTypesEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { OnRegeneratedFeeAdd } from '~/pages/CustomerInvoiceRegenerate'
import { MenuPopper, PopperOpener } from '~/styles'

import { useDeleteAdjustedFeeDialog } from './DeleteAdjustedFeeDialog'
import { EditFeeDrawerRef } from './EditFeeDrawer'
import { CopyFeeIdButton, FeeActionsCell, ViewFeeDetailsButton } from './FeeActionsCell'
import { InvoiceDetailsTableBodyLineGraduated } from './InvoiceDetailsTableBodyLineGraduated'
import { InvoiceDetailsTableBodyLineGraduatedPercentage } from './InvoiceDetailsTableBodyLineGraduatedPercentage'
import { InvoiceDetailsTableBodyLinePackage } from './InvoiceDetailsTableBodyLinePackage'
import { InvoiceDetailsTableBodyLinePercentage } from './InvoiceDetailsTableBodyLinePercentage'
import { InvoiceDetailsTableBodyLineVolume } from './InvoiceDetailsTableBodyLineVolume'
import { FEE_ROW_TEST_ID_PREFIX } from './invoiceDetailsTestIds'

gql`
  fragment FeeForInvoiceDetailsTableBodyLine on Fee {
    id
    units
    preciseUnitAmount
    amountCents
    eventsCount
    adjustedFee
    adjustedFeeType
    succeededAt
    feeType
    description
    groupedBy
    itemName
    properties {
      fromDatetime
      toDatetime
    }
    pricingUnitUsage {
      amountCents
      conversionRate
      shortName
      preciseUnitAmount
    }
    charge {
      id
      chargeModel
      minAmountCents
      payInAdvance
      prorated
      billableMetric {
        id
        name
        recurring
      }
    }
    trueUpParentFee {
      id
    }
    appliedTaxes {
      id
      taxRate
      tax {
        id
        name
        code
        rate
      }
    }
    amountDetails {
      freeUnits # for package charge model
      fixedFeeUnitAmount # for percentage charge model
      flatUnitAmount # for volume charge model
      graduatedRanges {
        toValue
      }
      graduatedPercentageRanges {
        toValue
      }
    }

    ...FeeForInvoiceDetailsTableBodyLineGraduated
    ...FeeForInvoiceDetailsTableBodyLineGraduatedPercentage
    ...FeeForInvoiceDetailsTableBodyLineVolume
    ...FeeForInvoiceDetailsTableBodyLinePackage
    ...FeeForInvoiceDetailsTableBodyLinePercentage
    ...FeeForEditfeeDrawer
    ...FeeForDeleteAdjustmentFeeDialog
    ...FeeForViewFeeDetailsDrawer
  }

  ${FeeForInvoiceDetailsTableBodyLineGraduatedFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLineGraduatedPercentageFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLineVolumeFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLinePackageFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLinePercentageFragmentDoc}
  ${FeeForEditfeeDrawerFragmentDoc}
  ${FeeForDeleteAdjustmentFeeDialogFragmentDoc}
  ${FeeForViewFeeDetailsDrawerFragmentDoc}
`

type InvoiceDetailsTableBodyLineBaseProps = {
  canHaveUnitPrice: boolean
  currency: CurrencyEnum
  displayName: string
  fee: (FeeForInvoiceDetailsTableBodyLineFragment & { metadata: FeeMetadata }) | undefined
  isDraftInvoice: boolean
  hideVat?: boolean
  displayFeeBoundaries?: boolean
  editFeeDrawerRef?: RefObject<EditFeeDrawerRef>
  succeededDate?: string
  hasTaxProviderError?: boolean
}

type RegenerateModeProps = {
  onAdd: OnRegeneratedFeeAdd
  onDelete: (id: string) => void
  invoiceSubscriptionId: string
  localFees: FeeForCreateFeeDrawerFragment[]
}

type InvoiceDetailsTableBodyLineProps =
  | (InvoiceDetailsTableBodyLineBaseProps & RegenerateModeProps)
  | (InvoiceDetailsTableBodyLineBaseProps & {
      onAdd?: undefined
      onDelete?: undefined
      invoiceSubscriptionId?: undefined
      localFees?: undefined
    })

export const getRegenerateModeProps = (
  onAdd: OnRegeneratedFeeAdd | undefined,
  onDelete: ((id: string) => void) | undefined,
  localFees: FeeForCreateFeeDrawerFragment[] | undefined,
  invoiceSubscriptionId: string,
): RegenerateModeProps | Record<string, never> => {
  if (onAdd && onDelete && localFees) {
    return { onAdd, onDelete, localFees, invoiceSubscriptionId }
  }
  return {}
}

export const calculateIfDetailsShouldBeDisplayed = (
  fee: (FeeForInvoiceDetailsTableBodyLineFragment & { metadata: FeeMetadata }) | undefined,
  isTrueUpFee: boolean,
  canHaveUnitPrice: boolean,
): boolean => {
  const isValidGraduatedToHaveDetails =
    fee?.charge?.chargeModel === ChargeModelEnum.Graduated && !fee.charge.prorated
  const isValidChargeModelToHaveDetails =
    isValidGraduatedToHaveDetails ||
    fee?.charge?.chargeModel === ChargeModelEnum.Volume ||
    fee?.charge?.chargeModel === ChargeModelEnum.Package ||
    fee?.charge?.chargeModel === ChargeModelEnum.Percentage ||
    fee?.charge?.chargeModel === ChargeModelEnum.GraduatedPercentage

  const isInArrears = !fee?.charge?.payInAdvance
  const isValidAdvanceRecurringVolume =
    fee?.charge?.chargeModel === ChargeModelEnum.Volume && !!fee?.amountDetails?.flatUnitAmount
  const isValidAdvanceRecurringPackage =
    fee?.charge?.chargeModel === ChargeModelEnum.Package && !!fee?.amountDetails?.freeUnits
  const isValidAdvanceGraduated =
    fee?.charge?.chargeModel === ChargeModelEnum.Graduated &&
    !!fee?.amountDetails?.graduatedRanges?.[0].toValue
  const isValidAdvanceGraduatedPercentage =
    fee?.charge?.chargeModel === ChargeModelEnum.GraduatedPercentage &&
    !!fee?.amountDetails?.graduatedPercentageRanges?.[0].toValue
  // Only recurring fee in advance that are full can have details
  const isAdvanceRecurring =
    !!fee?.charge?.payInAdvance &&
    !!fee?.charge?.billableMetric?.recurring &&
    (isValidAdvanceRecurringVolume ||
      isValidAdvanceRecurringPackage ||
      isValidAdvanceGraduated ||
      isValidAdvanceGraduatedPercentage)

  // Always show details for percentage charge if it has fixedFeeUnitAmount
  const isPercentageWithDetailsAndNotOnlyRate =
    fee?.charge?.chargeModel === ChargeModelEnum.Percentage &&
    (!!Number(fee?.amountDetails?.fixedFeeUnitAmount) ||
      !!Number(fee?.amountDetails?.freeUnits) ||
      !!Number(fee?.amountDetails?.freeEvents) ||
      !!Number(fee?.amountDetails?.minMaxAdjustmentTotalAmount))

  const isSubscriptionFee = !!fee?.metadata?.isSubscriptionFee

  const shouldDisplayFeeDetail =
    !!fee &&
    !isTrueUpFee &&
    fee.adjustedFeeType !== AdjustedFeeTypeEnum.AdjustedAmount &&
    !isSubscriptionFee &&
    (isInArrears || isAdvanceRecurring || isPercentageWithDetailsAndNotOnlyRate) &&
    fee?.charge?.chargeModel !== ChargeModelEnum.Standard &&
    fee.feeType !== FeeTypesEnum.AddOn &&
    fee.feeType !== FeeTypesEnum.Credit &&
    isValidChargeModelToHaveDetails &&
    canHaveUnitPrice

  return shouldDisplayFeeDetail
}

export const InvoiceDetailsTableBodyLine = memo(
  ({
    canHaveUnitPrice,
    currency,
    displayName,
    editFeeDrawerRef,
    fee,
    hideVat,
    isDraftInvoice,
    displayFeeBoundaries,
    succeededDate,
    hasTaxProviderError,
    onAdd,
    onDelete,
    invoiceSubscriptionId,
    localFees,
  }: InvoiceDetailsTableBodyLineProps) => {
    const { invoiceId = '' } = useParams()
    const { translate } = useInternationalization()
    const viewFeeDetails = useViewFeeDetailsDrawer()
    const { openDeleteAdjustedFeeDialog } = useDeleteAdjustedFeeDialog()
    const chargeModel = fee?.charge?.chargeModel
    const isTrueUpFee = !!fee?.metadata?.isTrueUpFee
    const isCommitmentFee = !!fee?.metadata?.isCommitmentFee
    const isAdjustedFee = !!fee?.adjustedFee
    const pricingUnitUsage = fee?.pricingUnitUsage
    const subLabel = useMemo(() => {
      if (!canHaveUnitPrice) return undefined
      if (fee?.description) return fee.description
      if (chargeModel === ChargeModelEnum.Percentage) {
        return translate('text_659e67cd63512ef53284303e', { eventsCount: fee?.eventsCount })
      }
      if (fee?.charge?.prorated) {
        return translate('text_659e6b6b8e57e6ff88a34930')
      }
      if (isTrueUpFee) {
        return translate('text_659e67cd63512ef53284305a', {
          amount: intlFormatNumber(deserializeAmount(fee?.charge?.minAmountCents, currency), {
            currencyDisplay: 'symbol',
            currency,
            minimumFractionDigits: 2,
            maximumFractionDigits: 15,
            pricingUnitShortName: pricingUnitUsage?.shortName,
          }),
        })
      }
      return undefined
    }, [canHaveUnitPrice, fee, chargeModel, translate, isTrueUpFee, currency, pricingUnitUsage])

    const shouldDisplayFeeDetail = calculateIfDetailsShouldBeDisplayed(
      fee,
      isTrueUpFee,
      canHaveUnitPrice,
    )

    const taxRateDisplay = useMemo(() => {
      if (hasTaxProviderError) {
        return '-'
      }

      if (fee?.appliedTaxes?.length) {
        return fee.appliedTaxes.map((appliedTaxes) => (
          <Typography
            key={`fee-${fee.id}-applied-tax-${appliedTaxes.id}`}
            className="whitespace-nowrap"
            variant="body"
            color="grey700"
          >
            {intlFormatNumber(appliedTaxes.taxRate / 100 || 0, {
              style: 'percent',
            })}
          </Typography>
        ))
      }

      return '0%'
    }, [fee, hasTaxProviderError])

    const FeeActions = () => <FeeActionsCell fee={fee} />

    const handleRowClick = () => {
      if (fee) viewFeeDetails.open(fee)
    }
    const rowClickableClass = fee ? 'cursor-pointer hover:bg-grey-100' : undefined

    return (
      <>
        <tr
          data-test={fee ? `${FEE_ROW_TEST_ID_PREFIX}-${fee.id}` : undefined}
          className={tw(rowClickableClass, {
            'has-details': shouldDisplayFeeDetail || !!pricingUnitUsage,
            '[&_td:last-child]:!pr-0': !!pricingUnitUsage && !isDraftInvoice,
          })}
          onClick={fee ? handleRowClick : undefined}
        >
          <td colSpan={shouldDisplayFeeDetail ? 5 : 1}>
            <Stack direction="row" spacing={1} alignItems="center">
              <Typography variant="bodyHl" color="grey700">
                {displayName}
              </Typography>
              {isAdjustedFee && isDraftInvoice && (
                <Typography variant="caption" color="grey600">
                  {translate('text_65a6b4e2cb38d9b70ec53dec')}
                </Typography>
              )}
            </Stack>
            {displayFeeBoundaries &&
              !!fee?.properties?.fromDatetime &&
              !!fee?.properties?.toDatetime && (
                <Typography variant="caption" color="grey600">
                  {translate('text_633dae57ca9a923dd53c2097', {
                    fromDate: intlFormatDateTime(fee.properties.fromDatetime).date,
                    toDate: intlFormatDateTime(fee.properties.toDatetime).date,
                  })}
                </Typography>
              )}
            {(succeededDate || !!subLabel) && (
              <Typography variant="caption" color="grey600">
                {succeededDate}
                {succeededDate && !!subLabel && ' • '}
                {subLabel}
              </Typography>
            )}
          </td>
          {/* Basic line infos */}
          {!shouldDisplayFeeDetail && (
            <>
              <td>
                <Typography variant="body" color="grey700">
                  {intlFormatNumber(fee?.units || 0, {
                    style: 'decimal',
                    maximumFractionDigits: 6,
                  })}
                </Typography>
              </td>
              {canHaveUnitPrice && (
                <>
                  {chargeModel === ChargeModelEnum.Percentage &&
                  fee?.adjustedFeeType !== AdjustedFeeTypeEnum.AdjustedAmount ? (
                    <td>
                      <Typography variant="body" color="grey700">
                        {fee?.amountDetails?.rate}%
                      </Typography>
                    </td>
                  ) : (
                    <td>
                      <Typography variant="body" color="grey700">
                        {intlFormatNumber(
                          pricingUnitUsage?.preciseUnitAmount || fee?.preciseUnitAmount || 0,
                          {
                            pricingUnitShortName: pricingUnitUsage?.shortName,
                            currencyDisplay: 'symbol',
                            currency,
                            minimumFractionDigits: 2,
                            maximumSignificantDigits: 6,
                          },
                        )}
                      </Typography>
                    </td>
                  )}
                </>
              )}
              {!hideVat && (
                <td>
                  <Typography variant="body" color="grey700">
                    {taxRateDisplay}
                  </Typography>
                </td>
              )}
              <td>
                <Typography variant="body" color="grey700">
                  {intlFormatNumber(
                    deserializeAmount(
                      pricingUnitUsage?.amountCents || fee?.amountCents || 0,
                      currency,
                    ),
                    {
                      pricingUnitShortName: pricingUnitUsage?.shortName,
                      currencyDisplay: 'symbol',
                      currency,
                    },
                  )}
                </Typography>
              </td>
            </>
          )}

          {isDraftInvoice && (
            <td onClick={(e) => e.stopPropagation()}>
              {!isTrueUpFee && !isCommitmentFee && (
                <Popper
                  PopperProps={{ placement: 'bottom-end' }}
                  opener={({ isOpen }) => (
                    <PopperOpener className="static">
                      <Tooltip
                        placement="top-end"
                        disableHoverListener={isOpen}
                        title={translate(
                          isAdjustedFee
                            ? 'text_65a6b4e2cb38d9b70ec54035'
                            : 'text_65a6b4e3cb38d9b70ec54092',
                        )}
                      >
                        <Button size="small" icon="dots-horizontal" variant="quaternary" />
                      </Tooltip>
                    </PopperOpener>
                  )}
                >
                  {({ closePopper }) => (
                    <MenuPopper>
                      <Button
                        startIcon={isAdjustedFee ? 'reload' : 'pen'}
                        variant="quaternary"
                        align="left"
                        onClick={() => {
                          if (isAdjustedFee) {
                            openDeleteAdjustedFeeDialog({ fee, onDelete })
                          } else if (fee) {
                            if (onAdd && invoiceSubscriptionId) {
                              editFeeDrawerRef?.current?.openDrawer({
                                mode: 'regenerate',
                                invoiceId,
                                invoiceSubscriptionId,
                                fee,
                                onAdd,
                                localFees,
                              })
                            } else {
                              editFeeDrawerRef?.current?.openDrawer({
                                mode: 'edit',
                                invoiceId,
                                fee,
                              })
                            }
                          }
                          closePopper()
                        }}
                      >
                        {translate(
                          isAdjustedFee
                            ? 'text_65a6b4e2cb38d9b70ec54035'
                            : 'text_65a6b4e3cb38d9b70ec54092',
                        )}
                      </Button>

                      <CopyFeeIdButton fee={fee} closePopper={closePopper} />
                      <ViewFeeDetailsButton fee={fee} closePopper={closePopper} />
                    </MenuPopper>
                  )}
                </Popper>
              )}
            </td>
          )}

          {!isDraftInvoice && <FeeActions />}
        </tr>

        {shouldDisplayFeeDetail && (
          <>
            {chargeModel === ChargeModelEnum.Graduated && (
              <InvoiceDetailsTableBodyLineGraduated
                currency={currency}
                fee={fee}
                hideVat={hideVat}
              />
            )}
            {chargeModel === ChargeModelEnum.GraduatedPercentage && (
              <InvoiceDetailsTableBodyLineGraduatedPercentage
                currency={currency}
                fee={fee}
                hideVat={hideVat}
              />
            )}
            {chargeModel === ChargeModelEnum.Volume && (
              <InvoiceDetailsTableBodyLineVolume currency={currency} fee={fee} hideVat={hideVat} />
            )}
            {chargeModel === ChargeModelEnum.Package && (
              <InvoiceDetailsTableBodyLinePackage currency={currency} fee={fee} hideVat={hideVat} />
            )}
            {chargeModel === ChargeModelEnum.Percentage && (
              <InvoiceDetailsTableBodyLinePercentage
                currency={currency}
                fee={fee}
                hideVat={hideVat}
              />
            )}
            <tr
              className={tw('details-line', rowClickableClass, {
                subtotal: !pricingUnitUsage,
              })}
              onClick={fee ? handleRowClick : undefined}
            >
              <td colSpan={hideVat && !isDraftInvoice ? 3 : 4}>
                <Typography variant="body" color="grey700">
                  {translate('text_659e67cd63512ef532843154')}
                </Typography>
              </td>
              <td>
                <Typography variant="body" color="grey700">
                  {intlFormatNumber(
                    deserializeAmount(
                      pricingUnitUsage?.amountCents || fee?.amountCents || 0,
                      currency,
                    ),
                    {
                      pricingUnitShortName: pricingUnitUsage?.shortName,
                      currencyDisplay: 'symbol',
                      currency,
                    },
                  )}
                </Typography>
              </td>

              <FeeActions />
            </tr>
          </>
        )}
        {!!pricingUnitUsage && (
          <tr
            className={tw('details-line subtotal', rowClickableClass)}
            onClick={fee ? handleRowClick : undefined}
          >
            <td colSpan={hideVat && !isDraftInvoice ? 3 : 4}>
              <Typography variant="body" color="grey700">
                {translate('text_1751039646310obdq6n385sc', {
                  pricingUnitShortName: pricingUnitUsage.shortName,
                  conversionRateAmount: intlFormatNumber(pricingUnitUsage.conversionRate || 0, {
                    style: 'decimal',
                    maximumFractionDigits: 15,
                  }),
                })}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="grey700">
                {intlFormatNumber(deserializeAmount(fee?.amountCents || 0, currency), {
                  currencyDisplay: 'symbol',
                  currency,
                })}
              </Typography>
            </td>
            <FeeActions />
          </tr>
        )}
      </>
    )
  },
)

InvoiceDetailsTableBodyLine.displayName = 'InvoiceDetailsTableBodyLine'
