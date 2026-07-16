import InputAdornment from '@mui/material/InputAdornment'
import { useMemo, useState } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Typography } from '~/components/designSystem/Typography'
import { Switch } from '~/components/form'
import { FieldErrorTooltip } from '~/components/form/FieldErrorTooltip'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { usePlanFormContext } from '~/contexts/PlanFormContext'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { DEFAULT_VALUES, ProgressiveBillingFormValues, ThresholdTableData } from './constants'

interface ProgressiveBillingDrawerContentExtraProps {
  initialDisplayRecurring: boolean
}

const progressiveBillingDrawerContentDefaultProps: ProgressiveBillingDrawerContentExtraProps = {
  initialDisplayRecurring: false,
}

export const ProgressiveBillingDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: progressiveBillingDrawerContentDefaultProps,
  render: function ProgressiveBillingDrawerContentRender({ form, initialDisplayRecurring }) {
    const { translate } = useInternationalization()
    const { currency } = usePlanFormContext()
    const [displayRecurring, setDisplayRecurring] = useState(initialDisplayRecurring)

    const handleAddThreshold = (
      nonRecurringThresholds: ProgressiveBillingFormValues['nonRecurringUsageThresholds'],
    ) => {
      const current = nonRecurringThresholds ?? []
      const last = current.at(-1)
      const newThreshold = {
        amountCents: last?.amountCents ? String(Number(last.amountCents) + 1) : '1',
        recurring: false as const,
      }

      form.setFieldValue('nonRecurringUsageThresholds', [...current, newThreshold])
    }

    const handleToggleRecurring = () => {
      if (displayRecurring) {
        form.setFieldValue('recurringUsageThreshold', undefined)
      } else {
        const currentRecurring = form.state.values.recurringUsageThreshold
        const value = currentRecurring ?? {
          amountCents: '1',
          recurring: true as const,
        }

        form.setFieldValue('recurringUsageThreshold', value)
      }
      setDisplayRecurring(!displayRecurring)
    }

    const getNonRecurringColumns = (
      nonRecurringThresholds: ProgressiveBillingFormValues['nonRecurringUsageThresholds'],
    ) => [
      {
        size: 224,
        content: (_: unknown, i: number) => (
          <Typography className="px-4" variant="captionHl" noWrap>
            {translate(i === 0 ? 'text_1724234174944p8zi54j192m' : 'text_1724179887723917j8ezkd9v')}
          </Typography>
        ),
      },
      {
        size: 248,
        title: (
          <Typography className="px-4" variant="captionHl">
            {translate('text_1724179887723eh12a0kqbdw')}
          </Typography>
        ),
        content: (_row: unknown, i: number) => (
          <form.AppField name={`nonRecurringUsageThresholds[${i}].amountCents`}>
            {(field) => (
              <FieldErrorTooltip
                title={
                  i > 0
                    ? translate('text_1724252232460i4tv7384iiy', {
                        value: nonRecurringThresholds?.[i - 1]?.amountCents,
                      })
                    : undefined
                }
              >
                <field.AmountInputField
                  variant="outlined"
                  currency={currency}
                  displayErrorText={false}
                  beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        {getCurrencySymbol(currency || CurrencyEnum.Usd)}
                      </InputAdornment>
                    ),
                  }}
                />
              </FieldErrorTooltip>
            )}
          </form.AppField>
        ),
      },
      {
        size: 248,
        title: (
          <Typography className="px-4" variant="captionHl">
            {translate('text_17241798877234jhvoho4ci9')}
          </Typography>
        ),
        content: (_row: unknown, i: number) => (
          <form.AppField name={`nonRecurringUsageThresholds[${i}].thresholdDisplayName`}>
            {(field) => (
              <field.TextInputField
                variant="outlined"
                displayErrorText={false}
                placeholder={translate('text_645bb193927b375079d28ace')}
              />
            )}
          </form.AppField>
        ),
      },
    ]

    const recurringColumns = useMemo(
      () => [
        {
          size: 224,
          content: () => (
            <Typography className="px-4" variant="captionHl" noWrap>
              {translate('text_17241798877230y851fdxzqu')}
            </Typography>
          ),
        },
        {
          size: 248,
          content: () => (
            <form.AppField name="recurringUsageThreshold.amountCents">
              {(field) => (
                <FieldErrorTooltip>
                  <field.AmountInputField
                    variant="outlined"
                    currency={currency}
                    displayErrorText={false}
                    beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
                    InputProps={{
                      startAdornment: (
                        <InputAdornment position="start">
                          {getCurrencySymbol(currency || CurrencyEnum.Usd)}
                        </InputAdornment>
                      ),
                    }}
                  />
                </FieldErrorTooltip>
              )}
            </form.AppField>
          ),
        },
        {
          size: 248,
          content: () => (
            <form.AppField name="recurringUsageThreshold.thresholdDisplayName">
              {(field) => (
                <field.TextInputField
                  variant="outlined"
                  displayErrorText={false}
                  placeholder={translate('text_645bb193927b375079d28ace')}
                />
              )}
            </form.AppField>
          ),
        },
      ],
      [currency, form, translate],
    )

    const handleFormSubmit = (event: React.FormEvent) => {
      event.preventDefault()
      form.handleSubmit()
    }

    return (
      <form onSubmit={handleFormSubmit}>
        <button type="submit" hidden aria-hidden="true" />
        <CenteredPage.SectionWrapper>
          <CenteredPage.PageTitle
            title={translate('text_1724179887722baucvj7bvc1')}
            description={translate('text_1724179887723kdf3nisf6hp')}
          />

          <CenteredPage.SubsectionWrapper>
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle
                title={translate('text_17696267519471sodhgj81od')}
                description={translate('text_1741101676181hja4m79j7qz')}
              />

              <form.Subscribe selector={(state) => state.values.nonRecurringUsageThresholds}>
                {(nonRecurringThresholds) => (
                  <div className="flex flex-col">
                    <Button
                      className="mb-2 ml-auto"
                      startIcon="plus"
                      variant="inline"
                      onClick={() => handleAddThreshold(nonRecurringThresholds)}
                    >
                      {translate('text_1724233213997l2ksi40t8q6')}
                    </Button>
                    <div className="-mx-4 overflow-auto px-4 pb-1">
                      <ChargeTable<ThresholdTableData>
                        name="progressive-billing-non-recurring"
                        data={(nonRecurringThresholds ?? []).map(
                          (localData) =>
                            ({
                              ...localData,
                              disabledDelete: nonRecurringThresholds?.length === 1,
                            }) as ThresholdTableData,
                        )}
                        onDeleteRow={(_, i) => {
                          const updated = (nonRecurringThresholds ?? []).filter(
                            (__, idx) => idx !== i,
                          )

                          form.setFieldValue('nonRecurringUsageThresholds', updated)
                        }}
                        deleteTooltipContent={translate('text_17242522324608198c2vblmw')}
                        columns={getNonRecurringColumns(nonRecurringThresholds)}
                      />
                    </div>
                  </div>
                )}
              </form.Subscribe>

              <Switch
                name="progressiveBillingRecurring"
                checked={displayRecurring}
                onChange={handleToggleRecurring}
                label={translate('text_1724234174945ztq15pvmty3')}
                subLabel={translate('text_172423417494563qf45qet2d')}
              />
              {displayRecurring && (
                <form.Subscribe selector={(state) => state.values.recurringUsageThreshold}>
                  {(recurringThreshold) => (
                    <div className="-mx-4 overflow-auto px-4 py-1">
                      <ChargeTable<ThresholdTableData>
                        name="progressive-billing-recurring"
                        columns={recurringColumns}
                        data={[(recurringThreshold ?? {}) as ThresholdTableData]}
                      />
                    </div>
                  )}
                </form.Subscribe>
              )}

              <Alert type="info">{translate('text_1724252232460iqofvwnpgnx')}</Alert>
            </CenteredPage.PageSection>
          </CenteredPage.SubsectionWrapper>
        </CenteredPage.SectionWrapper>
      </form>
    )
  },
})
