import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Selector, SelectorActions } from '~/components/designSystem/Selector'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { FIXED_CHARGES_ADD_BUTTON_TEST_ID } from '~/components/plans/chargeTestIds'
import {
  FixedChargeDrawer,
  FixedChargeDrawerRef,
} from '~/components/plans/drawers/fixedCharge/FixedChargeDrawer'
import {
  RemoveChargeWarningDialog,
  RemoveChargeWarningDialogRef,
} from '~/components/plans/RemoveChargeWarningDialog'
import { LocalFixedChargeInput } from '~/components/plans/types'
import {
  buildChargeHoverActions,
  getFormattedChargeSelectorSubtitle,
  mapChargeIntervalCopy,
} from '~/components/plans/utils'
import { useDuplicatePlanVar } from '~/core/apolloClient/reactiveVars/duplicatePlanVar'
import {
  GraduatedChargeFragmentDoc,
  PlanInterval,
  TaxForPlanAndChargesInPlanFormFragmentDoc,
  VolumeRangesFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

gql`
  fragment FixedChargesOnPlanForm on Plan {
    id
    billFixedChargesMonthly
    fixedCharges {
      id
      prorated
      units
      chargeModel
      invoiceDisplayName
      payInAdvance
      addOn {
        ...AddOnForFixedChargesSection
      }
      properties {
        amount
        graduatedRanges {
          ...GraduatedCharge
        }
        volumeRanges {
          ...VolumeRanges
        }
      }
      taxes {
        ...TaxForPlanAndChargesInPlanForm
      }
    }
  }

  ${TaxForPlanAndChargesInPlanFormFragmentDoc}
  ${GraduatedChargeFragmentDoc}
  ${VolumeRangesFragmentDoc}
`

interface FixedChargesSectionProps {
  form: PlanFormType
  alreadyExistingFixedChargesIds: string[]
  canBeEdited?: boolean
  isInSubscriptionForm?: boolean
  isEdition?: boolean
}

export const FixedChargesSection = ({
  form,
  alreadyExistingFixedChargesIds,
  canBeEdited,
  isInSubscriptionForm,
  isEdition = false,
}: FixedChargesSectionProps) => {
  const { translate } = useInternationalization()
  const { type: actionType } = useDuplicatePlanVar()
  const fixedCharges = useStore(form.store, (s) => s.values.fixedCharges)
  const interval = useStore(form.store, (s) => s.values.interval)
  const billFixedChargesMonthly = useStore(form.store, (s) => s.values.billFixedChargesMonthly)

  const hasAnyFixedCharge = !!fixedCharges.length
  const removeChargeWarningDialogRef = useRef<RemoveChargeWarningDialogRef>(null)
  const fixedChargeDrawerRef = useRef<FixedChargeDrawerRef>(null)
  const [alreadyUsedAddOnIds, setAlreadyUsedAddOnIds] = useState<Map<string, number>>(new Map())

  const handleDrawerSave = useCallback(
    (charge: LocalFixedChargeInput, index: number | null) => {
      const newCharges = [...form.state.values.fixedCharges]

      if (index === null) {
        newCharges.push(charge)
      } else {
        newCharges[index] = charge
      }
      form.setFieldValue('fixedCharges', newCharges)
    },
    [form],
  )

  const handleChargeDelete = useCallback(
    (index: number) => {
      const newCharges = [...form.state.values.fixedCharges]

      newCharges.splice(index, 1)
      form.setFieldValue('fixedCharges', newCharges)
    },
    [form],
  )

  useEffect(() => {
    setAlreadyUsedAddOnIds(
      fixedCharges?.reduce((prev, curr) => {
        const id = curr.addOn.id

        return prev.set(id, (prev.get(id) || 0) + 1)
      }, new Map()),
    )
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fixedCharges?.length])

  const isAnnual = [PlanInterval.Semiannual, PlanInterval.Yearly].includes(interval)

  const intervalBadgeCopy = useMemo(() => {
    return translate(
      mapChargeIntervalCopy(interval, (isAnnual && !!billFixedChargesMonthly) || false),
    )
  }, [translate, interval, billFixedChargesMonthly, isAnnual])

  if (!hasAnyFixedCharge && isInSubscriptionForm) {
    return null
  }

  return (
    <>
      <CenteredPage.PageSection>
        <CenteredPage.PageSectionTitle
          title={translate('text_176072970726728iw4tc8ucl')}
          description={translate('text_1760729707268c05r06ip8vg')}
        />

        {(!!fixedCharges?.length || !isInSubscriptionForm) && (
          <div className="flex flex-col gap-6">
            {!!fixedCharges?.length && (
              <div className="flex flex-col gap-4">
                {fixedCharges.map((fixedCharge: LocalFixedChargeInput, i) => {
                  const isNew = !alreadyExistingFixedChargesIds?.includes(fixedCharge?.id || '')
                  const alreadyUsedChargeAlertMessage =
                    (alreadyUsedAddOnIds.get(fixedCharge.addOn.id) || 0) > 1
                      ? translate('text_1760729707268h378x60alri')
                      : undefined
                  const isUsedInSubscription = !isNew && !canBeEdited

                  const openFixedChargeDrawer = () => {
                    fixedChargeDrawerRef.current?.openDrawer(fixedCharge, i, {
                      alreadyUsedChargeAlertMessage,
                      isUsedInSubscription,
                    })
                  }

                  return (
                    <Selector
                      key={`fixed-charge-${fixedCharge.addOn.id}-${i}`}
                      icon="puzzle"
                      title={fixedCharge.invoiceDisplayName || fixedCharge.addOn.name}
                      subtitle={getFormattedChargeSelectorSubtitle({
                        chargeModel: fixedCharge.chargeModel,
                        code: fixedCharge.addOn.code,
                        translate,
                      })}
                      endContent={
                        <div className="flex items-center gap-3">
                          <Chip label={intervalBadgeCopy} />
                          <Tooltip
                            placement="top-end"
                            title={translate('text_17719630334671lxunwzo7ae')}
                          >
                            <Button
                              icon="chevron-right-filled"
                              variant="quaternary"
                              tabIndex={-1}
                            />
                          </Tooltip>
                        </div>
                      }
                      hoverActions={
                        <SelectorActions
                          actions={buildChargeHoverActions({
                            showDelete: !isInSubscriptionForm,
                            showWarningOnDelete: actionType !== 'duplicate' && isUsedInSubscription,
                            onDelete: () => handleChargeDelete(i),
                            onEdit: openFixedChargeDrawer,
                            removeChargeWarningDialogRef,
                            translate,
                          })}
                        />
                      }
                      data-test={`fixed-charge-selector-${i}`}
                      onClick={() => openFixedChargeDrawer()}
                    />
                  )
                })}
              </div>
            )}
            {!isInSubscriptionForm && (
              <Button
                fitContent
                startIcon="plus"
                variant="inline"
                data-test={FIXED_CHARGES_ADD_BUTTON_TEST_ID}
                onClick={() => {
                  fixedChargeDrawerRef.current?.openDrawer()
                }}
              >
                {translate('text_176072970726882uau5y69f1')}
              </Button>
            )}
          </div>
        )}
      </CenteredPage.PageSection>

      <FixedChargeDrawer
        ref={fixedChargeDrawerRef}
        disabled={isEdition && !canBeEdited}
        isEdition={isEdition}
        isInSubscriptionForm={isInSubscriptionForm}
        onSave={handleDrawerSave}
        onDelete={handleChargeDelete}
        removeChargeWarningDialogRef={removeChargeWarningDialogRef}
      />

      <RemoveChargeWarningDialog ref={removeChargeWarningDialogRef} />
    </>
  )
}
