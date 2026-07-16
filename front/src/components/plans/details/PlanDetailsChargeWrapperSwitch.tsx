import { memo, useCallback, useId, useMemo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Chip } from '~/components/designSystem/Chip'
import { JsonEditor } from '~/components/form'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { ALL_CHARGE_MODELS, AnyChargeModel } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  ChargeModelEnum,
  CurrencyEnum,
  FixedChargeChargeModelEnum,
  FixedChargeProperties,
  Maybe,
  Properties,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import PlanDetailsPresentationGroupKeys from './PlanDetailsPresentationGroupKeys'

const isUsageChargeProperties = (
  values?: Maybe<Properties> | Maybe<FixedChargeProperties>,
): values is Properties => {
  if (!values) return false

  return values?.__typename === 'Properties'
}

export const PlanDetailsChargeWrapperSwitch = memo(
  ({
    currency,
    chargeModel,
    values,
    chargeAppliedPricingUnit,
    showPresentationGroupKeys = true,
  }: {
    currency: CurrencyEnum
    chargeModel: ChargeModelEnum | FixedChargeChargeModelEnum
    values?: Maybe<Properties> | Maybe<FixedChargeProperties>
    chargeAppliedPricingUnit?: Maybe<{ pricingUnit?: Maybe<{ shortName?: string }> }>
    showPresentationGroupKeys?: boolean
  }) => {
    const componentId = useId()
    const { translate } = useInternationalization()

    const isUsageCharge = isUsageChargeProperties(values)
    const pricingGroupKeys = isUsageCharge ? values?.pricingGroupKeys : undefined
    const presentationGroupKeys = isUsageCharge ? values?.presentationGroupKeys : undefined

    const renderGroupKeyChips = useCallback(
      (groupKeys: string[], keyPrefix: string) => (
        <div className="mt-1 flex flex-wrap gap-2">
          {groupKeys.map((group, groupIndex) => (
            <Chip key={`${componentId}-${keyPrefix}-${groupIndex}`} label={group} />
          ))}
        </div>
      ),
      [componentId],
    )

    // Memoize the formatter function to avoid recreation on every render
    const formatAmountWithCurrency = useCallback(
      (
        amount: number,
        options?: { minimumFractionDigits?: number; maximumFractionDigits?: number },
      ) =>
        intlFormatNumber(amount, {
          pricingUnitShortName: chargeAppliedPricingUnit?.pricingUnit?.shortName,
          currency: currency,
          minimumFractionDigits: options?.minimumFractionDigits ?? 2,
          maximumFractionDigits: options?.maximumFractionDigits ?? 15,
        }),
      [chargeAppliedPricingUnit?.pricingUnit?.shortName, currency],
    )

    // Memoize the configuration object to avoid recreating it on every render
    // Only recreate when dependencies change
    const chargeModelConfigs: Record<
      AnyChargeModel,
      {
        isVisible: boolean
        content: JSX.Element
      }
    > = useMemo(
      () => ({
        [ALL_CHARGE_MODELS.Standard]: {
          isVisible: true,
          content: (
            <DetailsPage.TableDisplay
              name="standard"
              header={[translate('text_624453d52e945301380e49b6')]}
              body={[[formatAmountWithCurrency(Number(values?.amount) || 0)]]}
            />
          ),
        },
        [ALL_CHARGE_MODELS.Package]: {
          isVisible: !!isUsageCharge,
          content: (
            <DetailsPage.TableDisplay
              name="package"
              header={[
                translate('text_624453d52e945301380e49b6'),
                translate('text_65201b8216455901fe273de7'),
                translate('text_65201b8216455901fe273de8'),
              ]}
              body={[
                [
                  formatAmountWithCurrency(Number(values?.amount) || 0),
                  isUsageCharge ? values.packageSize : undefined,
                  isUsageCharge ? values.freeUnits : undefined,
                ],
              ]}
            />
          ),
        },
        [ALL_CHARGE_MODELS.Graduated]: {
          isVisible: true,
          content: (
            <DetailsPage.TableDisplay
              name="graduated-ranges"
              header={[
                translate('text_62793bbb599f1c01522e91ab'),
                translate('text_62793bbb599f1c01522e91b1'),
                translate('text_62793bbb599f1c01522e91b6'),
                translate('text_62793bbb599f1c01522e91bc'),
              ]}
              body={
                values?.graduatedRanges?.map((value) => [
                  value.fromValue,
                  value.toValue || '∞',
                  formatAmountWithCurrency(Number(value.perUnitAmount) || 0),
                  formatAmountWithCurrency(Number(value.flatAmount) || 0),
                ]) || []
              }
            />
          ),
        },
        [ALL_CHARGE_MODELS.GraduatedPercentage]: {
          isVisible: !!isUsageCharge,
          content: (
            <DetailsPage.TableDisplay
              name="graduated-percentage-ranges"
              header={[
                translate('text_62793bbb599f1c01522e91ab'),
                translate('text_62793bbb599f1c01522e91b1'),
                translate('text_64de472463e2da6b31737de0'),
                translate('text_62793bbb599f1c01522e91bc'),
              ]}
              body={
                isUsageCharge
                  ? values.graduatedPercentageRanges?.map((value) => [
                      value.fromValue,
                      value.toValue || '∞',
                      intlFormatNumber(Number(value.rate) / 100 || 0, {
                        style: 'percent',
                        maximumFractionDigits: 15,
                      }),
                      formatAmountWithCurrency(Number(value.flatAmount) || 0, {
                        minimumFractionDigits: 2,
                      }),
                    ]) || []
                  : []
              }
            />
          ),
        },
        [ALL_CHARGE_MODELS.Percentage]: {
          isVisible: !!isUsageCharge,
          content: (
            <>
              <DetailsPage.TableDisplay
                name="percentage"
                header={[
                  translate('text_64de472463e2da6b31737de0'),
                  translate('text_62ff5d01a306e274d4ffcc1e'),
                  translate('text_65201b8216455901fe273dfb'),
                  translate('text_62ff5d01a306e274d4ffcc48'),
                ]}
                body={
                  isUsageCharge
                    ? [
                        [
                          intlFormatNumber(Number(values.rate) / 100 || 0, {
                            style: 'percent',
                            maximumFractionDigits: 15,
                          }),
                          formatAmountWithCurrency(Number(values.fixedAmount) || 0, {
                            minimumFractionDigits: 2,
                          }),
                          !!values.freeUnitsPerEvents ? values.freeUnitsPerEvents : 0,
                          formatAmountWithCurrency(
                            Number(values.freeUnitsPerTotalAggregation) || 0,
                          ),
                        ],
                      ]
                    : []
                }
              />

              <DetailsPage.InfoGrid
                grid={[
                  {
                    label: translate('text_65201b8216455901fe273e01'),
                    value: formatAmountWithCurrency(
                      isUsageCharge ? Number(values.perTransactionMinAmount || 0) : 0,
                    ),
                  },
                  {
                    label: translate('text_65201b8216455901fe273e03'),
                    value: formatAmountWithCurrency(
                      isUsageCharge ? Number(values.perTransactionMaxAmount || 0) : 0,
                    ),
                  },
                ]}
              />
            </>
          ),
        },
        [ALL_CHARGE_MODELS.Volume]: {
          isVisible: true,
          content: (
            <DetailsPage.TableDisplay
              name="volume-ranges"
              header={[
                translate('text_62793bbb599f1c01522e91ab'),
                translate('text_62793bbb599f1c01522e91b1'),
                translate('text_62793bbb599f1c01522e91b6'),
                translate('text_62793bbb599f1c01522e91bc'),
              ]}
              body={
                values?.volumeRanges?.map((value) => [
                  value.fromValue,
                  value.toValue || '∞',
                  formatAmountWithCurrency(Number(value.perUnitAmount) || 0),
                  formatAmountWithCurrency(Number(value.flatAmount) || 0),
                ]) || []
              }
            />
          ),
        },
        [ALL_CHARGE_MODELS.Custom]: {
          isVisible: !!isUsageCharge,
          content: (
            <DetailsPage.TableDisplay
              name="custom"
              className="[&_tbody_td]:p-0"
              header={[translate('text_663dea5702b60301d8d06502')]}
              body={[
                [
                  <JsonEditor
                    key="custom-json-editor"
                    label={translate('text_663dea5702b60301d8d06502')}
                    value={isUsageCharge ? values.customProperties : undefined}
                    hideLabel
                    readOnly
                  />,
                ],
              ]}
            />
          ),
        },
        [ALL_CHARGE_MODELS.Dynamic]: {
          isVisible: true,
          content: <Alert type="info">{translate('text_17277706303454rxgscdqklx')}</Alert>,
        },
      }),
      [formatAmountWithCurrency, isUsageCharge, translate, values],
    )

    // Get the configuration for the current charge model
    const { isVisible, content } = chargeModelConfigs[chargeModel]

    return (
      <div className="flex flex-col gap-4">
        {isVisible && content}

        {!!pricingGroupKeys?.length && (
          <DetailsPage.InfoGridItem
            label={translate('text_65ba6d45e780c1ff8acb20ce')}
            value={renderGroupKeyChips(pricingGroupKeys, 'pricing-group-key')}
          />
        )}

        {showPresentationGroupKeys && !!presentationGroupKeys?.length && (
          <PlanDetailsPresentationGroupKeys presentationGroupKeys={presentationGroupKeys} />
        )}
      </div>
    )
  },
)

PlanDetailsChargeWrapperSwitch.displayName = 'PlanDetailsChargeWrapperSwitch'
