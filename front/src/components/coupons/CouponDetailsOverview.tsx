import { gql } from '@apollo/client'
import { Icon } from 'lago-design-system'
import { useParams } from 'react-router-dom'

import { formatCouponValue } from '~/components/coupons/utils'
import { Card } from '~/components/designSystem/Card'
import { Status } from '~/components/designSystem/Status'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import {
  getCouponFrequencyTranslationKey,
  getCouponTypeTranslationKey,
} from '~/core/constants/form'
import { couponStatusMapping } from '~/core/constants/statusCouponMapping'
import {
  CouponFrequency,
  CouponTypeEnum,
  LagoApiError,
  useGetCouponForDetailsOverviewQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  fragment CouponDetailsForOverview on Coupon {
    name
    code
    couponType
    amountCurrency
    status
    frequency
    reusable
    expirationAt
    amountCents
    amountCurrency
    percentageRate
    billableMetrics {
      id
      name
    }
    plans {
      id
      name
    }
  }

  query getCouponForDetailsOverview($id: ID!) {
    coupon(id: $id) {
      id
      ...CouponDetailsForOverview
    }
  }
`

export const CouponDetailsOverview = () => {
  const { translate } = useInternationalization()
  const { couponId } = useParams()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  const { data, loading } = useGetCouponForDetailsOverviewQuery({
    variables: { id: couponId as string },
    skip: !couponId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  const coupon = data?.coupon

  let limitationElement: Array<{ id: string; name: string }> = []

  if (!!coupon?.billableMetrics?.length) {
    limitationElement = coupon.billableMetrics
  } else if (!!coupon?.plans?.length) {
    limitationElement = coupon?.plans
  }

  const hasLimitations =
    !!coupon?.reusable ||
    !!coupon?.expirationAt ||
    !!coupon?.billableMetrics?.length ||
    !!coupon?.plans?.length

  if (!coupon && loading) {
    return <DetailsPage.Skeleton />
  }

  return (
    <section className="flex flex-col gap-12">
      <section>
        <DetailsPage.SectionTitle variant="subhead1" noWrap>
          {translate('text_664cb90097bfa800e6efa3e4')}
        </DetailsPage.SectionTitle>
        <DetailsPage.InfoGrid
          grid={[
            {
              label: translate('text_62865498824cc10126ab2960'),
              value: coupon?.name,
            },
            {
              label: translate('text_664cb90097bfa800e6efa3e7'),
              value: coupon?.code ? (
                <TypographyWithCopy variant="body" color="grey700">
                  {coupon.code}
                </TypographyWithCopy>
              ) : undefined,
            },
            coupon?.couponType === CouponTypeEnum.FixedAmount && {
              label: translate('text_632b4acf0c41206cbcb8c324'),
              value: coupon?.amountCurrency,
            },
            {
              label: translate('text_62865498824cc10126ab296f'),
              value: <Status {...couponStatusMapping(coupon?.status)} />,
            },
          ]}
        />
      </section>

      <section>
        <DetailsPage.SectionTitle variant="subhead1" noWrap>
          {translate('text_62876e85e32e0300e1803137')}
        </DetailsPage.SectionTitle>
        <Card className="gap-0 p-0">
          <div className="flex flex-col gap-4 p-4 shadow-b">
            <DetailsPage.TableDisplay
              name="coupon-value"
              header={[
                coupon?.couponType === CouponTypeEnum.Percentage &&
                  translate('text_64de472463e2da6b31737de0'),
                coupon?.couponType === CouponTypeEnum.FixedAmount &&
                  translate('text_624453d52e945301380e49b6'),
              ]}
              body={[
                [
                  formatCouponValue({
                    couponType: coupon?.couponType,
                    percentageRate: coupon?.percentageRate,
                    amountCents: coupon?.amountCents,
                    amountCurrency: coupon?.amountCurrency,
                  }),
                ],
              ]}
            />
          </div>

          <div className="flex flex-col gap-4 p-4">
            <DetailsPage.InfoGrid
              grid={[
                {
                  label: translate('text_6560809c38fb9de88d8a52fb'),
                  value: translate(
                    getCouponTypeTranslationKey[coupon?.couponType as CouponTypeEnum],
                  ),
                },
                {
                  label: translate('text_632d68358f1fedc68eed3e9d'),
                  value: translate(
                    getCouponFrequencyTranslationKey[coupon?.frequency as CouponFrequency],
                  ),
                },
              ]}
            />
          </div>
        </Card>
      </section>

      {hasLimitations && (
        <section>
          <DetailsPage.SectionTitle variant="subhead1" noWrap>
            {translate('text_63c83d58e697e8e9236da806')}
          </DetailsPage.SectionTitle>
          <Card className="p-4">
            {!!coupon?.reusable && (
              <DetailsPage.TableDisplay
                name="coupon-reusable"
                header={[
                  <div key="coupon-reusable-header" className="flex flex-row items-center gap-2">
                    <Icon name="validate-filled" size="small" />
                    <Typography variant="captionHl">
                      {translate('text_638f48274d41e3f1d01fc16a')}
                    </Typography>
                  </div>,
                ]}
              />
            )}
            {!!coupon?.expirationAt && (
              <DetailsPage.TableDisplay
                name="coupon-expiration"
                header={[
                  <div key="expiration-date-header" className="flex flex-row items-center gap-2">
                    <Icon name="validate-filled" size="small" />
                    <Typography variant="captionHl">
                      {translate('text_632d68358f1fedc68eed3eb7')}
                    </Typography>
                  </div>,
                ]}
                body={[
                  [
                    <DetailsPage.InfoGridItem
                      key="expiration-date-body"
                      className="py-4"
                      label={translate('text_664cb90097bfa800e6efa3f5')}
                      value={intlFormatDateTimeOrgaTZ(coupon.expirationAt).date}
                    />,
                  ],
                ]}
              />
            )}
            {!!limitationElement?.length && (
              <DetailsPage.TableDisplay
                name="limitation-plan-or-bm"
                header={[
                  <div
                    key="limitation-plan-or-bm-header"
                    className="flex flex-row items-center gap-2"
                  >
                    <Icon name="validate-filled" size="small" />
                    <Typography variant="captionHl">
                      {translate('text_64352657267c3d916f9627a4')}
                    </Typography>
                  </div>,
                ]}
                body={[
                  [
                    <div key="limitation-plan-or-bm-body" className="py-4">
                      {limitationElement.map((element, elementIndex) => (
                        <div
                          className="flex flex-row items-center gap-2"
                          key={`limitation-plan-or-bm-body-${elementIndex}`}
                        >
                          <Icon name={coupon?.plans?.length ? 'board' : 'pulse'} color="dark" />
                          <Typography variant="body" color="grey700">
                            {element.name}
                          </Typography>
                        </div>
                      ))}
                    </div>,
                  ],
                ]}
              />
            )}
          </Card>
        </section>
      )}
    </section>
  )
}
