import debounce from 'lodash/debounce'
import { useCallback, useMemo } from 'react'
import {
  Line,
  LineChart,
  Tooltip as RechartTooltip,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from 'recharts'
import { NameType, Payload, ValueType } from 'recharts/types/component/DefaultTooltipContent'

import { useAnalyticsState } from '~/components/analytics/AnalyticsStateContext'
import {
  multipleLineChartFakeData,
  multipleLineChartFakeLines,
  multipleLineChartLoadingFakeData,
  multipleLineChartLoadingFakeLines,
} from '~/components/designSystem/graphs/fixtures'
import { Typography } from '~/components/designSystem/Typography'
import { ChartWrapper } from '~/components/layouts/Charts'
import {
  bigNumberShortenNotationFormater,
  getCurrencySymbol,
  intlFormatNumber,
} from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { CurrencyEnum, TimeGranularityEnum, TimezoneEnum } from '~/generated/graphql'
import { theme } from '~/styles'

import {
  calculateYAxisDomain,
  checkOnlyZeroValues,
  getItemDateFormatedByTimeGranularity,
} from './utils'

const LOADING_TICK_SIZE = 32

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

type DataItem = {
  [key: string]: unknown
}

type MultipleLineChartLineVisibleOnGraph<T> = {
  dataKey: DotNestedKeys<T>
  tooltipLabel: string
  colorHex: string
  hideOnGraph?: never
  strokeDasharray?: string
}
type MultipleLineChartLineHiddenFromGraph<T> = {
  dataKey: DotNestedKeys<T>
  tooltipLabel: string
  hideOnGraph: true
  colorHex?: never
  strokeDasharray?: string
}
export type MultipleLineChartLine<T> =
  MultipleLineChartLineVisibleOnGraph<T> | MultipleLineChartLineHiddenFromGraph<T>

type MultipleLineChartProps<T> = {
  blur?: boolean
  currency: CurrencyEnum
  data?: T[]
  lines: Array<MultipleLineChartLine<T>>
  loading: boolean
  xAxisDataKey: DotNestedKeys<T>
  xAxisTickAttributes?: [DotNestedKeys<T>, DotNestedKeys<T>]
  timeGranularity: TimeGranularityEnum
}

type CustomTooltipProps<T> = {
  includeHidden: boolean
  active: boolean
  currency: CurrencyEnum
  payload: Payload<ValueType & { payload: T }, NameType>[] | undefined
  lines: Array<MultipleLineChartLine<T>>
  timeGranularity: TimeGranularityEnum
}

const CustomTooltip = <T,>({
  active,
  currency,
  payload,
  lines,
  timeGranularity,
}: CustomTooltipProps<T>): JSX.Element | null => {
  if (active && payload && payload.length) {
    const labelValues: Record<string, string> = payload?.[0].payload

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
          {lines.map((line, lineIndex) => {
            const associatedPayload = payload.find((p) => p?.dataKey === line.dataKey)

            return (
              <div
                key={`multiple-line-chart-custom-tooltip-${lineIndex}`}
                className="flex items-center justify-between gap-2"
              >
                <div className="flex items-center gap-2">
                  {!!line.colorHex && (
                    <div
                      className="size-3 rounded-full"
                      style={{
                        backgroundColor: line.colorHex,
                      }}
                    ></div>
                  )}
                  <Typography variant="caption" color="white" noWrap>
                    {line.tooltipLabel || line.dataKey}
                  </Typography>
                </div>
                <Typography variant="caption" color="white" noWrap>
                  {intlFormatNumber(
                    deserializeAmount(String(associatedPayload?.value) || 0, currency),
                    {
                      currencyDisplay: 'symbol',
                      currency: currency,
                    },
                  )}
                </Typography>
              </div>
            )
          })}
        </div>
      </>
    )
  }

  return null
}

const MultipleLineChart = <T extends DataItem>({
  blur,
  currency,
  data,
  lines,
  loading,
  xAxisDataKey,
  xAxisTickAttributes,
  timeGranularity,
}: MultipleLineChartProps<T>) => {
  const { hoverDataIndex, setHoverDataIndex, setClickedDataIndex, handleMouseLeave } =
    useAnalyticsState()

  const handleHoverUpdate = useCallback(
    (index: number | undefined) => {
      setHoverDataIndex(index)
    },
    [setHoverDataIndex],
  )

  const { localData, localLines } = useMemo(() => {
    if (loading || !data) {
      return {
        localData: multipleLineChartLoadingFakeData as unknown as T[],
        localLines: multipleLineChartLoadingFakeLines as unknown as Array<MultipleLineChartLine<T>>,
      }
    } else if (!!blur) {
      return {
        localData: multipleLineChartFakeData as unknown as T[],
        localLines: multipleLineChartFakeLines as unknown as Array<MultipleLineChartLine<T>>,
      }
    }

    return {
      // Note: make sure there is at least 2 items to show 2 ticks on the graph
      localData: data.length < 2 ? [...data, ...data] : data,
      localLines: lines,
    }
  }, [blur, data, lines, loading])

  // Use the hover data index from context
  const { localHoverDataIndex } = useMemo(() => {
    return {
      localHoverDataIndex: hoverDataIndex,
    }
  }, [hoverDataIndex])

  const yTooltipPosition = useMemo(() => {
    const DEFAULT_TOOLTIP_Y_GAP = 60
    const TOOLTIP_INNER_LINE_HEIGHT = 31

    return -(DEFAULT_TOOLTIP_Y_GAP + (lines.length || 0) * TOOLTIP_INNER_LINE_HEIGHT)
  }, [lines.length])

  const hasOnlyZeroValues: boolean = useMemo(() => {
    if (!localData?.length || loading) {
      return true
    }

    return checkOnlyZeroValues(localData, localLines)
  }, [localData, localLines, loading])

  const yAxisDomain: [number, number] = useMemo(
    () => calculateYAxisDomain(localData, localLines, hasOnlyZeroValues),
    [localData, localLines, hasOnlyZeroValues],
  )

  return (
    <ChartWrapper className="rounded-xl bg-white" blur={blur}>
      <ResponsiveContainer width="100%" height={232}>
        <LineChart
          margin={{
            top: 1,
            left: 1,
            right: getCurrencySymbol(currency).length > 1 ? 12 : 2,
            bottom: -2,
          }}
          width={500}
          height={300}
          data={localData}
          onClick={(event) =>
            typeof event?.activeTooltipIndex === 'number' &&
            setClickedDataIndex(event.activeTooltipIndex)
          }
          onMouseMove={useMemo(
            () =>
              debounce(
                (event) => {
                  const newIndex = event?.activeTooltipIndex

                  if (typeof newIndex === 'number') {
                    handleHoverUpdate(newIndex)
                  }
                },
                // Scale debounce time more aggressively for larger datasets
                // For 300 elements: ~8ms
                // For 1000 elements: ~49ms
                Math.max(1, Math.round(Math.pow((localData?.length || 0) / 300, 1.5) * 8)),
                {
                  leading: true,
                },
              ),
            [handleHoverUpdate, localData?.length],
          )}
          onMouseLeave={handleMouseLeave}
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

              // Make sure we only render 2 ticks on the graph
              if (index !== 0 && index !== (localData?.length || 0) - 1) {
                return <></>
              }

              // Early return for loading state
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
                // For first tick, use the first attribute on the first data item
                if (index === 0 && localData[0]) {
                  const firstAttributeKey = xAxisTickAttributes[0]
                  const attributeValue = localData[0][firstAttributeKey]

                  dateValue = String(attributeValue)
                }
                // For last tick, use the second attribute on the last data item
                else if (index === localData.length - 1 && localData[localData.length - 1]) {
                  const secondAttributeKey = xAxisTickAttributes[1]
                  const lastItem = localData[localData.length - 1]

                  dateValue = String(lastItem[secondAttributeKey])
                }
              } else {
                // Fallback to previous payload-based approach if xAxisTickAttributes not provided
                dateValue = props.payload?.value || ''
              }

              return (
                <g transform={`translate(${x},${y + 16})`}>
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
            domain={yAxisDomain}
            orientation="right"
            tick={(props: {
              x: number
              y: number
              index: number
              visibleTicksCount: number
              payload: { value: number }
            }) => {
              const { x, y, payload, index, visibleTicksCount } = props

              if (index !== 0 && index !== visibleTicksCount - 1) {
                return <></>
              }

              return (
                <>
                  {!loading ? (
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
                        {index !== 0 && hasOnlyZeroValues
                          ? '-'
                          : bigNumberShortenNotationFormater(
                              deserializeAmount(payload.value, currency),
                              {
                                currency,
                              },
                            )}
                      </text>
                    </g>
                  ) : (
                    <g transform={`translate(${x},${index !== 0 ? y + 2 : y - 12})`}>
                      <rect width={32} height={12} rx={6} fill={theme.palette.grey[100]}></rect>
                    </g>
                  )}
                </>
              )
            }}
          />

          {localLines?.map((line) => {
            return (
              <Line
                key={`multiple-line-chart-line-${line.dataKey}`}
                type="linear"
                hide={line.hideOnGraph}
                dataKey={line.dataKey}
                stroke={line.colorHex}
                strokeWidth={2}
                strokeDasharray={line.strokeDasharray || ''}
                isAnimationActive={false}
                dot={false}
              />
            )
          })}
          {!loading && (
            <RechartTooltip
              defaultIndex={localHoverDataIndex}
              active={typeof localHoverDataIndex === 'number'}
              includeHidden={true}
              cursor={{
                stroke: `${theme.palette.grey[500]}`,
                strokeDasharray: '2 2',
              }}
              offset={0}
              position={{ y: yTooltipPosition }}
              content={({ active, payload, includeHidden }) => (
                <div className="min-w-90 rounded-xl bg-grey-700 px-4 py-3">
                  {!!payload && (
                    <CustomTooltip
                      active={active || false}
                      currency={currency}
                      lines={lines}
                      // Payload does not cast T type from data, so we have to manually override
                      payload={payload as unknown as CustomTooltipProps<T>['payload']}
                      timeGranularity={timeGranularity}
                      includeHidden={!!includeHidden}
                    />
                  )}
                </div>
              )}
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </ChartWrapper>
  )
}

export default MultipleLineChart
