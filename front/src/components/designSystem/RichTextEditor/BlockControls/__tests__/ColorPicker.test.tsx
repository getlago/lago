import { cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import tailwindConfig from 'lago-configs/tailwind'
import resolveConfig from 'tailwindcss/resolveConfig'

import { render } from '~/test-utils'

import ColorPicker from '../ColorPicker'

const fullConfig = resolveConfig(tailwindConfig)
const themeColors = fullConfig.theme.colors
const red100 = (themeColors.red as Record<number, string>)[100]
const red600 = (themeColors.red as Record<number, string>)[600]
const blue600 = (themeColors.blue as Record<number, string>)[600]

const defaultProps = {
  activeBackgroundColor: null,
  activeTextColor: null,
  onSelectBackground: jest.fn(),
  onSelectText: jest.fn(),
}

describe('ColorPicker', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the unified color picker', () => {
    describe('WHEN rendered', () => {
      it('THEN should display both text and background sections', () => {
        render(<ColorPicker {...defaultProps} />)

        // Text color section comes first, background second
        // Labels are translated, so we check for noteHl typography elements
        const sections = screen.getAllByTestId('noteHl')

        expect(sections).toHaveLength(2)
      })

      it('THEN should display 12 color swatches plus 2 clear buttons', () => {
        render(<ColorPicker {...defaultProps} />)

        const buttons = screen.getAllByRole('button')

        // 1 clear text + 6 text colors + 1 clear bg + 6 bg colors = 14
        expect(buttons).toHaveLength(14)
      })
    })

    describe('WHEN clicking a text color swatch', () => {
      it('THEN should call onSelectText with the color value', async () => {
        const user = userEvent.setup()
        const onSelectText = jest.fn()

        render(<ColorPicker {...defaultProps} onSelectText={onSelectText} />)

        // Text section is first — "Red" buttons: first is text, second is bg
        const redButtons = screen.getAllByTitle('Red')

        await user.click(redButtons[0])

        expect(onSelectText).toHaveBeenCalledWith(red600)
      })
    })

    describe('WHEN clicking the text clear button', () => {
      it('THEN should call onSelectText with null', async () => {
        const user = userEvent.setup()
        const onSelectText = jest.fn()

        render(
          <ColorPicker {...defaultProps} activeTextColor={blue600} onSelectText={onSelectText} />,
        )

        await user.click(screen.getByTitle('Clear text color'))

        expect(onSelectText).toHaveBeenCalledWith(null)
      })
    })

    describe('WHEN clicking a background color swatch', () => {
      it('THEN should call onSelectBackground with the color value', async () => {
        const user = userEvent.setup()
        const onSelectBackground = jest.fn()

        render(<ColorPicker {...defaultProps} onSelectBackground={onSelectBackground} />)

        // Background section is second — "Red" buttons: first is text, second is bg
        const redButtons = screen.getAllByTitle('Red')

        await user.click(redButtons[1])

        expect(onSelectBackground).toHaveBeenCalledWith(red100)
      })
    })

    describe('WHEN clicking the background clear button', () => {
      it('THEN should call onSelectBackground with null', async () => {
        const user = userEvent.setup()
        const onSelectBackground = jest.fn()

        render(
          <ColorPicker
            {...defaultProps}
            activeBackgroundColor={red100}
            onSelectBackground={onSelectBackground}
          />,
        )

        await user.click(screen.getByTitle('Clear background'))

        expect(onSelectBackground).toHaveBeenCalledWith(null)
      })
    })

    describe('WHEN a text color is active', () => {
      it('THEN should highlight the active text swatch with a thicker border', () => {
        render(<ColorPicker {...defaultProps} activeTextColor={blue600} />)

        // Text section is first — "Blue" buttons: first is text, second is bg
        const blueButtons = screen.getAllByTitle('Blue')
        const textSwatch = blueButtons[0]

        expect(textSwatch.className).toContain('border-2')
      })
    })

    describe('WHEN a background color is active', () => {
      it('THEN should highlight the active background swatch with a thicker border', () => {
        render(<ColorPicker {...defaultProps} activeBackgroundColor={red100} />)

        // Background section is second — "Red" buttons: first is text, second is bg
        const redButtons = screen.getAllByTitle('Red')
        const bgSwatch = redButtons[1]

        expect(bgSwatch.className).toContain('border-2')
      })
    })
  })
})
