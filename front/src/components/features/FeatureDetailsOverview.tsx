import { gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { Accordion } from '~/components/designSystem/Accordion'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { getPrivilegeValueTypeTranslationKey } from '~/core/constants/form'
import {
  LagoApiError,
  PrivilegeValueTypeEnum,
  useGetFeatureForDetailsOverviewQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment FeatureDetails on FeatureObject {
    id
    name
    code
    description
    privileges {
      id
      name
      code
      valueType
      config {
        selectOptions
      }
    }
  }

  query getFeatureForDetailsOverview($id: ID!) {
    feature(id: $id) {
      ...FeatureDetails
    }
  }
`

export const FeatureDetailsOverview = () => {
  const { translate } = useInternationalization()
  const { featureId = '' } = useParams()

  const { data, loading } = useGetFeatureForDetailsOverviewQuery({
    variables: { id: featureId },
    skip: !featureId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })
  const feature = data?.feature

  if (!feature && loading) {
    return <DetailsPage.Skeleton />
  }

  return (
    <section className="flex flex-col gap-12">
      <section>
        <DetailsPage.SectionTitle variant="subhead1" noWrap>
          {translate('text_1752692673070lgfy2k2bri4')}
        </DetailsPage.SectionTitle>
        <div className="flex flex-col gap-4">
          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_1752692673070tqhrx2dhw5m'),
                value: feature?.name || '-',
              },
              {
                label: translate('text_1752692673070dtc2aidgcmh'),
                value: feature?.code ? (
                  <TypographyWithCopy variant="body" color="grey700">
                    {feature.code}
                  </TypographyWithCopy>
                ) : undefined,
              },
            ]}
          />

          {!!feature?.description && (
            <DetailsPage.InfoGridItem
              className="col-span-2"
              label={translate('text_6388b923e514213fed58331c')}
              value={feature?.description}
            />
          )}
        </div>
      </section>

      {!!feature?.privileges.length && (
        <section>
          <DetailsPage.SectionTitle variant="subhead1" noWrap>
            {translate('text_175269267307071bczmrev9u')}
          </DetailsPage.SectionTitle>

          <div className="flex flex-col gap-4">
            {feature?.privileges.map((privilege) => (
              <Accordion
                key={`privilege-${privilege.id}`}
                summary={
                  <div className="flex flex-col">
                    <Typography variant="bodyHl" color="grey700" noWrap>
                      {privilege.name || '-'}
                    </Typography>
                    <Typography variant="caption" color="grey600" noWrap>
                      {privilege.code}
                    </Typography>
                  </div>
                }
              >
                <DetailsPage.InfoGrid
                  grid={[
                    {
                      label: translate('text_1752845254936itxrmqo8h54'),
                      value: privilege.name || '-',
                    },
                    {
                      label: translate('text_1752845254936jdsefrsvmam'),
                      value: privilege.code ? (
                        <TypographyWithCopy variant="body" color="grey700">
                          {privilege.code}
                        </TypographyWithCopy>
                      ) : undefined,
                    },
                    {
                      label: translate('text_175287350361170qk4c93fmm'),
                      value: translate(getPrivilegeValueTypeTranslationKey[privilege.valueType]),
                    },
                    ...(privilege.valueType === PrivilegeValueTypeEnum.Select
                      ? [
                          {
                            label: translate('text_1752862804124q8fjgwp3ep9'),
                            value: privilege.config?.selectOptions?.join(', '),
                          },
                        ]
                      : []),
                  ]}
                />
              </Accordion>
            ))}
          </div>
        </section>
      )}
    </section>
  )
}
