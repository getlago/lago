import { gql } from '@apollo/client'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Typography } from '~/components/designSystem/Typography'
import { DunningEmail, DunningEmailSkeleton } from '~/components/emails/DunningEmail'
import { LanguageSettingsButton } from '~/components/settings/LanguageSettingsButton'
import { PreviewEmailLayout } from '~/components/settings/PreviewEmailLayout'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { LocaleEnum } from '~/core/translations'
import {
  CurrencyEnum,
  InvoicesForDunningEmailFragment,
  useGetOrganizationInfoForPreviewDunningCampaignLazyQuery,
} from '~/generated/graphql'
import { useContextualLocale } from '~/hooks/core/useContextualLocale'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment OrganizationInfoForPreviewDunningCampaign on CurrentOrganization {
    name
    email
    logoUrl
  }

  query getOrganizationInfoForPreviewDunningCampaign {
    organization {
      ...OrganizationInfoForPreviewDunningCampaign
    }
  }
`
export interface PreviewCampaignEmailDrawerRef extends DrawerRef {
  openDrawer: () => void
  closeDrawer: () => void
}

const DUMMY_OVERDUE_AMOUNT_CENTS = 73000
const DUMMY_INVOICES_COUNT = 5

export const PreviewCampaignEmailDrawer = forwardRef<PreviewCampaignEmailDrawerRef>(
  (_props, ref) => {
    const { translate } = useInternationalization()
    const drawerRef = useRef<DrawerRef>(null)
    const [locale, setLocale] = useState<LocaleEnum>(LocaleEnum.en)
    const { translateWithContextualLocal } = useContextualLocale(locale)

    const [getOrganizationInfo, { loading, data }] =
      useGetOrganizationInfoForPreviewDunningCampaignLazyQuery()

    const invoices: InvoicesForDunningEmailFragment[] = Array.from({
      length: DUMMY_INVOICES_COUNT,
    }).map((_, index) => ({
      id: `${index}`,
      number: `${data?.organization?.name.slice(0, 3).toUpperCase()}-1234-567-89${index + 1}`,
      totalDueAmountCents:
        index === 0 ? DUMMY_OVERDUE_AMOUNT_CENTS - 10000 * (DUMMY_INVOICES_COUNT - 1) : 10000,
      currency: CurrencyEnum.Usd,
    }))

    useImperativeHandle(ref, () => ({
      openDrawer: () => {
        getOrganizationInfo()
        drawerRef.current?.openDrawer()
      },
      closeDrawer: () => drawerRef.current?.closeDrawer(),
    }))

    return (
      <Drawer
        ref={drawerRef}
        withPadding={false}
        stickyBottomBar={({ closeDrawer }) => (
          <div className="flex justify-end">
            <Button onClick={closeDrawer}>{translate('text_1729594310368kstqhifkf5p')}</Button>
          </div>
        )}
        title={
          <div className="flex flex-1 flex-row items-center justify-between gap-1">
            <Typography variant="bodyHl" color="textSecondary">
              {translate('text_1728584028187udjepvgj8ra')}
            </Typography>
            <LanguageSettingsButton
              language={locale}
              onChange={(currentLocale) => setLocale(currentLocale)}
            />
          </div>
        }
      >
        <div className="h-full bg-grey-100 p-12 pb-0">
          <div className="mx-auto max-w-150">
            <PreviewEmailLayout
              name={data?.organization?.name}
              logoUrl={data?.organization?.logoUrl}
              isLoading={loading}
              language={locale}
              emailObject={translateWithContextualLocal('text_1729256593854oiy13slixjr', {
                companyName: data?.organization?.name,
              })}
              emailFrom={`<${data?.organization?.email || '{{organization_email}}'}>`}
            >
              {loading ? (
                <div className="flex flex-col gap-7">
                  <DunningEmailSkeleton />
                </div>
              ) : (
                <div className="flex flex-col gap-6">
                  <DunningEmail
                    locale={locale}
                    invoices={invoices}
                    currency={CurrencyEnum.Usd}
                    overdueAmount={deserializeAmount(DUMMY_OVERDUE_AMOUNT_CENTS, CurrencyEnum.Usd)}
                    organization={{
                      name: data?.organization?.name ?? '{{organization_name}}',
                      netPaymentTerm: '{{net_payment_term}}',
                      email: data?.organization?.email || '{{organization_email}}',
                    }}
                    customer={{
                      displayName: `{{customer_name}}`,
                    }}
                  />
                </div>
              )}
            </PreviewEmailLayout>
          </div>
        </div>
      </Drawer>
    )
  },
)

PreviewCampaignEmailDrawer.displayName = 'PreviewCampaignEmailDrawer'
