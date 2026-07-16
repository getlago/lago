import { gql } from '@apollo/client'
import { useParams } from 'react-router-dom'

import { CodeSnippet } from '~/components/CodeSnippet'
import { Accordion } from '~/components/designSystem/Accordion'
import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { TypographyWithCopy } from '~/components/designSystem/TypographyWithCopy'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import {
  formatAggregationType,
  formatRoundingFunction,
} from '~/core/formats/formatBillableMetricsItems'
import { LagoApiError, useGetBillableMetricForDetailsOverviewQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment BillableMetricDetails on BillableMetric {
    name
    code
    description
    aggregationType
    fieldName
    recurring
    expression
    weightedInterval
    roundingFunction
    roundingPrecision
    filters {
      id
      key
      values
    }
  }

  query getBillableMetricForDetailsOverview($id: ID!) {
    billableMetric(id: $id) {
      id
      ...BillableMetricDetails
    }
  }
`

export const BillableMetricDetailsOverview = () => {
  const { translate } = useInternationalization()
  const { billableMetricId } = useParams()

  const { data, loading } = useGetBillableMetricForDetailsOverviewQuery({
    variables: { id: billableMetricId as string },
    skip: !billableMetricId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })
  const billableMetric = data?.billableMetric

  if (!billableMetric && loading) {
    return <DetailsPage.Skeleton />
  }

  return (
    <section className="flex flex-col gap-12">
      <section>
        <DetailsPage.SectionTitle variant="subhead1" noWrap>
          {translate('text_1748363241713k6n9cgzat7q')}
        </DetailsPage.SectionTitle>
        <div className="flex flex-col gap-4">
          <DetailsPage.InfoGrid
            grid={[
              {
                label: translate('text_6419c64eace749372fc72b0f'),
                value: billableMetric?.name,
              },
              {
                label: translate('text_62876e85e32e0300e1803127'),
                value: billableMetric?.code ? (
                  <TypographyWithCopy variant="body" color="grey700">
                    {billableMetric.code}
                  </TypographyWithCopy>
                ) : undefined,
              },
            ]}
          />

          {!!billableMetric?.description && (
            <DetailsPage.InfoGridItem
              className="col-span-2"
              label={translate('text_6388b923e514213fed58331c')}
              value={billableMetric?.description}
            />
          )}
        </div>
      </section>
      <div>
        <DetailsPage.SectionTitle variant="subhead1" noWrap>
          {translate('text_1748363241714mwu6t0uhwe4')}
        </DetailsPage.SectionTitle>
        <div className="flex flex-col gap-12">
          <section>
            <div className="mb-4">
              <Typography variant="bodyHl" color="textSecondary" noWrap>
                {translate('text_1748363241714ew3a4g1sawr')}
              </Typography>
              <Typography variant="caption" noWrap>
                {translate('text_17483632417149hokjqyfoaw')}
              </Typography>
            </div>
            <div className="flex flex-col gap-4">
              <DetailsPage.InfoGrid
                grid={[
                  {
                    label: translate('text_632d68358f1fedc68eed3e5a'),
                    value: billableMetric?.recurring
                      ? translate('text_632d68358f1fedc68eed3e64')
                      : translate('text_6310755befed49627644222b'),
                  },
                  {
                    label: translate('text_623b42ff8ee4e000ba87d0ce'),
                    value: billableMetric?.aggregationType
                      ? translate(
                          formatAggregationType(billableMetric?.aggregationType)?.label || '',
                        )
                      : '-',
                  },
                  {
                    label: translate('text_1729771640162n696lisyg7u'),
                    value: billableMetric?.fieldName ?? '-',
                  },
                ]}
              />
              {!!billableMetric?.expression && (
                <DetailsPage.InfoGridItem
                  className="col-span-2"
                  label={translate('text_1729771640162wd2k9x6mrvh')}
                  value={
                    <CodeSnippet
                      variant="minimal"
                      canCopy
                      displayHead={false}
                      language="bash"
                      code={billableMetric?.expression}
                    />
                  }
                />
              )}
            </div>
          </section>

          {!!billableMetric?.roundingFunction && (
            <section>
              <div className="mb-4">
                <Typography variant="bodyHl" color="textSecondary" noWrap>
                  {translate('text_1748363241714nk5s8jj4787')}
                </Typography>
                <Typography variant="caption" noWrap>
                  {translate('text_1748363241714c3jndcn96k9')}
                </Typography>
              </div>
              <div className="flex flex-col gap-4">
                <DetailsPage.InfoGrid
                  grid={[
                    {
                      label: translate('text_17305547268320wyhpbm8hh0'),
                      value: billableMetric?.roundingFunction
                        ? translate(
                            formatRoundingFunction(billableMetric?.roundingFunction)?.label || '',
                          )
                        : '-',
                    },
                    {
                      label: translate('text_1748363241714y66l16bjag2'),
                      value: billableMetric?.roundingPrecision ?? '-',
                    },
                  ]}
                />
              </div>
            </section>
          )}

          {!!billableMetric?.filters?.length && (
            <section>
              <div className="mb-4">
                <Typography variant="bodyHl" color="textSecondary" noWrap>
                  {translate('text_66ab42d4ece7e6b7078993ad')}
                </Typography>
                <Typography variant="caption" noWrap>
                  {translate('text_1748363241714znmroohfgg7')}
                </Typography>
              </div>
              <div className="flex flex-col gap-4">
                {billableMetric?.filters?.map((filter) => (
                  <Accordion
                    key={filter.id}
                    summary={
                      <Typography variant="bodyHl" color="grey700">
                        {filter.key}
                      </Typography>
                    }
                  >
                    <div className="flex flex-col gap-4">
                      <DetailsPage.InfoGridItem
                        label={translate('text_63fcc3218d35b9377840f5a3')}
                        value={filter.key}
                      />
                      <DetailsPage.InfoGridItem
                        label={translate('text_63fcc3218d35b9377840f5ab')}
                        value={
                          <div className="flex flex-wrap gap-2">
                            {filter.values.map((value) => (
                              <Chip key={value} label={value} />
                            ))}
                          </div>
                        }
                      />
                    </div>
                  </Accordion>
                ))}
              </div>
            </section>
          )}
        </div>
      </div>
    </section>
  )
}
