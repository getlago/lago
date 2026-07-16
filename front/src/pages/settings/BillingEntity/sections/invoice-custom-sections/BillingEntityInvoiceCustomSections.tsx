import { useMemo, useRef } from 'react'
import { generatePath, useParams } from 'react-router-dom'

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
import { BILLING_ENTITY_ROUTE } from '~/core/router/SettingRoutes'
import { BillingEntity, useGetBillingEntityQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import {
  ApplyInvoiceCustomSectionDialog,
  ApplyInvoiceCustomSectionDialogRef,
} from '~/pages/settings/BillingEntity/sections/invoice-custom-sections/ApplyInvoiceCustomSectionDialog'
import { useRemoveInvoiceCustomSectionDialog } from '~/pages/settings/BillingEntity/sections/invoice-custom-sections/RemoveInvoiceCustomSectionDialog'
import ErrorImage from '~/public/images/maneki/error.svg'

const BillingEntityInvoiceCustomSections = () => {
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()

  const applyInvoiceCustomSectionDialogRef = useRef<ApplyInvoiceCustomSectionDialogRef>(null)
  const { openRemoveInvoiceCustomSectionDialog } = useRemoveInvoiceCustomSectionDialog()

  const { billingEntityCode } = useParams()

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

  const invoiceCustomSections = useMemo(
    () =>
      [...(billingEntity?.selectedInvoiceCustomSections || [])]?.sort(
        (a, b) => (a?.name || '').toLowerCase().localeCompare((b?.name || '').toLowerCase()) ?? 0,
      ),
    [billingEntity?.selectedInvoiceCustomSections],
  )

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
          viewName: translate('text_1749024634192ov41w9fp6r2'),
          viewNameLoading: loading,
          metadata: translate('text_1749024634192jeeb8l2bxk0'),
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
                  label={translate('text_1749024634192zt98gtce07b')}
                  sublabel={translate('text_17490246341927ohcf309qh6')}
                  action={
                    <>
                      {hasPermissions(['billingEntitiesUpdate']) && (
                        <Button
                          variant="inline"
                          disabled={loading}
                          onClick={() => {
                            if (billingEntity) {
                              applyInvoiceCustomSectionDialogRef?.current?.openDialog(
                                billingEntity as BillingEntity,
                              )
                            }
                          }}
                          data-test="apply-invoice-custom-section-button"
                        >
                          {translate('text_1749024634192lxuod95rb33')}
                        </Button>
                      )}
                    </>
                  }
                />

                {!invoiceCustomSections?.length && (
                  <Typography className="text-grey-500">
                    {translate('text_1749024634192uicqquutkdf')}
                  </Typography>
                )}

                {!!invoiceCustomSections?.length && (
                  <Table
                    name="billing-entity-invoice-custom-section"
                    containerSize={{ default: 0 }}
                    isLoading={loading}
                    data={invoiceCustomSections}
                    columns={[
                      {
                        key: 'name',
                        title: translate('text_17490267676055ulih3hfm6u'),
                        maxSpace: true,
                        content: ({ name }) => (
                          <Typography className="text-grey-700">{name}</Typography>
                        ),
                      },
                    ]}
                    actionColumn={(customSection) => {
                      if (!hasPermissions(['billingEntitiesUpdate'])) return null

                      return (
                        <Tooltip placement="top" title={translate('text_174902676760530x3yon7tqg')}>
                          <Button
                            icon="trash"
                            variant="quaternary"
                            onClick={() => {
                              if (billingEntity && customSection) {
                                openRemoveInvoiceCustomSectionDialog({
                                  billingEntity: billingEntity as BillingEntity,
                                  invoiceCustomSectionId: customSection.id,
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

      <ApplyInvoiceCustomSectionDialog ref={applyInvoiceCustomSectionDialogRef} />
    </>
  )
}

export default BillingEntityInvoiceCustomSections
