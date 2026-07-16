import { Icon } from 'lago-design-system'
import { useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import EmailPreview, { DisplayEnum } from '~/components/emails/EmailPreview'
import { Switch } from '~/components/form'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { LanguageSettingsButton } from '~/components/settings/LanguageSettingsButton'
import { BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE, BILLING_ENTITY_ROUTE } from '~/core/router'
import { LocaleEnum } from '~/core/translations'
import {
  BillingEntity,
  BillingEntityEmailSettingsEnum,
  useGetBillingEntityQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useEmailConfig } from '~/hooks/useEmailConfig'
import { useEmailPreviewTranslationsKey } from '~/hooks/useEmailPreviewTranslationsKey'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { EMAIL_SCENARIOS } from '~/pages/settings/BillingEntity/sections/BillingEntityEmailScenarios'

const BillingEntityEmailScenariosConfig = () => {
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  const [invoiceLanguage, setInvoiceLanguage] = useState<LocaleEnum>(LocaleEnum.en)
  const [display, setDisplay] = useState<DisplayEnum>(DisplayEnum.desktop)
  const { translate } = useInternationalization()
  const { type } = useParams<{ type: BillingEntityEmailSettingsEnum }>()
  const { mapTranslationsKey } = useEmailPreviewTranslationsKey()
  const translationsKey = mapTranslationsKey(type)

  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const { billingEntityCode } = useParams()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

  const scenario = EMAIL_SCENARIOS.find((_scenario) => _scenario.setting === type)

  const hasAccess = scenario?.integration
    ? hasOrganizationPremiumAddon(scenario?.integration)
    : isPremium

  const { data: billingEntityData } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  const { loading, emailSettings, updateEmailSettings } = useEmailConfig({
    billingEntity: billingEntity as BillingEntity,
  })

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: billingEntity?.name || '',
            path: generatePath(BILLING_ENTITY_ROUTE, {
              billingEntityCode: billingEntityCode as string,
            }),
          },
          {
            label: translate('text_1742367202528mfhsv0f4fxq'),
            path: generatePath(BILLING_ENTITY_EMAIL_SCENARIOS_ROUTE, {
              billingEntityCode: billingEntityCode as string,
            }),
          },
        ]}
        actions={{
          items: [
            {
              type: 'custom',
              label: 'email-toggle',
              hidden: !hasPermissions(['billingEntitiesUpdate']),
              snapshotKey: type ? emailSettings?.includes(type) : false,
              content: (
                <div className="flex flex-row items-center gap-3">
                  <Typography variant="caption">
                    {translate('text_6408b5ae7f629d008bc8af7c')}
                  </Typography>
                  <Switch
                    name={`switch-config-${type}`}
                    checked={type && emailSettings?.includes(type)}
                    onChange={async (value, e) => {
                      e.preventDefault()
                      e.stopPropagation()

                      if (hasAccess) {
                        await updateEmailSettings(type as BillingEntityEmailSettingsEnum, value)
                      } else {
                        openPremiumWarningDialog()
                      }
                    }}
                  />
                  {!hasAccess && <Icon name="sparkles" />}
                </div>
              ),
            },
          ],
          loading,
        }}
        entity={{
          viewName: translate(translationsKey.title),
          viewNameLoading: loading,
          metadata: translate(translationsKey.subtitle),
          metadataLoading: loading,
        }}
      />

      <div className="min-height-minus-nav flex flex-col overflow-auto">
        <div className="flex h-18 min-h-18 items-center justify-between px-12 first:not-last:mr-3">
          <Typography variant="subhead1" color="grey700" noWrap>
            {translate('text_6407684eaf41130074c4b2f8')}
          </Typography>

          {!loading && (
            <div className="flex items-center gap-3">
              <Typography variant="caption">
                {translate('text_6407684eaf41130074c4b2f9')}
              </Typography>

              <LanguageSettingsButton language={invoiceLanguage} onChange={setInvoiceLanguage} />

              <div className="h-10 w-px bg-grey-300" />
              <Typography variant="caption">
                {translate('text_6407684eaf41130074c4b2fa')}
              </Typography>
              <Tooltip title={translate('text_6407684eaf41130074c4b2f6')} placement="top-end">
                <Button
                  variant={display === DisplayEnum.desktop ? 'secondary' : 'quaternary'}
                  icon="laptop"
                  onClick={() => setDisplay(DisplayEnum.desktop)}
                />
              </Tooltip>
              <Tooltip title={translate('text_6407684eaf41130074c4b2f5')} placement="top-end">
                <Button
                  variant={display === DisplayEnum.mobile ? 'secondary' : 'quaternary'}
                  icon="smartphone"
                  onClick={() => setDisplay(DisplayEnum.mobile)}
                />
              </Tooltip>
            </div>
          )}
        </div>

        <div className="px-12">
          <EmailPreview
            billingEntity={billingEntity}
            loading={loading}
            type={type}
            invoiceLanguage={invoiceLanguage}
          />
        </div>
      </div>
    </>
  )
}

export default BillingEntityEmailScenariosConfig
