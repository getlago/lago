import tailwindConfig from 'lago-configs/tailwind'
import { Icon, tw } from 'lago-design-system'
import resolveConfig from 'tailwindcss/resolveConfig'

import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'

const fullConfig = resolveConfig(tailwindConfig)
const themeColors = fullConfig.theme.colors

const getColor = (name: string, shade: number): string => {
  const color = themeColors[name as keyof typeof themeColors]

  if (typeof color === 'object' && color !== null && shade in color) {
    return (color as Record<number, string>)[shade]
  }

  return '#000000'
}

// Background colors — light shades from the Tailwind theme
const BG_COLORS = [
  { label: 'Red', value: getColor('red', 100) },
  { label: 'Yellow', value: getColor('yellow', 100) },
  { label: 'Green', value: getColor('green', 100) },
  { label: 'Blue', value: getColor('blue', 100) },
  { label: 'Purple', value: getColor('purple', 100) },
  { label: 'Grey', value: getColor('grey', 100) },
]

// Text colors — dark shades from the Tailwind theme
const TEXT_COLORS = [
  { label: 'Red', value: getColor('red', 600) },
  { label: 'Yellow', value: getColor('yellow', 600) },
  { label: 'Green', value: getColor('green', 600) },
  { label: 'Blue', value: getColor('blue', 600) },
  { label: 'Purple', value: getColor('purple', 600) },
  { label: 'Grey', value: getColor('grey', 600) },
]

type ColorPickerProps = {
  activeBackgroundColor: string | null
  activeTextColor: string | null
  onSelectBackground: (color: string | null) => void
  onSelectText: (color: string | null) => void
}

const ColorPicker = ({
  activeBackgroundColor,
  activeTextColor,
  onSelectBackground,
  onSelectText,
}: ColorPickerProps) => {
  const { translate } = useInternationalization()

  const baseButtonClasses =
    'flex size-8 items-center justify-center rounded-lg border border-grey-300 hover:border-grey-500'

  return (
    <div className="flex flex-col gap-3 p-2">
      {/* Text color section */}
      <div className="flex flex-col gap-1">
        <Typography variant="noteHl">{translate('text_1774969464357oo1dfrfw06m')}</Typography>
        <div className="grid grid-cols-4 gap-1">
          <button
            className={baseButtonClasses}
            title="Clear text color"
            aria-label="Clear text color"
            onClick={() => onSelectText(null)}
          >
            <Icon name="close-circle-unfilled" />
          </button>
          {TEXT_COLORS.map((color) => (
            <button
              key={color.value}
              className={tw(baseButtonClasses, {
                'border-2 border-grey-700': activeTextColor === color.value,
              })}
              title={color.label}
              onClick={() => onSelectText(color.value)}
            >
              <span className="text-sm font-bold" style={{ color: color.value }}>
                <Icon name="text-a" />
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Background color section */}
      <div className="flex flex-col gap-1">
        <Typography variant="noteHl">{translate('text_1774969464357ic1jobm2vtd')}</Typography>
        <div className="grid grid-cols-4 gap-1">
          <button
            className={baseButtonClasses}
            title="Clear background"
            aria-label="Clear background"
            onClick={() => onSelectBackground(null)}
          >
            <Icon name="close-circle-unfilled" />
          </button>
          {BG_COLORS.map((color) => (
            <button
              key={color.value}
              className={tw(baseButtonClasses, {
                'border-2 border-grey-700': activeBackgroundColor === color.value,
              })}
              style={{ backgroundColor: color.value }}
              title={color.label}
              onClick={() => onSelectBackground(color.value)}
            ></button>
          ))}
        </div>
      </div>
    </div>
  )
}

export default ColorPicker
