import { Icon } from 'lago-design-system'
import { generatePath, useParams } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { Switch } from '~/components/form'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListItemLoadingSkeleton,
  SettingsListWrapper,
  SettingsPaddedContainer,
} from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import {
  BILLING_ENTITY_EMAIL_SCENARIOS_CONFIG_ROUTE,
  BILLING_ENTITY_ROUTE,
  useNavigate,
} from '~/core/router'
import {
  BillingEntity,
  BillingEntityEmailSettingsEnum,
  PremiumIntegrationTypeEnum,
  useGetBillingEntityQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useEmailConfig } from '~/hooks/useEmailConfig'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

const EmailScenarioTitleLookup: Record<BillingEntityEmailSettingsEnum, string> = {
  [BillingEntityEmailSettingsEnum.InvoiceFinalized]: 'text_6408b5ae7f629d008bc8af7d',
  [BillingEntityEmailSettingsEnum.CreditNoteCreated]: 'text_6408b5ae7f629d008bc8af86',
  [BillingEntityEmailSettingsEnum.PaymentReceiptCreated]: 'text_1741334140002zdl3cl599ib',
}

const EmailScenarioSubtitleLookup: Record<BillingEntityEmailSettingsEnum, string> = {
  [BillingEntityEmailSettingsEnum.InvoiceFinalized]: 'text_6408b5ae7f629d008bc8af7e',
  [BillingEntityEmailSettingsEnum.CreditNoteCreated]: 'text_6408b5ae7f629d008bc8af87',
  [BillingEntityEmailSettingsEnum.PaymentReceiptCreated]: 'text_1741334140002wx0sbk2bd13',
}

type EmailScenario = {
  id: string
  setting: BillingEntityEmailSettingsEnum
  integration?: PremiumIntegrationTypeEnum
}

export const EMAIL_SCENARIOS: Array<EmailScenario> = [
  {
    id: 'scenario-1',
    setting: BillingEntityEmailSettingsEnum.InvoiceFinalized,
  },
  {
    id: 'scenario-2',
    setting: BillingEntityEmailSettingsEnum.PaymentReceiptCreated,
    integration: PremiumIntegrationTypeEnum.IssueReceipts,
  },
  {
    id: 'scenario-3',
    setting: BillingEntityEmailSettingsEnum.CreditNoteCreated,
  },
]

const BillingEntityEmailScenarios = () => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const { billingEntityCode } = useParams()
  const { hasOrganizationPremiumAddon } = useOrganizationInfos()

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

  const generateConfigRoute = (setting: BillingEntityEmailSettingsEnum) =>
    generatePath(BILLING_ENTITY_EMAIL_SCENARIOS_CONFIG_ROUTE, {
      billingEntityCode: billingEntityCode as string,
      type: setting,
    })

  const goToConfigRoute = (setting: BillingEntityEmailSettingsEnum) => {
    if (billingEntityCode) {
      navigate(generateConfigRoute(setting))
    }
  }

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
        ]}
        entity={{
          viewName: translate('text_6408b5ae7f629d008bc8af79'),
          viewNameLoading: loading,
          metadata: translate('text_6408b5ae7f629d008bc8af7b'),
          metadataLoading: loading,
        }}
      />

      <SettingsPaddedContainer>
        <SettingsListWrapper>
          {!!loading ? (
            <SettingsListItemLoadingSkeleton count={2} />
          ) : (
            <>
              <SettingsListItem>
                <SettingsListItemHeader
                  label={translate('text_6408b5ae7f629d008bc8af7c')}
                  sublabel={translate('text_1728050339810z0fp6orhtgp')}
                />

                <Table
                  name="email-settings-scenarios"
                  containerSize={{ default: 0 }}
                  rowSize={72}
                  data={EMAIL_SCENARIOS}
                  onRowActionLink={({ setting }) => generateConfigRoute(setting)}
                  columns={[
                    {
                      key: 'id',
                      title: translate('text_1728052663405tgkf89zijqf'),
                      maxSpace: true,
                      content: ({ setting }) => (
                        <div className="flex flex-1 items-center gap-3">
                          <Avatar size="big" variant="connector">
                            <Icon name="mail" color="dark" />
                          </Avatar>
                          <div>
                            <Typography color="grey700" variant="body" noWrap>
                              {translate(EmailScenarioTitleLookup[setting])}
                            </Typography>
                            <Typography variant="caption" noWrap>
                              {translate(EmailScenarioSubtitleLookup[setting])}
                            </Typography>
                          </div>
                        </div>
                      ),
                    },
                    ...(hasPermissions(['billingEntitiesUpdate'])
                      ? [
                          {
                            key: 'setting',
                            title: translate('text_63ac86d797f728a87b2f9fa7'),
                            tdCellClassName: '[&>div]:pr-2',
                            content: ({ setting, integration }) => {
                              const uniqName = `email-setting-item-${Math.round(Math.random() * 1000)}`

                              const hasAccess = integration
                                ? hasOrganizationPremiumAddon(integration)
                                : isPremium

                              return (
                                <div className="flex items-center gap-2">
                                  <Switch
                                    name={uniqName}
                                    checked={emailSettings?.includes(setting)}
                                    onChange={async (value) => {
                                      if (hasAccess) {
                                        await updateEmailSettings(setting, value)
                                      } else {
                                        openPremiumWarningDialog()
                                      }
                                    }}
                                  />

                                  {hasAccess ? (
                                    <div className="size-4"></div>
                                  ) : (
                                    <Icon name="sparkles" />
                                  )}
                                </div>
                              )
                            },
                          } as TableColumn<{
                            id: string
                            setting: BillingEntityEmailSettingsEnum
                            integration?: PremiumIntegrationTypeEnum
                          }>,
                        ]
                      : []),
                  ]}
                  actionColumn={({ setting }) => {
                    return (
                      <Tooltip
                        placement="top-end"
                        title={translate('text_1728287936427nxgl4vcemin')}
                      >
                        <Button
                          icon="chevron-right"
                          variant="quaternary"
                          disabled={loading}
                          onClick={() => goToConfigRoute(setting)}
                        />
                      </Tooltip>
                    )
                  }}
                />
              </SettingsListItem>
            </>
          )}
        </SettingsListWrapper>
      </SettingsPaddedContainer>
    </>
  )
}

export default BillingEntityEmailScenarios
