import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Table } from '~/components/designSystem/Table/Table'
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
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { BILLING_ENTITY_ROUTE } from '~/core/router/SettingRoutes'
import { Tax, useGetBillingEntityQuery, useGetBillingEntityTaxesQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import {
  ApplyTaxDialog,
  ApplyTaxDialogRef,
} from '~/pages/settings/BillingEntity/sections/taxes/ApplyTaxDialog'
import { APPLY_TAX_BUTTON_TEST_ID } from '~/pages/settings/BillingEntity/sections/taxes/dataTestConstants'
import { useRemoveTaxDialog } from '~/pages/settings/BillingEntity/sections/taxes/RemoveTaxDialog'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  query getBillingEntityTaxes($billingEntityId: ID!) {
    billingEntityTaxes(billingEntityId: $billingEntityId) {
      collection {
        id
        name
        code
        rate
      }
    }
  }
`

const BillingEntityTaxesSettings = () => {
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()

  const applyTaxDialogRef = useRef<ApplyTaxDialogRef>(null)
  const { openRemoveTaxDialog } = useRemoveTaxDialog()

  const { billingEntityCode } = useParams()

  const { data: billingEntityData } = useGetBillingEntityQuery({
    variables: {
      code: billingEntityCode as string,
    },
    skip: !billingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  const { data, error, loading } = useGetBillingEntityTaxesQuery({
    variables: {
      billingEntityId: billingEntity?.id as string,
    },
    skip: !billingEntity?.id,
  })

  const { collection } = data?.billingEntityTaxes || {}

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
          viewName: translate('text_1743241419870gwqt1b54uuq'),
          viewNameLoading: loading,
          metadata: translate('text_17432414198709y2y2ua9zxt'),
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
                  label={translate('text_17432414198707qivkiz8cth')}
                  sublabel={translate('text_17432414198712tgdfmlnxb0')}
                  action={
                    <>
                      {hasPermissions(['billingEntitiesUpdate']) && (
                        <Button
                          variant="inline"
                          disabled={loading}
                          onClick={() => {
                            if (billingEntity?.id) {
                              applyTaxDialogRef?.current?.openDialog(billingEntity.id)
                            }
                          }}
                          data-test={APPLY_TAX_BUTTON_TEST_ID}
                        >
                          {translate('text_1743241419871j03yn6wurna')}
                        </Button>
                      )}
                    </>
                  }
                />

                {!collection?.length && (
                  <Typography className="text-grey-500">
                    {translate('text_1743241419871563o61p323b')}
                  </Typography>
                )}

                {!!collection?.length && (
                  <Table
                    name="billing-entity-taxes"
                    containerSize={{ default: 0 }}
                    rowSize={72}
                    isLoading={loading}
                    data={collection}
                    columns={[
                      {
                        key: 'name',
                        title: translate('text_17280312664187sb64qzmyhy'),
                        maxSpace: true,
                        content: ({ name, code }) => (
                          <div className="flex flex-1 items-center gap-3" data-test={code}>
                            <Avatar size="big" variant="connector">
                              <Icon size="medium" name="percentage" color="dark" />
                            </Avatar>
                            <div>
                              <Typography color="textSecondary" variant="bodyHl" noWrap>
                                {name}
                              </Typography>
                              <Typography variant="caption" noWrap>
                                {code}
                              </Typography>
                            </div>
                          </div>
                        ),
                      },
                      {
                        key: 'rate',
                        textAlign: 'right',
                        title: translate('text_64de472463e2da6b31737de0'),
                        content: ({ rate }) => (
                          <Typography variant="body" color="grey700">
                            {intlFormatNumber((rate || 0) / 100, {
                              style: 'percent',
                            })}
                          </Typography>
                        ),
                      },
                    ]}
                    actionColumn={(tax) => {
                      if (!hasPermissions(['billingEntitiesUpdate'])) return null

                      return (
                        <Tooltip placement="top" title={translate('text_1743600025133r2npxfa25sy')}>
                          <Button
                            icon="trash"
                            variant="quaternary"
                            onClick={() => {
                              if (billingEntity?.id && tax) {
                                openRemoveTaxDialog({
                                  billingEntityId: billingEntity.id,
                                  tax: tax as Tax,
                                })
                              }
                            }}
                          />
                        </Tooltip>
                      )
                    }}
                  />
                )}
              </SettingsListItem>
            </SettingsListWrapper>
          </>
        )}
      </SettingsPaddedContainer>

      <ApplyTaxDialog ref={applyTaxDialogRef} />
    </>
  )
}

export default BillingEntityTaxesSettings
