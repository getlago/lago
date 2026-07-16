import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { useDeleteAddOnDialog } from '~/components/addOns/DeleteAddOnDialog'
import { Card } from '~/components/designSystem/Card'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { ADD_ONS_ROUTE, UPDATE_ADD_ON_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, LagoApiError, useGetAddOnForDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  query getAddOnForDetails($addOn: ID!) {
    addOn(id: $addOn) {
      id
      name
      amountCents
      amountCurrency
      code
      taxes {
        id
        code
        name
        rate
      }
    }
  }
`

const AddOnDetails = () => {
  const navigate = useNavigate()
  const { hasPermissions } = usePermissions()
  const { translate } = useInternationalization()
  const { addOnId } = useParams()

  const { openDeleteAddOnDialog } = useDeleteAddOnDialog()

  const {
    data: addOnResult,
    loading: isAddOnLoading,
    error: addOnError,
  } = useGetAddOnForDetailsQuery({
    variables: {
      addOn: addOnId as string,
    },
    skip: !addOnId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error: addOnError,
    loading: isAddOnLoading,
    redirectTo: ADD_ONS_ROUTE,
    translateKey: 'text_1777995443788l735b53lgd1',
  })

  const addOn = addOnResult?.addOn

  const amountWithCurrency = intlFormatNumber(
    deserializeAmount(addOn?.amountCents, addOn?.amountCurrency || CurrencyEnum.Usd) || 0,
    {
      currencyDisplay: 'symbol',
      currency: addOn?.amountCurrency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 15,
    },
  )

  const actions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_626162c62f790600f850b6fe'),
      dataTest: 'addon-details-actions',
      items: [
        {
          label: translate('text_625fd39a15394c0117e7d792'),
          dataTest: 'addon-details-edit',
          hidden: !hasPermissions(['addonsUpdate']),
          onClick: (closePopper) => {
            navigate(generatePath(UPDATE_ADD_ON_ROUTE, { addOnId: addOnId as string }))
            closePopper()
          },
        },
        {
          label: translate('text_629728388c4d2300e2d38182'),
          hidden: !addOn || !hasPermissions(['addonsDelete']),
          onClick: (closePopper) => {
            if (!addOn) return
            openDeleteAddOnDialog({
              addOn,
              callback: () => {
                navigate(ADD_ONS_ROUTE)
              },
            })
            closePopper()
          },
        },
      ],
    },
  ]

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[{ label: translate('text_629728388c4d2300e2d3809b'), path: ADD_ONS_ROUTE }]}
        entity={{
          viewName: addOn?.name || '',
          viewNameLoading: isAddOnLoading,
          metadata: translate('text_629728388c4d2300e2d3810b', { amountWithCurrency }),
          metadataLoading: isAddOnLoading,
        }}
        actions={{ items: actions, loading: isAddOnLoading }}
      />

      <DetailsPage.Container>
        <section>
          <DetailsPage.SectionTitle variant="subhead1" noWrap>
            {translate('text_6627e7b9732dbfb6c472e027')}
          </DetailsPage.SectionTitle>
          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_629728388c4d2300e2d380bd'),
                value: addOn?.name,
              },
              {
                label: translate('text_6627e7b9732dbfb6c472e02d'),
                value: addOn?.code ? (
                  <TypographyWithCopy variant="body" color="grey700">
                    {addOn.code}
                  </TypographyWithCopy>
                ) : undefined,
              },
              {
                label: translate('text_632b4acf0c41206cbcb8c324'),
                value: addOn?.amountCurrency,
              },
            ]}
          />
        </section>

        <section>
          <DetailsPage.SectionTitle variant="subhead1" noWrap>
            {translate('text_629728388c4d2300e2d38117')}
          </DetailsPage.SectionTitle>
          <Card className="gap-0 p-0">
            <div className="p-4 shadow-b">
              <DetailsPage.TableDisplay
                name="addon-settings"
                header={[translate('text_624453d52e945301380e49b6')]}
                body={[[amountWithCurrency]]}
              />
            </div>

            <div className="p-4">
              <DetailsPage.InfoGrid
                grid={[
                  {
                    label: translate('text_64be910fba8ef9208686a8e3'),
                    value: !!addOn?.taxes?.length
                      ? addOn.taxes?.map((tax, taxIndex) => (
                          <div key={`add-on-details-tax-${taxIndex}`}>
                            {tax.name} (
                            {intlFormatNumber(Number(tax.rate) / 100 || 0, {
                              style: 'percent',
                            })}
                            )
                          </div>
                        ))
                      : '-',
                  },
                ]}
              />
            </div>
          </Card>
        </section>
      </DetailsPage.Container>
    </>
  )
}

export default AddOnDetails
