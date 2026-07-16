import { cloneDeep } from 'lodash'
import { useCallback } from 'react'

import { Button } from '~/components/designSystem/Button'
import { useDrawer } from '~/components/drawers/useDrawer'
import { PlanSettingsSection } from '~/components/plans/PlanSettingsSection'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import type { PlanFormType } from '~/hooks/plans/usePlanForm'

export const PLAN_SETTINGS_DRAWER_SAVE_TEST_ID = 'plan-settings-drawer-save'

export const useQuotePlanSettingsDrawer = (planForm: PlanFormType) => {
  const { translate } = useInternationalization()
  const drawer = useDrawer()

  const openDrawer = useCallback(() => {
    // PlanSettingsSection edits the shared planForm live, so snapshot the values
    // on open: "Cancel" restores them (discarding the drawer's edits) and "Save"
    // keeps the live changes — matching the sibling settings drawers' semantics.
    const snapshot = cloneDeep(planForm.state.values)

    drawer.open({
      title: translate('text_642d5eb2783a2ad10d67031a'),
      children: <PlanSettingsSection form={planForm} isInSubscriptionForm />,
      actions: (
        <div className="flex items-center justify-end gap-3">
          <Button
            variant="quaternary"
            onClick={() => {
              planForm.reset(snapshot, { keepDefaultValues: true })
              drawer.close()
            }}
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button data-test={PLAN_SETTINGS_DRAWER_SAVE_TEST_ID} onClick={() => drawer.close()}>
            {translate('text_17295436903260tlyb1gp1i7')}
          </Button>
        </div>
      ),
    })
  }, [drawer, planForm, translate])

  return { openDrawer }
}
