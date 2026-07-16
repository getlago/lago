import { useEffect, useState } from 'react'
import { Bar, BarChart, BarProps, ResponsiveContainer, XAxis, YAxis } from 'recharts'

import { ChartWrapper } from '~/components/layouts/Charts'

import { Tooltip } from '../Tooltip'

type InlineBarsChartProps = {
  colors: string[]
  data: Record<string, number>[]
  hoveredBarId?: string
  tooltipsData?: Record<string, string>[]
  lineHeight?: number
}

type TShapeBarProps = Omit<BarProps, 'name' | 'opacity'>

const BarWithBorder = (
  props: TShapeBarProps & {
    opacity?: number
  },
) => {
  const { fill, height, opacity, width, x, y, className } = props

  return (
    <g>
      <rect
        className={className}
        opacity={opacity}
        x={x}
        y={y}
        width={width}
        height={height}
        stroke="none"
        fill={fill}
      />
      {x !== 0 && (
        <rect className="fill-white" x={x} y={y} width={2} height={height} stroke="none" />
      )}
    </g>
  )
}

BarWithBorder.displayName = 'BarWithBorder'

const InlineBarsChart = ({
  colors,
  data,
  hoveredBarId,
  tooltipsData,
  lineHeight = 12,
}: InlineBarsChartProps) => {
  const [localHoveredBarId, setLocalHoveredBarId] = useState<string | undefined>(undefined)

  useEffect(() => {
    setLocalHoveredBarId(hoveredBarId)
  }, [hoveredBarId])

  return (
    <ChartWrapper className="overflow-hidden rounded-xl bg-white">
      <ResponsiveContainer width="100%" height={lineHeight}>
        <BarChart
          layout="vertical"
          data={data}
          margin={{
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
          }}
          barCategoryGap={0}
        >
          <XAxis hide axisLine={false} tickLine={false} type="number" domain={[0, 'dataMax']} />
          <YAxis hide axisLine={false} tickLine={false} dataKey="name" type="category" />
          {Object.keys(data[0]).map((key, index) => (
            <Bar
              key={`inline-bar-${key}`}
              isAnimationActive={false}
              dataKey={key}
              stackId="a"
              fill={colors[index]}
              onMouseEnter={!!tooltipsData?.length ? () => setLocalHoveredBarId(key) : undefined}
              onMouseLeave={
                !!tooltipsData?.length ? () => setLocalHoveredBarId(undefined) : undefined
              }
              shape={(props: TShapeBarProps) => (
                <>
                  <BarWithBorder
                    className="bar-with-border"
                    opacity={!localHoveredBarId || localHoveredBarId === key ? 1 : 0.2}
                    {...props}
                    height={lineHeight || props.height}
                  />
                  {!!tooltipsData?.length && (
                    <foreignObject
                      key={`foreign-object-${key}`}
                      width={props.width}
                      height={props.height}
                      transform={`translate(${props.x}, 0)`}
                    >
                      <Tooltip
                        // Position fixed is needed to place properly the first foreignObject child on Safari
                        className="fixed"
                        title={tooltipsData?.[0]?.[key] || ''}
                        placement="top"
                      >
                        <div
                          style={{
                            width: props.width,
                            height: props.hanging,
                            opacity: 0,
                          }}
                        >
                          -
                        </div>
                      </Tooltip>
                    </foreignObject>
                  )}
                </>
              )}
            />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </ChartWrapper>
  )
}

export default InlineBarsChart
