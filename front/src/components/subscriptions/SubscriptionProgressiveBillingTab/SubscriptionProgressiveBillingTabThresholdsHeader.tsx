import { gql } from '@apollo/client'
import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ResetProgressiveBillingDialog } from '~/components/subscriptions/ResetProgressiveBillingDialog'
import {
  SubscriptionForProgressiveBillingTabThresholdsHeaderFragment,
  SubscriptionForUseProgressiveBillingTabThresholdsHeaderFragmentDoc,
} from '~/generated/graphql'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

import { useSubscriptionProgressiveBillingTabThresholdsHeader } from './hooks/useSubscriptionProgressiveBillingTabThresholdsHeader'

// Test ID constants
export const PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID = 'progressive-billing-lifetime-chip'
export const PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID = 'progressive-billing-overridden-chip'
export const PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID = 'progressive-billing-menu-button'
export const PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID = 'progressive-billing-edit-button'
export const PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID = 'progressive-billing-reset-button'
export const PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID = 'progressive-billing-toggle-button'

gql`
  fragment SubscriptionForProgressiveBillingTabThresholdsHeader on Subscription {
    ...SubscriptionForUseProgressiveBillingTabThresholdsHeader
  }

  ${SubscriptionForUseProgressiveBillingTabThresholdsHeaderFragmentDoc}
`

interface SubscriptionProgressiveBillingTabThresholdsHeaderProps {
  subscription?: SubscriptionForProgressiveBillingTabThresholdsHeaderFragment | null
}

export const SubscriptionProgressiveBillingTabThresholdsHeader: FC<
  SubscriptionProgressiveBillingTabThresholdsHeaderProps
> = ({ subscription }) => {
  const {
    canEditSubscription,
    hasSubscriptionThresholds,
    shouldDisplayOverriddenBadge,
    tooltipTitle,
    switchingProgressiveBillingDisabledValueLoading,
    resetDialogRef,
    navigateToEditForm,
    openResetDialog,
    toggleProgressiveBilling,
    translate,
  } = useSubscriptionProgressiveBillingTabThresholdsHeader({ subscription })

  return (
    <>
      <div className="flex w-full items-center justify-between p-4 shadow-b">
        <Typography variant="bodyHl" color="grey700">
          {translate('text_17696267549792unv7l25frt')}
        </Typography>

        <div className="flex items-center gap-3">
          {shouldDisplayOverriddenBadge && (
            <Chip
              data-test={PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID}
              className="border-purple-200 bg-purple-100"
              color="infoMain"
              label={translate('text_65281f686a80b400c8e2f6dd')}
            />
          )}

          <Chip
            data-test={PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID}
            color="grey700"
            label={translate('text_1780512470285ql6s1rc7wjr')}
          />

          {canEditSubscription && (
            <Popper
              PopperProps={{ placement: 'bottom-end' }}
              opener={({ onClick }) => (
                <Tooltip placement="top-start" title={tooltipTitle}>
                  <Button
                    data-test={PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID}
                    variant="quaternary"
                    icon="dots-horizontal"
                    onClick={(e) => {
                      e.stopPropagation()
                      onClick()
                    }}
                  />
                </Tooltip>
              )}
            >
              {({ closePopper }) => (
                <MenuPopper>
                  <Button
                    data-test={PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID}
                    fullWidth
                    align="left"
                    startIcon="pen"
                    variant="quaternary"
                    onClick={(e) => {
                      e.stopPropagation()
                      navigateToEditForm()
                      closePopper()
                    }}
                  >
                    {translate('text_1738071730498edit4pb8hzw')}
                  </Button>

                  {hasSubscriptionThresholds && (
                    <Button
                      data-test={PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID}
                      fullWidth
                      align="left"
                      startIcon="history"
                      variant="quaternary"
                      onClick={(e) => {
                        e.stopPropagation()
                        openResetDialog()
                        closePopper()
                      }}
                    >
                      {translate('text_1738071730498ht52blrjax6')}
                    </Button>
                  )}

                  <Button
                    data-test={PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID}
                    fullWidth
                    align="left"
                    startIcon={
                      !!subscription?.progressiveBillingDisabled ? 'validate-filled' : 'stop'
                    }
                    loading={switchingProgressiveBillingDisabledValueLoading}
                    variant="quaternary"
                    onClick={async (e) => {
                      e.stopPropagation()
                      await toggleProgressiveBilling()
                      closePopper()
                    }}
                  >
                    {!!subscription?.progressiveBillingDisabled
                      ? translate('text_1769604747500dwp43wers40')
                      : translate('text_1769604747500dwp43wers41')}
                  </Button>
                </MenuPopper>
              )}
            </Popper>
          )}
        </div>
      </div>

      <ResetProgressiveBillingDialog ref={resetDialogRef} />
    </>
  )
}
