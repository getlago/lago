import { Fragment } from 'react'
import { generatePath } from 'react-router-dom'

import { Chip } from '~/components/designSystem/Chip'
import { Status } from '~/components/designSystem/Status'
import { Table, TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { EDIT_QUOTE_ROUTE, QUOTE_VERSION_PREVIEW_ROUTE } from '~/core/router'
import { QuoteDetailItemFragment, StatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { getQuoteStatusMapping } from './common/getQuoteStatusMapping'
import { useQuoteVersionActions } from './hooks/useQuoteVersionActions'

type QuoteVersion = QuoteDetailItemFragment['versions'][number]

interface QuoteDetailsVersionsProps {
  quote: QuoteDetailItemFragment
}

export const QUOTE_VERSIONS_TABLE_TEST_ID = 'quote-versions-table'

const QuoteDetailsVersions = ({ quote }: QuoteDetailsVersionsProps): JSX.Element => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const { getActions } = useQuoteVersionActions()

  const getRowLink = (version: QuoteVersion): string =>
    version.status === StatusEnum.Draft
      ? generatePath(EDIT_QUOTE_ROUTE, { quoteId: quote.id, versionId: version.id })
      : generatePath(QUOTE_VERSION_PREVIEW_ROUTE, { quoteId: quote.id, versionId: version.id })

  const versionColumns: Array<TableColumn<QuoteVersion>> = [
    {
      key: 'status',
      title: translate('text_63ac86d797f728a87b2f9fa7'),
      minWidth: 100,
      content: ({ status }) => <Status {...getQuoteStatusMapping(status, translate)} />,
    },
    {
      key: 'version',
      maxSpace: true,
      title: translate('text_1775747115932pql5mtb30dc'),
      minWidth: 80,
      content: ({ version }) => (
        <Typography color="grey600">
          {quote.number} - v{version}
        </Typography>
      ),
    },
    {
      key: 'createdAt',
      title: translate('text_17758254440392sc27lxm6ua'),
      minWidth: 120,
      maxSpace: true,
      content: ({ createdAt }) => (
        <Typography color="grey600">{intlFormatDateTimeOrgaTZ(createdAt).date}</Typography>
      ),
    },
  ]

  const quoteDetails = [
    {
      label: translate('text_177581001572954eedouxq5u'),
      value: quote.number,
    },
    {
      label: translate('text_65201c5a175a4b0238abf29a'),
      value: `${quote.customer.displayName} - ${quote.customer.externalId}`,
    },
    {
      label: translate('text_6560809c38fb9de88d8a52fb'),
      value: translate(getQuoteOrderTypeTranslationKey(quote.orderType)),
    },
    ...((quote.owners ?? []).length > 0
      ? [
          {
            label: translate('text_1776429591588dnpx1guz0cl'),
            value: (
              <div className="flex flex-row gap-4">
                {quote.owners?.map((owner) => (
                  <Chip key={owner.id} label={owner.email} />
                ))}
              </div>
            ),
          },
        ]
      : []),
  ]

  const versionActionColumn = (version: QuoteVersion) => {
    const actions = getActions(quote, version)

    if (actions.length === 0) return null

    return actions.map(({ icon, label, onAction }) => ({
      startIcon: icon,
      title: label,
      onAction: () => onAction(),
    }))
  }

  return (
    <DetailsPage.Container className="max-w-full gap-12 pt-12">
      <section className="flex flex-col gap-4 pb-12 shadow-b">
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1">{translate('text_17757493673753qivx6ijtc0')}</Typography>
          <Typography variant="caption">{translate('text_1775807564102me0jot8mmkl')}</Typography>
        </div>
        <div className="grid grid-cols-[200px_1fr] gap-x-4 gap-y-2">
          {quoteDetails.map(({ label, value }) => (
            <Fragment key={label}>
              <Typography color="grey600" variant="caption">
                {label}
              </Typography>
              <Typography variant="body" color="grey700">
                {value}
              </Typography>
            </Fragment>
          ))}
        </div>
      </section>
      <section className="flex flex-col gap-4" data-test={QUOTE_VERSIONS_TABLE_TEST_ID}>
        <div className="flex flex-col gap-2">
          <Typography variant="subhead1">{translate('text_1775825275651t25f8xbhmai')}</Typography>
          <Typography variant="caption">{translate('text_1775825275651evevz6qh4d0')}</Typography>
        </div>
        <Table
          name="quote-versions"
          data={quote.versions}
          containerSize={0}
          columns={versionColumns}
          onRowActionLink={getRowLink}
          actionColumnTooltip={() => translate('text_1776414006125pcxcyeblul7')}
          actionColumn={versionActionColumn}
        />
      </section>
    </DetailsPage.Container>
  )
}

export default QuoteDetailsVersions
