import { PreviewTable, type PreviewTableColumn } from '~/components/designSystem/Table/PreviewTable'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { DateFormat, intlFormatDateTime } from '~/core/timezone/utils'
import type { LocaleEnum } from '~/core/translations'
import type { CurrencyEnum } from '~/generated/graphql'
import type { TranslateFunc } from '~/hooks/core/useInternationalization'

import type { EntityData } from '../common/RichTextEditorContext'

export const ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID = 'one-off-addons-preview-table'

interface OneOffAddOnsPreviewTableProps {
  entities: EntityData[]
  translate: TranslateFunc
  currency: CurrencyEnum
  locale?: LocaleEnum
}

export const OneOffAddOnsPreviewTable = ({
  entities,
  translate,
  currency,
  locale,
}: OneOffAddOnsPreviewTableProps) => {
  const columns: PreviewTableColumn<EntityData>[] = [
    {
      key: 'name',
      title: translate('text_17804985042415hh3kbs8ksh'),
      maxSpace: true,
      content: (entity) => (
        <div className="flex flex-col gap-1">
          <Typography variant="bodyHl" color="grey700">
            {entity.invoiceDisplayName || entity.name}
          </Typography>
          {entity.description && (
            <Typography variant="caption" color="grey600">
              {entity.description}
            </Typography>
          )}
        </div>
      ),
    },
    {
      key: 'billed',
      title: translate('text_178049850424144tpzoeoge3'),
      minWidth: 200,
      textAlign: 'right',
      content: (entity) => {
        if (!entity.fromDatetime && !entity.toDatetime) return null

        const fromDate = entity.fromDatetime
          ? intlFormatDateTime(entity.fromDatetime, {
              formatDate: DateFormat.DATE_MED,
              locale,
            }).date
          : ''
        const toDate = entity.toDatetime
          ? intlFormatDateTime(entity.toDatetime, {
              formatDate: DateFormat.DATE_MED,
              locale,
            }).date
          : ''

        return (
          <Typography variant="body" color="grey700">
            {translate('text_1780498504241eo24fnc6s9u', { fromDate, toDate })}
          </Typography>
        )
      },
    },
    {
      key: 'units',
      title: translate('text_1780498504241avgm5sugii4'),
      textAlign: 'right',
      content: (entity) => (
        <Typography variant="body" color="grey700">
          {entity.units}
        </Typography>
      ),
    },
    {
      key: 'totalAmount',
      title: translate('text_1780498504241di3s12o655k'),
      textAlign: 'right',
      content: (entity) => (
        <Typography variant="body" color="grey700">
          {intlFormatNumber(Number.parseFloat(entity.totalAmount ?? '0'), {
            currency,
            locale,
          })}
        </Typography>
      ),
    },
  ]

  return (
    <div data-test={ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID}>
      <PreviewTable
        name="one-off-addons-preview"
        data={entities}
        columns={columns}
        footer={
          <Typography variant="caption" className="mt-3 text-right">
            {translate('text_17804985042422iw5hwj0u2v')}
          </Typography>
        }
      />
    </div>
  )
}
