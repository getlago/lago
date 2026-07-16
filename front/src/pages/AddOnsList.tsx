import { gql } from '@apollo/client'
import { Icon, tw } from 'lago-design-system'
import { generatePath } from 'react-router-dom'

import { useDeleteAddOnDialog } from '~/components/addOns/DeleteAddOnDialog'
import { Avatar } from '~/components/designSystem/Avatar'
import { GenericPlaceholderProps } from '~/components/designSystem/GenericPlaceholder'
import { InfiniteScroll } from '~/components/designSystem/InfiniteScroll'
import { Table } from '~/components/designSystem/Table/Table'
import { ActionItem } from '~/components/designSystem/Table/types'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { formatCountToMetadata } from '~/components/MainHeader/formatCountToMetadata'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { SearchInput } from '~/components/SearchInput'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  ADD_ON_DETAILS_ROUTE,
  ADD_ONS_ROUTE,
  CREATE_ADD_ON_ROUTE,
  UPDATE_ADD_ON_ROUTE,
  useNavigate,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { useAddOnsLazyQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useDebouncedSearch } from '~/hooks/useDebouncedSearch'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment AddOnItem on AddOn {
    id
    name
    code
    amountCurrency
    amountCents
    customersCount
    createdAt
  }

  query addOns($page: Int, $limit: Int, $searchTerm: String) {
    addOns(page: $page, limit: $limit, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
        totalCount
      }
      collection {
        id
        ...AddOnItem
      }
    }
  }
`

const AddOnsList = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { hasPermissions } = usePermissions()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const { openDeleteAddOnDialog } = useDeleteAddOnDialog()
  const [getAddOns, { data, error, loading, fetchMore, variables }] = useAddOnsLazyQuery({
    variables: { limit: 20 },
    notifyOnNetworkStatusChange: true,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  })
  const { debouncedSearch, isLoading } = useDebouncedSearch(getAddOns, loading)
  const list = data?.addOns?.collection || []

  const canCreateAddOns = hasPermissions(['addonsCreate'])
  const canUpdateAddOns = hasPermissions(['addonsUpdate'])
  const canDeleteAddOns = hasPermissions(['addonsDelete'])

  const getEmptyState = (): Partial<GenericPlaceholderProps> => {
    if (variables?.searchTerm) {
      return {
        title: translate('text_63bee4e10e2d53912bfe4da5'),
        subtitle: translate('text_63bee4e10e2d53912bfe4da7'),
      }
    }
    if (canCreateAddOns) {
      return {
        title: translate('text_629728388c4d2300e2d380c9'),
        subtitle: translate('text_629728388c4d2300e2d380df'),
        buttonTitle: translate('text_629728388c4d2300e2d3810f'),
        buttonVariant: 'primary',
        buttonAction: () => navigate(CREATE_ADD_ON_ROUTE),
      }
    }
    return {
      title: translate('text_664de6f0ec798e005a110d19'),
      subtitle: translate('text_629728388c4d2300e2d380df'),
    }
  }

  const addOnsTotalCount = data?.addOns?.metadata?.totalCount

  return (
    <>
      <MainHeader.Configure
        entity={{
          viewName: translate('text_629728388c4d2300e2d3809b'),
          metadata: formatCountToMetadata(addOnsTotalCount, translate),
          metadataLoading: isLoading,
        }}
        actions={{
          items: [
            {
              type: 'action',
              label: translate('text_629728388c4d2300e2d38085'),
              variant: 'primary',
              hidden: !canCreateAddOns,
              onClick: () => navigate(CREATE_ADD_ON_ROUTE),
              dataTest: 'create-addon-cta',
            },
          ],
        }}
        filtersSection={
          <SearchInput
            onChange={debouncedSearch}
            placeholder={translate('text_63bee4e10e2d53912bfe4db8')}
          />
        }
      />

      <InfiniteScroll
        onBottom={() => {
          const { currentPage = 0, totalPages = 0 } = data?.addOns?.metadata || {}

          currentPage < totalPages &&
            !isLoading &&
            fetchMore({
              variables: { page: currentPage + 1 },
            })
        }}
      >
        <Table
          name="add-ons-list"
          data={list}
          containerSize={{
            default: 16,
            md: 48,
          }}
          containerClassName={tw('h-[calc(100%-theme(space.nav))] border-t border-grey-300')}
          rowSize={72}
          isLoading={isLoading}
          hasError={!!error}
          onRowActionLink={({ id }) => generatePath(ADD_ON_DETAILS_ROUTE, { addOnId: id })}
          rowDataTestId={(addOn) => `${addOn.name}`}
          columns={[
            {
              key: 'name',
              title: translate('text_629728388c4d2300e2d380bd'),
              minWidth: 200,
              maxSpace: true,
              content: ({ name, code, amountCents, amountCurrency }) => (
                <div className="flex items-center gap-3">
                  <Avatar size="big" variant="connector">
                    <Icon name="puzzle" color="dark" />
                  </Avatar>
                  <div>
                    <Typography color="textSecondary" variant="bodyHl" noWrap>
                      {name}
                    </Typography>
                    <div className="flex items-baseline gap-1">
                      <TypographyWithCopy className="shrink-0" compact noWrap variant="caption">
                        {code}
                      </TypographyWithCopy>
                      <Typography className="min-w-0" variant="caption" noWrap>
                        {`• ${translate('text_629728388c4d2300e2d3810b', {
                          amountWithCurrency: intlFormatNumber(
                            deserializeAmount(amountCents, amountCurrency) || 0,
                            {
                              currencyDisplay: 'symbol',
                              currency: amountCurrency,
                            },
                          ),
                        })}`}
                      </Typography>
                    </div>
                  </div>
                </div>
              ),
            },
            {
              key: 'customersCount',
              title: translate('text_629728388c4d2300e2d380cd'),
              textAlign: 'right',
              minWidth: 112,
              content: ({ customersCount }) => (
                <Typography color="grey600" variant="bodyHl" noWrap>
                  {customersCount}
                </Typography>
              ),
            },
            {
              key: 'createdAt',
              title: translate('text_629728388c4d2300e2d380e3'),
              minWidth: 140,
              content: ({ createdAt }) => (
                <Typography color="textSecondary" variant="bodyHl" noWrap>
                  {intlFormatDateTimeOrgaTZ(createdAt).date}
                </Typography>
              ),
            },
          ]}
          actionColumnTooltip={
            canUpdateAddOns && canDeleteAddOns
              ? () => translate('text_629728388c4d2300e2d3810d')
              : undefined
          }
          actionColumn={(addOn) => {
            const actions: ActionItem<typeof addOn>[] = []

            if (canUpdateAddOns) {
              actions.push({
                startIcon: 'pen',
                title: translate('text_629728388c4d2300e2d3816a'),
                onAction: () => navigate(generatePath(UPDATE_ADD_ON_ROUTE, { addOnId: addOn.id })),
              })
            }

            if (canDeleteAddOns) {
              actions.push({
                startIcon: 'trash',
                title: translate('text_629728388c4d2300e2d38182'),
                onAction: () => {
                  openDeleteAddOnDialog({
                    addOn,
                    callback: () => {
                      navigate(ADD_ONS_ROUTE)
                    },
                  })
                },
              })
            }

            return actions
          }}
          placeholder={{
            errorState: !!variables?.searchTerm
              ? {
                  title: translate('text_623b53fea66c76017eaebb6e'),
                  subtitle: translate('text_63bab307a61c62af497e0599'),
                }
              : {
                  title: translate('text_629728388c4d2300e2d380d5'),
                  subtitle: translate('text_629728388c4d2300e2d380eb'),
                  buttonTitle: translate('text_629728388c4d2300e2d38110'),
                  buttonVariant: 'primary',
                  buttonAction: () => location.reload(),
                },

            emptyState: getEmptyState(),
          }}
        />
      </InfiniteScroll>
    </>
  )
}

export default AddOnsList
