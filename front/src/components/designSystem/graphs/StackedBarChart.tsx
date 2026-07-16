import { tw } from 'lago-design-system'
import debounce from 'lodash/debounce'
import { useCallback, useMemo } from 'react'
import {
  Bar,
  BarChart,
  Customized,
  Tooltip as RechartTooltip,
  ReferenceLine,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from 'recharts'
import { NameType, Payload, ValueType } from 'recharts/types/component/DefaultTooltipContent'

import { useAnalyticsState } from '~/components/analytics/AnalyticsStateContext'
import { toAmountCents } from '~/components/analytics/prepaidCredits/utils'
import {
  multipleStackedBarChartLoadingFakeBars,
  multipleStackedBarChartLoadingFakeData,
} from '~/components/designSystem/graphs/fixtures'
import { Typography } from '~/components/designSystem/Typography'
import { ChartWrapper } from '~/components/layouts/Charts'
import { bigNumberShortenNotationFormater } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { CurrencyEnum, TimeGranularityEnum, TimezoneEnum } from '~/generated/graphql'
import { theme } from '~/styles'

import {
  calculateYAxisDomain,
  checkOnlyZeroValues,
  getItemDateFormatedByTimeGranularity,
} from './utils'

type DataItem = { [key: string]: unknown }

type DotPrefix<T extends string> = T extends '' ? '' : `.${T}`
type DotNestedKeys<T> = (
  T extends object
    ? { [K in Exclude<keyof T, symbol>]: `${K}${DotPrefix<DotNestedKeys<T[K]>>}` }[Exclude<
        keyof T,
        symbol
      >]
    : ''
) extends infer D
  ? Extract<D, string>
  : never

type StackedBarChartBarVisibleOnGraph<T> = {
  dataKey: DotNestedKeys<T>
  tooltipLabel: string
  colorHex: string
  hideOnGraph?: never
  tooltipIndex?: number
  barIndex?: number
}

type StackedBarChartBarHiddenFromGraph<T> = {
  dataKey: DotNestedKeys<T>
  tooltipLabel: string
  hideOnGraph: true
  colorHex?: never
  tooltipIndex?: number
  barIndex?: number
}

export type StackedBarChartBar<T> =
  StackedBarChartBarVisibleOnGraph<T> | StackedBarChartBarHiddenFromGraph<T>

type StackedBarChartProps<T> = {
  blur?: boolean
  currency: CurrencyEnum
  data?: T[]
  bars: Array<StackedBarChartBar<T>>
  loading: boolean
  xAxisDataKey: DotNestedKeys<T>
  xAxisTickAttributes?: [DotNestedKeys<T>, DotNestedKeys<T>]
  timeGranularity: TimeGranularityEnum
  customFormatter?: (value: string | number, currency: CurrencyEnum) => string
  margin?: {
    top?: number
    right?: number
    bottom?: number
    left?: number
  }
  inlineTooltip?: boolean
}

const LOADING_TICK_SIZE = 32

type CustomTooltipProps<T> = {
  includeHidden: boolean
  active: boolean
  currency: CurrencyEnum
  payload: Payload<ValueType & { payload: T }, NameType>[] | undefined
  bars: Array<StackedBarChartBar<T>>
  timeGranularity: TimeGranularityEnum
  customFormatter?: (value: string | number, currency: CurrencyEnum) => string
  inlineTooltip?: boolean
}

const CustomTooltip = <T,>({
  active,
  payload,
  currency,
  bars,
  timeGranularity,
  customFormatter,
  inlineTooltip,
}: CustomTooltipProps<T>) => {
  if (!active || !payload?.length) return null

  const labelValues = payload[0].payload

  if (inlineTooltip) {
    const date = getItemDateFormatedByTimeGranularity({
      item: {
        startOfPeriodDt: labelValues.startOfPeriodDt,
        endOfPeriodDt: labelValues.endOfPeriodDt,
      },
      timeGranularity,
    })

    const value = customFormatter
      ? customFormatter(labelValues[bars[0].dataKey || '0'], currency)
      : toAmountCents(labelValues[bars[0].dataKey || '0'], currency)

    return (
      <Typography className="w-fit rounded-xl bg-grey-700" variant="caption" color="white">
        {`${date}: ${value}`}
      </Typography>
    )
  }

  return (
    <>
      <Typography className="mb-3" variant="captionHl" color="white">
        {getItemDateFormatedByTimeGranularity({
          item: {
            startOfPeriodDt: labelValues.startOfPeriodDt,
            endOfPeriodDt: labelValues.endOfPeriodDt,
          },
          timeGranularity,
        })}
      </Typography>

      <div className="flex flex-col gap-2">
        {bars
          .sort((a, b) => (a?.tooltipIndex || 0) - (b?.tooltipIndex || 0))
          .map((bar, i) => (
            <div key={i} className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <div className="size-3 rounded-full" style={{ backgroundColor: bar.colorHex }} />
                <Typography variant="caption" color="white" noWrap>
                  {bar.tooltipLabel}
                </Typography>
              </div>
              <Typography variant="caption" color="white" noWrap>
                {customFormatter
                  ? customFormatter(labelValues[bar.dataKey || '0'], currency)
                  : toAmountCents(labelValues[bar.dataKey || '0'], currency)}
              </Typography>
            </div>
          ))}
      </div>
    </>
  )
}

const StackedBarChart = <T extends DataItem>({
  blur,
  currency,
  data,
  bars,
  loading,
  xAxisDataKey,
  xAxisTickAttributes,
  timeGranularity,
  margin,
  customFormatter,
  inlineTooltip,
}: StackedBarChartProps<T>) => {
  const { setClickedDataIndex, setHoverDataIndex, hoverDataIndex, handleMouseLeave } =
    useAnalyticsState()

  const handleHoverUpdate = useCallback(
    (index: number | undefined) => {
      setHoverDataIndex(index)
    },
    [setHoverDataIndex],
  )

  const { localData, localBars } = useMemo(() => {
    const fakeData = {
      localData: multipleStackedBarChartLoadingFakeData as unknown as T[],
      localBars: multipleStackedBarChartLoadingFakeBars as unknown as typeof bars,
    }

    if (loading || !data) {
      return fakeData
    } else if (!!blur) {
      return fakeData
    }

    return {
      localData: data.length < 2 ? [...data, ...data] : data,
      localBars: bars,
    }
  }, [blur, data, bars, loading])

  const { localHoverDataIndex } = useMemo(() => {
    return {
      localHoverDataIndex: hoverDataIndex,
    }
  }, [hoverDataIndex])

  const yTooltipPosition = useMemo(() => {
    const DEFAULT_TOOLTIP_Y_GAP = 60
    const TOOLTIP_INNER_LINE_HEIGHT = 31

    return -(DEFAULT_TOOLTIP_Y_GAP + (bars.length || 0) * TOOLTIP_INNER_LINE_HEIGHT)
  }, [bars.length])

  const hasOnlyZeroValues: boolean = useMemo(() => {
    if (!localData?.length || loading) {
      return true
    }

    return checkOnlyZeroValues(localData, localBars)
  }, [localData, localBars, loading])

  const yAxisDomain: [number, number] = useMemo(
    () => calculateYAxisDomain(localData, localBars, hasOnlyZeroValues),
    [localData, localBars, hasOnlyZeroValues],
  )

  return (
    <ChartWrapper className="rounded-xl bg-white" blur={blur}>
      <ResponsiveContainer width="100%" height={232}>
        <BarChart
          width={500}
          height={300}
          margin={{
            top: margin?.top ?? 1,
            left: margin?.left ?? 1,
            right: margin?.right ?? 12,
            bottom: margin?.bottom ?? -2,
          }}
          data={localData}
          stackOffset="sign"
          onMouseLeave={handleMouseLeave}
          onMouseMove={useMemo(
            () =>
              debounce((event) => {
                const index = event?.activeTooltipIndex

                if (typeof index === 'number') handleHoverUpdate(index)
              }, 16),
            [handleHoverUpdate],
          )}
          onClick={(event) => {
            if (typeof event?.activeTooltipIndex === 'number') {
              setClickedDataIndex(event.activeTooltipIndex)
            }
          }}
        >
          <XAxis
            axisLine={true}
            tickLine={false}
            dataKey={xAxisDataKey}
            stroke={theme.palette.grey[300]}
            interval={0}
            domain={['dataMin', 'dataMax']}
            tick={(props: {
              x: number
              y: number
              index: number
              payload: { value: string }
            }): React.ReactElement => {
              const { x, y, index } = props

              if (index !== 0 && index !== (localData?.length || 0) - 1) {
                return <></>
              }

              if (loading) {
                return (
                  <g transform={`translate(${index !== 0 ? x - LOADING_TICK_SIZE : x},${y + 6})`}>
                    <rect
                      width={LOADING_TICK_SIZE}
                      height={12}
                      rx={6}
                      fill={theme.palette.grey[100]}
                    ></rect>
                  </g>
                )
              }

              let dateValue = ''

              if (xAxisTickAttributes && localData?.length) {
                if (index === 0 && localData[0]) {
                  const firstAttributeKey = xAxisTickAttributes[0]
                  const attributeValue = localData[0][firstAttributeKey]

                  dateValue = String(attributeValue)
                } else if (index === localData.length - 1 && localData[localData.length - 1]) {
                  const secondAttributeKey = xAxisTickAttributes[1]
                  const lastItem = localData[localData.length - 1]

                  dateValue = String(lastItem[secondAttributeKey])
                }
              } else {
                dateValue = props.payload?.value || ''
              }

              const shift = localData?.length ? 500 / localData?.length : 0

              const translateX = index === 0 ? 0 : x + shift

              return (
                <g transform={`translate(${translateX},${y + 16})`}>
                  <text
                    fill={theme.palette.grey[600]}
                    style={{
                      fontFamily: 'Inter',
                      fontSize: '14px',
                      fontStyle: 'normal',
                      fontWeight: '400',
                      lineHeight: '24px',
                      letterSpacing: '-0.16px',
                      textAnchor: index === 0 ? 'start' : 'end',
                    }}
                  >
                    {
                      intlFormatDateTime(dateValue, {
                        timezone: TimezoneEnum.TzUtc,
                      }).date
                    }
                  </text>
                </g>
              )
            }}
          />
          <YAxis
            allowDataOverflow={false}
            axisLine={false}
            stroke={theme.palette.grey[600]}
            tickLine={false}
            interval={0}
            orientation="right"
            domain={yAxisDomain}
            tick={(props: {
              x: number
              y: number
              index: number
              visibleTicksCount: number
              payload: { value: number }
            }) => {
              const { x, y, payload, index, visibleTicksCount } = props

              const isZeroTick = payload.value === 0
              const isEdgeTick = index === 0 || index === visibleTicksCount - 1

              if (!isZeroTick && !isEdgeTick) {
                return <></>
              }

              const isNegative = payload.value < 0

              const formatted = customFormatter
                ? customFormatter(payload.value, currency)
                : bigNumberShortenNotationFormater(isNegative ? -payload.value : payload.value, {
                    currency,
                  })

              if (loading) {
                return (
                  <g transform={`translate(${x},${index !== 0 ? y + 2 : y - 12})`}>
                    <rect width={32} height={12} rx={6} fill={theme.palette.grey[100]}></rect>
                  </g>
                )
              }

              return (
                <g transform={`translate(${x},${index !== 0 ? y + 12 : y - 2})`}>
                  <text
                    fill={theme.palette.grey[600]}
                    style={{
                      fontFamily: 'Inter',
                      fontSize: '14px',
                      fontStyle: 'normal',
                      fontWeight: '400',
                      lineHeight: '24px',
                      letterSpacing: '-0.16px',
                    }}
                  >
                    {index !== 0 && hasOnlyZeroValues ? (
                      '-'
                    ) : (
                      <>
                        {isNegative && '-'}
                        {formatted}
                      </>
                    )}
                  </text>
                </g>
              )
            }}
          />

          <Customized
            // @ts-expect-error Recharts component prop types are not fully compatible
            component={({ yAxisMap }) => {
              const yAxis = yAxisMap[Object.keys(yAxisMap)[0]]

              if (yAxisDomain[0] === 0 || yAxisDomain[1] === 0 || yAxisDomain[1] === 1) return null

              if (!yAxis || typeof yAxis.scale !== 'function') return null

              const yZero = yAxis.scale(0)

              if (typeof yZero !== 'number') return null

              const hasZeroTick = yZero >= yAxis.y && yZero <= yAxis.y + yAxis.height

              if (hasZeroTick) return null

              if (loading) {
                return (
                  <g>
                    <rect width={32} height={12} rx={6} fill={theme.palette.grey[100]}></rect>
                  </g>
                )
              }

              return (
                <g>
                  <text
                    x={yAxis.x + 8}
                    y={yZero + 4}
                    textAnchor="start"
                    fill={theme.palette.grey[600]}
                    style={{
                      fontFamily: 'Inter',
                      fontSize: '14px',
                      fontWeight: 400,
                      letterSpacing: '-0.16px',
                    }}
                  >
                    {customFormatter
                      ? customFormatter('0', currency)
                      : bigNumberShortenNotationFormater(deserializeAmount(0, currency), {
                          currency,
                        })}
                  </text>
                </g>
              )
            }}
          />

          <ReferenceLine
            ifOverflow="extendDomain"
            y={0}
            stroke={theme.palette.grey[300]}
            strokeWidth={1}
          />

          {!loading && (
            <RechartTooltip
              defaultIndex={localHoverDataIndex}
              cursor={false}
              active={typeof localHoverDataIndex === 'number'}
              includeHidden={true}
              offset={0}
              position={{ y: yTooltipPosition }}
              content={({ active, payload, includeHidden }) => (
                <div
                  className={tw('rounded-xl bg-grey-700 px-4 py-3', {
                    'min-w-90': !inlineTooltip,
                  })}
                >
                  {!!payload && (
                    <CustomTooltip
                      active={active || false}
                      currency={currency}
                      bars={bars}
                      payload={payload as unknown as CustomTooltipProps<T>['payload']}
                      timeGranularity={timeGranularity}
                      includeHidden={!!includeHidden}
                      customFormatter={customFormatter}
                      inlineTooltip={inlineTooltip}
                    />
                  )}
                </div>
              )}
            />
          )}

          {typeof localHoverDataIndex === 'number' && (
            <>
              <Customized
                // @ts-expect-error Recharts xAxisMap and yAxisMap prop typing is incomplete
                component={({ xAxisMap, yAxisMap }) => {
                  const xAxis = xAxisMap[Object.keys(xAxisMap)[0]]
                  const yAxis = yAxisMap[Object.keys(yAxisMap)[0]]
                  const xValue = data?.[localHoverDataIndex]?.[xAxisDataKey]

                  if (!xAxis || !xValue || typeof xAxis.scale !== 'function') return null

                  const x = xAxis.scale(xValue)
                  const bandwidth = xAxis.bandSize ?? 0

                  if (typeof x !== 'number' || !yAxis) return null

                  return (
                    <line
                      x1={x + bandwidth / 2}
                      x2={x + bandwidth / 2}
                      y1={yAxis.y}
                      y2={yAxis.y + yAxis.height}
                      stroke={theme.palette.grey[500]}
                      strokeDasharray="2 2"
                      strokeWidth={1}
                    />
                  )
                }}
              />
            </>
          )}

          {localBars
            .sort((a, b) => (a?.barIndex || -100) - (b?.barIndex || -100))
            .map((line) => (
              <Bar
                key={line.dataKey}
                dataKey={line.dataKey}
                stackId="stack"
                fill={line.colorHex}
                isAnimationActive={false}
              />
            ))}
        </BarChart>
      </ResponsiveContainer>
    </ChartWrapper>
  )
}

export default StackedBarChart
