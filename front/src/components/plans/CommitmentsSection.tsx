import { useStore } from '@tanstack/react-form'
import { useMemo, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { Typography } from '~/components/designSystem/Typography'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { mapCommitmentToDrawerValues } from '~/components/plans/drawers/minimumCommitment/mapToDrawerValues'
import {
  MinimumCommitmentDrawer,
  MinimumCommitmentDrawerRef,
  MinimumCommitmentFormValues,
} from '~/components/plans/drawers/minimumCommitment/MinimumCommitmentDrawer'
import { MinimumCommitmentPremiumGate } from '~/components/plans/MinimumCommitmentPremiumGate'
import {
  mapChargeIntervalCopy,
  returnFirstDefinedArrayRatesSumAsString,
} from '~/components/plans/utils'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CommitmentTypeEnum, CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'
import { useCurrentUser } from '~/hooks/useCurrentUser'

export const OPEN_MINIMUM_COMMITMENT_DRAWER_TEST_ID = 'open-minimum-commitment-drawer'
export const ADD_MINIMUM_COMMITMENT_TEST_ID = 'add-minimum-commitment'

type CommitmentsSectionProps = {
  form: PlanFormType
}

export const CommitmentsSection = ({ form }: CommitmentsSectionProps) => {
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const minimumCommitmentDrawerRef = useRef<MinimumCommitmentDrawerRef>(null)

  const commitment = useStore(form.store, (s) => s.values.minimumCommitment)
  const currency = useStore(form.store, (s) => s.values.amountCurrency) || CurrencyEnum.Usd
  const interval = useStore(form.store, (s) => s.values.interval)

  const hasCommitment = !isNaN(Number(commitment?.amountCents)) && !!commitment?.amountCents

  const taxValueForBadgeDisplay = useMemo((): string | undefined => {
    return returnFirstDefinedArrayRatesSumAsString(commitment?.taxes || [])
  }, [commitment?.taxes])

  const openMinimumCommitmentDrawer = () => {
    minimumCommitmentDrawerRef.current?.openDrawer(mapCommitmentToDrawerValues(commitment))
  }

  const handleDrawerSave = (values: MinimumCommitmentFormValues) => {
    form.setFieldValue('minimumCommitment', {
      ...form.state.values.minimumCommitment,
      ...values,
      commitmentType: CommitmentTypeEnum.MinimumCommitment,
    })
  }

  return (
    <CenteredPage.PageSection>
      <CenteredPage.PageSectionTitle
        title={translate('text_65d601bffb11e0f9d1d9f569')}
        description={
          <Typography variant="caption" color="grey600">
            {translate('text_6661fc17337de3591e29e451', {
              interval: translate(mapChargeIntervalCopy(interval, false)).toLocaleLowerCase(),
            })}
          </Typography>
        }
      />

      {hasCommitment && (
        <Selector
          icon="minus-circle"
          title={commitment?.invoiceDisplayName || translate('text_65d601bffb11e0f9d1d9f569')}
          subtitle={intlFormatNumber(Number(commitment?.amountCents), {
            style: 'currency',
            currency,
          })}
          endContent={
            <div className="flex items-center gap-3">
              {!!taxValueForBadgeDisplay && (
                <Chip
                  label={intlFormatNumber(Number(taxValueForBadgeDisplay) / 100 || 0, {
                    style: 'percent',
                  })}
                />
              )}
              <Chip label={translate(getIntervalTranslationKey[interval])} />
              <Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />
            </div>
          }
          hoverActions={
            <SelectorActions
              actions={[
                {
                  icon: 'trash',
                  tooltipCopy: translate('text_63aa085d28b8510cd46443ff'),
                  onClick: () => {
                    form.setFieldValue('minimumCommitment', {})
                  },
                },
                {
                  icon: 'pen',
                  tooltipCopy: translate('text_63e51ef4985f0ebd75c212fc'),
                  onClick: () => openMinimumCommitmentDrawer(),
                },
              ]}
            />
          }
          data-test={OPEN_MINIMUM_COMMITMENT_DRAWER_TEST_ID}
          onClick={() => openMinimumCommitmentDrawer()}
        />
      )}

      {!hasCommitment && !isPremium && <MinimumCommitmentPremiumGate />}

      {!hasCommitment && isPremium && (
        <Button
          fitContent
          variant="inline"
          startIcon="plus"
          data-test={ADD_MINIMUM_COMMITMENT_TEST_ID}
          onClick={() => {
            minimumCommitmentDrawerRef.current?.openDrawer()
          }}
        >
          {translate('text_6661ffe746c680007e2df0e1')}
        </Button>
      )}

      <MinimumCommitmentDrawer
        ref={minimumCommitmentDrawerRef}
        onSave={handleDrawerSave}
        onDelete={() => form.setFieldValue('minimumCommitment', {})}
      />
    </CenteredPage.PageSection>
  )
}

CommitmentsSection.displayName = 'CommitmentsSection'
