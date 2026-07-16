import debounce from 'lodash/debounce'
import { memo, useCallback, useMemo } from 'react'
import {
  Area,
  AreaChart as RechartAreaChart,
  Tooltip as RechartTooltip,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from 'recharts'

import { useAnalyticsState } from '~/components/analytics/AnalyticsStateContext'
import { Typography } from '~/components/designSystem/Typography'
import { ChartWrapper } from '~/components/layouts/Charts'
import {
  bigNumberShortenNotationFormater,
  getCurrencySymbol,
} from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { theme } from '~/styles'

import { AreaChartDataType } from './types'

const LOADING_TICK_SIZE = 32
const DEFAULT_AREA_CHART_HEIGHT = 112
const DEFAULT_TICK_FONT_SIZE = 12

type CustomTooltipProps = {
  active?: boolean
  payload?: {
    payload?: {
      axisName?: string | null
      value?: number | null
      tooltipLabel?: string | null
    }
  }[]
}

const CustomTooltip = ({ active, payload }: CustomTooltipProps): JSX.Element | null => {
  if (active && payload && payload.length) {
    return (
      <Typography
        className="w-fit rounded-xl bg-grey-700 px-4 py-3"
        variant="caption"
        color="white"
      >
        {payload[0]?.payload?.tooltipLabel}
      </Typography>
    )
  }

  return null
}

type AreaChartProps = {
  blur: boolean
  data: AreaChartDataType[]
  loading?: boolean
  hasOnlyZeroValues?: boolean
  currency: CurrencyEnum
  height?: number
  tickFontSize?: number
}

const AreaChart = memo(
  ({
    blur,
    currency,
    data,
    hasOnlyZeroValues,
    loading,
    height = DEFAULT_AREA_CHART_HEIGHT,
    tickFontSize = DEFAULT_TICK_FONT_SIZE,
  }: AreaChartProps) => {
    const { hoverDataIndex, setHoverDataIndex, setClickedDataIndex, handleMouseLeave } =
      useAnalyticsState()

    const handleHoverUpdate = useCallback(
      (index: number | undefined) => {
        setHoverDataIndex(index)
      },
      [setHoverDataIndex],
    )

    // Use the hover data index from context
    const { localHoverDataIndex } = useMemo(() => {
      return {
        localHoverDataIndex: hoverDataIndex,
      }
    }, [hoverDataIndex])

    return (
      <ChartWrapper blur={blur}>
        <ResponsiveContainer width="100%" height={height}>
          <RechartAreaChart
            margin={{
              top: 3,
              left: 3,
              right: getCurrencySymbol(currency).length > 1 ? 12 : 2,
              bottom: -2,
            }}
            data={data}
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
                  Math.max(1, Math.round(Math.pow((data?.length || 0) / 300, 1.5) * 8)),
                  {
                    leading: true,
                  },
                ),
              [handleHoverUpdate, data?.length],
            )}
            onMouseLeave={handleMouseLeave}
          >
            <defs>
              <linearGradient id="colorUv" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={theme.palette.primary[200]} stopOpacity={0.4} />
                <stop offset="60%" stopColor={theme.palette.primary[200]} stopOpacity={0} />
              </linearGradient>
            </defs>
            <XAxis
              axisLine={true}
              stroke={theme.palette.grey[200]}
              tickLine={false}
              interval={0}
              domain={['dataMin', 'dataMax']}
              dataKey="axisName"
              tick={(props: {
                x: number
                y: number
                index: number
                payload: { value: string }
              }) => {
                const { x, y, payload, index } = props

                if (index !== 0 && index !== data.length - 1) {
                  return <></>
                }

                const tickUpperSpacing = tickFontSize >= 14 ? 16 : 10

                return (
                  <>
                    {!loading ? (
                      <g transform={`translate(${x},${y + tickUpperSpacing})`}>
                        <text
                          fill={theme.palette.grey[600]}
                          style={{
                            fontFamily: 'Inter',
                            fontSize: `${tickFontSize}px`,
                            fontStyle: 'normal',
                            fontWeight: '400',
                            lineHeight: '16px',
                            letterSpacing: '-0.16px',
                            textAnchor: index === 0 ? 'start' : 'end',
                          }}
                        >
                          {payload?.value}
                        </text>
                      </g>
                    ) : (
                      <g
                        transform={`translate(${index !== 0 ? x - LOADING_TICK_SIZE : x},${y + 2})`}
                      >
                        <rect
                          width={LOADING_TICK_SIZE}
                          height={12}
                          rx={6}
                          fill={theme.palette.grey[100]}
                        ></rect>
                      </g>
                    )}
                  </>
                )
              }}
            />
            <YAxis
              axisLine={false}
              stroke={theme.palette.grey[600]}
              tickLine={false}
              interval={0}
              domain={[0, 'dataMax + 10']}
              orientation="right"
              dataKey="value"
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
                            fontSize: `${tickFontSize}px`,
                            fontStyle: 'normal',
                            fontWeight: '400',
                            lineHeight: '16px',
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
            <Area
              isAnimationActive={false}
              dataKey="value"
              stroke={!loading ? theme.palette.primary[600] : theme.palette.grey[200]}
              strokeWidth={2}
              fill={!loading ? 'url(#colorUv)' : 'transparent'}
            />
            {!loading && (
              <RechartTooltip
                isAnimationActive={false}
                defaultIndex={localHoverDataIndex}
                active={typeof localHoverDataIndex === 'number'}
                cursor={{
                  stroke: `${theme.palette.grey[500]}`,
                  strokeDasharray: '2 2',
                }}
                position={{ y: -55 }}
                offset={0}
                content={<CustomTooltip />}
              />
            )}
          </RechartAreaChart>
        </ResponsiveContainer>
      </ChartWrapper>
    )
  },
)

AreaChart.displayName = 'AreaChart'

export default AreaChart
