import { PreviewTable, type PreviewTableColumn } from '~/components/designSystem/Table/PreviewTable'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import type {
  PlanPreviewData,
  PlanPreviewRow,
  PreviewCellValue,
  PreviewDetailLabel,
  PreviewQualifier,
} from '~/core/serializers/buildPlanPreviewData'
import type { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import type { TranslateFunc } from '~/hooks/core/useInternationalization'

export const SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID = 'subscription-plan-preview-table'

interface SubscriptionPlanPreviewTableProps {
  data: PlanPreviewData
  translate: TranslateFunc
  currency: CurrencyEnum
  locale?: LocaleEnum
}

// Real translation ids from Task 1.
const K = {
  subscriptionFee: 'text_1782223048614hpapupcc6gu',
  minimumCommitment: 'text_1782223048615tzkt8zfl7zb',
  colName: 'text_178222304861526lr006rl38',
  colBilled: 'text_17822230486157n020egd1q3',
  colUnits: 'text_1782223048615rmf57qlo7ka',
  colPrice: 'text_17822230486157sa0x6qnkwn',
  taxFooter: 'text_1782223048615xcjwjwpk8m6',
  usageBased: 'text_178222304861556wt5ly8kdt',
  variesWithUsage: 'text_17822230486150yjc3p0zuk8',
  timingBeginningOfPeriod: 'text_17822230486156drbcgwv3im',
  timingEndOfPeriod: 'text_1782223048615uw7sc81m608',
  timingOnTransaction: 'text_1782223048615u6681rnxkbc',
  intervalMonthly: 'text_17822230486156idvwim55ka',
  intervalQuarterly: 'text_1782223048615kmq4u89rcwh',
  intervalSemiannual: 'text_1782223048615h9guc3qbjng',
  intervalWeekly: 'text_1782223048615uwsktde0g65',
  intervalYearly: 'text_1782223048615i3muavjkfld',
  qualifierPerUnit: 'text_1782223048615ryc3feojo1q',
  qualifierFlatFee: 'text_1782223048615karzj041hem',
  qualifierPercentOfVolume: 'text_17822230486152rn6wgxlyf6',
  qualifierPerPackage: 'text_1782223048615vd1dcv9zquq',
  qualifierFirstNUnits: 'text_1782223048615ft8swe5x3s8',
  qualifierFirstNTransactions: 'text_1782223048616tzv42620ptn',
  qualifierPerTransaction: 'text_1782223048616pdb7i6st0bw',
  qualifierCommitment: 'text_17822230486168qjhfsbbe8h',
  labelUsage: 'text_1782223048616i4v9ljoc18x',
  labelFreeUnits: 'text_1782223048616z5gmt1gkmrj',
  labelPackage: 'text_17822230486168q4ex9sxj4m',
  labelFreeVolume: 'text_1782223048616yyubypm49b6',
  labelFreeTransactions: 'text_1782223048616uzj383wmd90',
  labelTransactionCost: 'text_1782223048616qkda3m6wjcc',
  labelFixedFee: 'text_1782223048616yxih5krfug9',
  labelMinimum: 'text_178222304861668o6zi936fw',
  labelMaximum: 'text_1782223048616qkrwdmyzq4w',
  labelMinimumSpending: 'text_1782223048616dlfjn4nlsxa',
  tierFromTo: 'text_1782223048616ckvs57mnzff',
  tierFromAbove: 'text_1782223048616d9fxvmvy6xk',
  flatFeeForFirstUnits: 'text_17822898603051pryf16s23k',
  flatFeeForRangeUnits: 'text_1782289860305xi20ikioh8l',
  flatFeeForUnitsAndAbove: 'text_1782289860305wlllob2k8n0',
} as const

const INTERVAL_KEY: Record<PlanInterval, string> = {
  [PlanInterval.Monthly]: K.intervalMonthly,
  [PlanInterval.Quarterly]: K.intervalQuarterly,
  [PlanInterval.Semiannual]: K.intervalSemiannual,
  [PlanInterval.Weekly]: K.intervalWeekly,
  [PlanInterval.Yearly]: K.intervalYearly,
}

const TIMING_KEY = {
  beginningOfPeriod: K.timingBeginningOfPeriod,
  endOfPeriod: K.timingEndOfPeriod,
  onTransaction: K.timingOnTransaction,
} as const

export const SubscriptionPlanPreviewTable = ({
  data,
  translate,
  currency,
  locale,
}: SubscriptionPlanPreviewTableProps) => {
  const formatValue = (v: PreviewCellValue): string => {
    switch (v.type) {
      case 'count':
        return String(v.value)
      case 'displayAmount':
        return intlFormatNumber(Number.parseFloat(v.amount || '0'), { currency, locale })
      case 'percentage':
        return `${v.rate}%`
      case 'usageBased':
        return translate(K.usageBased)
      case 'variesWithUsage':
        return translate(K.variesWithUsage)
      case 'empty':
      default:
        return ''
    }
  }

  const detailLabel = (label: PreviewDetailLabel): string => {
    if (label.type === 'tierRange') {
      return label.to === null || label.to === undefined
        ? translate(K.tierFromAbove, { from: label.from })
        : translate(K.tierFromTo, { from: label.from, to: label.to })
    }

    if (label.type === 'flatFeeForTier') {
      if (label.to === undefined) {
        return translate(K.flatFeeForUnitsAndAbove, { from: label.from })
      }

      if (label.from === 0) {
        return translate(K.flatFeeForFirstUnits, { to: label.to })
      }

      return translate(K.flatFeeForRangeUnits, { from: label.from, to: label.to })
    }

    return translate(K[label.key as keyof typeof K] ?? label.key)
  }

  const qualifierLabel = (q: PreviewQualifier): string => {
    switch (q.type) {
      case 'perUnit':
        return translate(K.qualifierPerUnit)
      case 'flatFee':
        return translate(K.qualifierFlatFee)
      case 'percentOfVolume':
        return translate(K.qualifierPercentOfVolume)
      case 'perPackage':
        return translate(K.qualifierPerPackage, { size: q.size })
      case 'firstNUnits':
        return translate(K.qualifierFirstNUnits, { count: q.count })
      case 'firstNTransactions':
        return translate(K.qualifierFirstNTransactions, { count: q.count })
      case 'perTransaction':
        return translate(K.qualifierPerTransaction)
      case 'commitment':
        return translate(K.qualifierCommitment)
      default:
        return ''
    }
  }

  const mainName = (row: Extract<PlanPreviewRow, { kind: 'main' }>): string => {
    if (row.name) return row.name
    if (row.rowType === 'subscriptionFee') return translate(K.subscriptionFee)
    if (row.rowType === 'minimumCommitment') return translate(K.minimumCommitment)

    return ''
  }

  const columns: PreviewTableColumn<PlanPreviewRow>[] = [
    {
      key: 'name',
      title: translate(K.colName),
      maxSpace: true,
      content: (row) =>
        row.kind === 'main' ? (
          <div className="flex flex-col gap-1">
            <Typography variant="bodyHl" color="grey700">
              {mainName(row)}
            </Typography>
            {row.description && (
              <Typography variant="caption" color="grey600">
                {row.description}
              </Typography>
            )}
          </div>
        ) : (
          <Typography variant="body" color="grey600" className="pl-4">
            {detailLabel(row.label)}
          </Typography>
        ),
    },
    {
      key: 'billed',
      title: translate(K.colBilled),
      minWidth: 160,
      textAlign: 'right',
      content: (row) =>
        row.kind === 'main' ? (
          <div className="flex flex-col">
            <Typography variant="body" color="grey700">
              {translate(INTERVAL_KEY[row.interval])}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate(TIMING_KEY[row.timing])}
            </Typography>
          </div>
        ) : null,
    },
    {
      key: 'units',
      title: translate(K.colUnits),
      minWidth: 160,
      textAlign: 'right',
      content: (row) => (
        <Typography variant="body" color={row.kind === 'main' ? 'grey700' : 'grey600'}>
          {row.kind === 'main' ? formatValue(row.units) : qualifierLabel(row.qualifier)}
        </Typography>
      ),
    },
    {
      key: 'price',
      title: translate(K.colPrice),
      minWidth: 180,
      textAlign: 'right',
      content: (row) => (
        <Typography variant="body" color={row.kind === 'main' ? 'grey700' : 'grey600'}>
          {formatValue(row.kind === 'main' ? row.price : row.value)}
        </Typography>
      ),
    },
  ]

  return (
    <div data-test={SUBSCRIPTION_PLAN_PREVIEW_TABLE_TEST_ID}>
      <PreviewTable
        name="subscription-plan-preview"
        data={data.rows}
        columns={columns}
        // Detail rows (usage / tiers) belong to the charge above them — suppress the
        // divider before a detail row so each charge + its breakdown reads as one group.
        rowHasDivider={(_row, index) => data.rows[index + 1]?.kind !== 'detail'}
        footer={
          <Typography variant="caption" className="mt-3 text-right">
            {translate(K.taxFooter)}
          </Typography>
        }
      />
    </div>
  )
}
