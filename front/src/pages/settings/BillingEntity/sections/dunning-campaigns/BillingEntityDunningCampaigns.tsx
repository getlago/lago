import { Icon } from 'lago-design-system'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListItemLoadingSkeleton,
  SettingsListWrapper,
  SettingsPaddedContainer,
} from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { BILLING_ENTITY_ROUTE } from '~/core/router/SettingRoutes'
import {
  BillingEntity,
  PremiumIntegrationTypeEnum,
  useGetBillingEntityQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import {
  ApplyDunningCampaignDialog,
  ApplyDunningCampaignDialogRef,
} from '~/pages/settings/BillingEntity/sections/dunning-campaigns/ApplyDunningCampaignDialog'
import { useRemoveAppliedDunningCampaignDialog } from '~/pages/settings/BillingEntity/sections/dunning-campaigns/RemoveAppliedDunningCampaignDialog'
import ErrorImage from '~/public/images/maneki/error.svg'

const BillingEntityDunningCampaigns = () => {
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()
  const { organization: { premiumIntegrations } = {} } = useOrganizationInfos()
  const { billingEntityCode } = useParams()

  const hasAccessToFeature = premiumIntegrations?.includes(PremiumIntegrationTypeEnum.AutoDunning)

  const applyDunningCampaignDialogRef = useRef<ApplyDunningCampaignDialogRef>(null)
  const { openRemoveAppliedDunningCampaignDialog } = useRemoveAppliedDunningCampaignDialog()

  const {
    data: billingEntityData,
    loading,
    error,
  } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  const appliedDunningCampaign = billingEntity?.appliedDunningCampaign

  if (!!error && !loading) {
    return (
      <GenericPlaceholder
        title={translate('text_629728388c4d2300e2d380d5')}
        subtitle={translate('text_629728388c4d2300e2d380eb')}
        buttonTitle={translate('text_629728388c4d2300e2d38110')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
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
          viewName: translate('text_1750663218390k1j07z0kda6'),
          viewNameLoading: loading,
          metadata: translate('text_17506632183909ttm5ngxpil'),
          metadataLoading: loading,
        }}
      />

      <SettingsPaddedContainer>
        {!!loading && <SettingsListItemLoadingSkeleton count={2} />}

        {!loading && (
          <>
            <SettingsListWrapper>
              <SettingsListItem>
                <SettingsListItemHeader
                  label={translate('text_1750663218390lixhj94mgbp')}
                  sublabel={translate('text_1750663218390kr7cu0gamqt')}
                  action={
                    <>
                      {hasPermissions(['billingEntitiesUpdate']) && (
                        <Button
                          variant="inline"
                          disabled={loading || !!appliedDunningCampaign?.id}
                          onClick={() => {
                            if (billingEntity) {
                              applyDunningCampaignDialogRef?.current?.openDialog(
                                billingEntity as BillingEntity,
                              )
                            }
                          }}
                          data-test="apply-dunning-campaign-button"
                        >
                          {translate('text_1750663218390gt40sy6c76o')}
                        </Button>
                      )}
                    </>
                  }
                />

                {!hasAccessToFeature && (
                  <div className="flex items-center justify-between gap-4 rounded-lg bg-grey-100 px-6 py-4">
                    <div>
                      <div className="flex items-center gap-1">
                        <Typography variant="bodyHl" color="textSecondary">
                          {translate('text_1729263759370k8po52j4m2n')}
                        </Typography>
                        <Icon name="sparkles" />
                      </div>
                      <Typography variant="caption">
                        {translate('text_1729263759370rhgayszv6yq')}
                      </Typography>
                    </div>

                    <ButtonLink
                      buttonProps={{
                        variant: 'tertiary',
                        size: 'medium',
                        endIcon: 'sparkles',
                      }}
                      type="button"
                      external
                      to={`mailto:hello@getlago.com?subject=${translate('text_1729263868504ljw2poh51w4')}&body=${translate('text_17292638685046z36ct98v0l')}`}
                    >
                      {translate('text_65ae73ebe3a66bec2b91d72d')}
                    </ButtonLink>
                  </div>
                )}

                {hasAccessToFeature && !appliedDunningCampaign && (
                  <Typography variant="body" color="grey500">
                    {translate('text_1750663218390oab5y7r0mai')}
                  </Typography>
                )}

                {hasAccessToFeature && appliedDunningCampaign && (
                  <div>
                    <Typography variant="bodyHl" color="grey600" className="my-2">
                      {translate('text_1750663218391y478pxbkhkw')}
                    </Typography>

                    <div className="flex items-center justify-between shadow-y">
                      <div className="flex flex-1 items-center gap-3 py-3">
                        <Avatar size="big" variant="connector">
                          <Icon size="medium" name="coin-dollar" color="dark" />
                        </Avatar>

                        <div>
                          <Typography color="textSecondary" variant="bodyHl" noWrap>
                            {appliedDunningCampaign.name}
                          </Typography>

                          <Typography variant="caption" noWrap>
                            {appliedDunningCampaign.code}
                          </Typography>
                        </div>
                      </div>

                      {hasPermissions(['billingEntitiesUpdate']) && (
                        <Tooltip placement="top" title={translate('text_175066321839172gm0lkz8eu')}>
                          <Button
                            icon="trash"
                            variant="quaternary"
                            onClick={() => {
                              if (billingEntity && appliedDunningCampaign) {
                                openRemoveAppliedDunningCampaignDialog(
                                  billingEntity as BillingEntity,
                                )
                              }
                            }}
                          />
                        </Tooltip>
                      )}
                    </div>
                  </div>
                )}
              </SettingsListItem>
            </SettingsListWrapper>
          </>
        )}
      </SettingsPaddedContainer>

      <ApplyDunningCampaignDialog ref={applyDunningCampaignDialogRef} />
    </>
  )
}

export default BillingEntityDunningCampaigns
