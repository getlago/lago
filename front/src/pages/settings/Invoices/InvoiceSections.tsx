import { gql } from '@apollo/client'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import {
  SettingsListItem,
  SettingsListItemHeader,
  SettingsListWrapper,
  SettingsPaddedContainer,
} from '~/components/layouts/Settings'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { useDeleteCustomSectionDialog } from '~/components/settings/invoices/DeleteCustomSectionDialog'
import {
  CREATE_INVOICE_CUSTOM_SECTION,
  CREATE_PRICING_UNIT,
  EDIT_INVOICE_CUSTOM_SECTION,
  EDIT_PRICING_UNIT,
  useNavigate,
} from '~/core/router'
import {
  DeleteCustomSectionFragmentDoc,
  useGetOrganizationSettingsInvoiceSectionsQuery,
  useGetOrganizationSettingsPricingUnitsQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePermissions } from '~/hooks/usePermissions'
import { tw } from '~/styles/utils'

gql`
  query getOrganizationSettingsInvoiceSections($limit: Int, $page: Int) {
    invoiceCustomSections(limit: $limit, page: $page) {
      collection {
        id
        name
        code

        ...DeleteCustomSection
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }

  query getOrganizationSettingsPricingUnits($limit: Int, $page: Int) {
    pricingUnits(limit: $limit, page: $page) {
      collection {
        id
        name
        shortName
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }

  ${DeleteCustomSectionFragmentDoc}
`

const InvoiceSections = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const navigate = useNavigate()
  const { openDeleteCustomSectionDialog } = useDeleteCustomSectionDialog()

  const canCreatePricingUnits = hasPermissions(['pricingUnitsCreate'])
  const canEditPricingUnits = hasPermissions(['pricingUnitsUpdate'])
  const canViewPricingUnits = hasPermissions(['pricingUnitsView'])

  const {
    data: invoiceCustomSectionsData,
    error: invoiceCustomSectionsError,
    loading: invoiceCustomSectionsLoading,
    fetchMore: invoiceCustomSectionsFetchMore,
  } = useGetOrganizationSettingsInvoiceSectionsQuery({
    variables: {
      limit: 100,
    },
  })

  const {
    data: pricingUnitsData,
    error: pricingUnitsError,
    loading: pricingUnitsLoading,
    fetchMore: pricingUnitsFetchMore,
  } = useGetOrganizationSettingsPricingUnitsQuery({
    variables: {
      limit: 100,
    },
    skip: !canViewPricingUnits,
  })

  const hasPricingUnits = !!pricingUnitsData?.pricingUnits?.collection?.length
  const hasCustomSections = !!invoiceCustomSectionsData?.invoiceCustomSections?.collection?.length

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_63ac86d797f728a87b2f9f85'),
          metadata: translate('text_1732553358445p7rg0i0dzws'),
        }}
      />

      <SettingsPaddedContainer>
        <SettingsListWrapper>
          {canViewPricingUnits && (
            <SettingsListItem className={tw({ 'pb-0 shadow-inherit': hasPricingUnits })}>
              <SettingsListItemHeader
                label={translate('text_17502505476284yyq70yy6mx')}
                sublabel={translate('text_1750250547628xsddx47vasu')}
                action={
                  <Button
                    variant="inline"
                    disabled={!canCreatePricingUnits}
                    onClick={() => navigate(CREATE_PRICING_UNIT)}
                  >
                    {translate('text_1742230191029lznwj3y41nb')}
                  </Button>
                }
              />

              {hasPricingUnits && (
                <InfiniteScroll
                  onBottom={() => {
                    const { currentPage = 0, totalPages = 0 } =
                      pricingUnitsData?.pricingUnits?.metadata || {}

                    currentPage < totalPages &&
                      !pricingUnitsLoading &&
                      pricingUnitsFetchMore?.({
                        variables: { page: currentPage + 1 },
                      })
                  }}
                >
                  <Table
                    name="pricing-units"
                    containerSize={{ default: 4 }}
                    data={pricingUnitsData?.pricingUnits?.collection || []}
                    isLoading={pricingUnitsLoading}
                    hasError={!!pricingUnitsError}
                    columns={[
                      {
                        key: 'shortName',
                        minWidth: 180,
                        title: translate('text_175025054762801ioe61wdye'),
                        content: (section) => (
                          <Typography variant="body" color="textSecondary">
                            {section.shortName}
                          </Typography>
                        ),
                      },
                      {
                        key: 'name',
                        maxSpace: true,
                        title: translate('text_6419c64eace749372fc72b0f'),
                        content: (section) => (
                          <Typography variant="body" color="textSecondary">
                            {section.name}
                          </Typography>
                        ),
                      },
                    ]}
                    actionColumnTooltip={() => translate('text_63e51ef4985f0ebd75c212fc')}
                    onRowActionLink={
                      canEditPricingUnits
                        ? ({ id }) => {
                            return generatePath(EDIT_PRICING_UNIT, {
                              pricingUnitId: id,
                            })
                          }
                        : undefined
                    }
                    actionColumn={({ id }) => [
                      {
                        startIcon: 'pen',
                        title: translate('text_63e51ef4985f0ebd75c212fc'),
                        onAction: () =>
                          navigate(
                            generatePath(EDIT_PRICING_UNIT, {
                              pricingUnitId: id,
                            }),
                          ),
                      },
                    ]}
                  />
                </InfiniteScroll>
              )}
            </SettingsListItem>
          )}

          {/* Custom section */}
          <SettingsListItem className={tw({ 'shadow-inherit': hasCustomSections })}>
            <SettingsListItemHeader
              label={translate('text_174223019102916wv632jh62')}
              sublabel={translate('text_17422301910293sbjvqbbq2i')}
              action={
                <Button
                  variant="inline"
                  disabled={!hasPermissions(['invoiceCustomSectionsCreate'])}
                  onClick={() => navigate(CREATE_INVOICE_CUSTOM_SECTION)}
                >
                  {translate('text_1742230191029lznwj3y41nb')}
                </Button>
              }
            />

            {hasCustomSections && (
              <InfiniteScroll
                onBottom={() => {
                  const { currentPage = 0, totalPages = 0 } =
                    invoiceCustomSectionsData?.invoiceCustomSections?.metadata || {}

                  currentPage < totalPages &&
                    !invoiceCustomSectionsLoading &&
                    invoiceCustomSectionsFetchMore?.({
                      variables: { page: currentPage + 1 },
                    })
                }}
              >
                <Table
                  name="invoice-custom-section"
                  containerSize={{ default: 0 }}
                  data={invoiceCustomSectionsData?.invoiceCustomSections?.collection || []}
                  isLoading={invoiceCustomSectionsLoading}
                  hasError={!!invoiceCustomSectionsError}
                  columns={[
                    {
                      key: 'name',
                      title: translate('text_6419c64eace749372fc72b0f'),
                      content: (section) => (
                        <Typography variant="body" color="textSecondary">
                          {section.name}
                        </Typography>
                      ),
                      maxSpace: true,
                    },
                  ]}
                  actionColumnTooltip={() => translate('text_17326382475765mx3dfl4v6t')}
                  actionColumn={(section) => [
                    {
                      startIcon: 'pen',
                      title: translate('text_1732638001460kne05vskb7e'),
                      disabled: !hasPermissions(['invoiceCustomSectionsUpdate']),
                      onAction: () =>
                        navigate(
                          generatePath(EDIT_INVOICE_CUSTOM_SECTION, { sectionId: section.id }),
                        ),
                    },
                    {
                      startIcon: 'trash',
                      title: translate('text_1732638001460kdzkctjfegi'),
                      onAction: () => {
                        openDeleteCustomSectionDialog({
                          id: section.id,
                        })
                      },
                    },
                  ]}
                />
              </InfiniteScroll>
            )}
          </SettingsListItem>
        </SettingsListWrapper>
      </SettingsPaddedContainer>
    </>
  )
}

export default InvoiceSections
