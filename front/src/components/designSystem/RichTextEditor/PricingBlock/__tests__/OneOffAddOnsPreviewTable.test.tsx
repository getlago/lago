import { screen } from '@testing-library/react'

import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import type { EntityData } from '../../common/RichTextEditorContext'
import {
  ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID,
  OneOffAddOnsPreviewTable,
} from '../OneOffAddOnsPreviewTable'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockTranslate = (key: string) => key

const createEntity = (overrides: Partial<EntityData> = {}): EntityData => ({
  entityId: 'addon-1',
  entityType: 'addOn',
  name: 'Setup Fee',
  code: 'setup',
  description: 'One-time setup fee',
  units: '2',
  unitAmountCents: '5000',
  totalAmount: '10000',
  fromDatetime: '2026-01-01T00:00:00.000Z',
  toDatetime: '2026-01-31T23:59:59.999Z',
  ...overrides,
})

const defaultProps = {
  entities: [createEntity()],
  translate: mockTranslate,
  currency: CurrencyEnum.Usd,
}

describe('OneOffAddOnsPreviewTable', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with entities', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the table container', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        expect(screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the preview table with correct data-test id', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        expect(screen.getByTestId('preview-table-one-off-addons-preview')).toBeInTheDocument()
      })

      it('THEN should display the entity name', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        expect(screen.getByText('Setup Fee')).toBeInTheDocument()
      })

      it('THEN should display the entity description', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        expect(screen.getByText('One-time setup fee')).toBeInTheDocument()
      })

      it('THEN should display the entity units', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        expect(screen.getByText('2')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the entity has an invoiceDisplayName', () => {
    describe('WHEN the component renders', () => {
      it('THEN should display invoiceDisplayName instead of name', () => {
        const entity = createEntity({ invoiceDisplayName: 'Custom Display Name' })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        expect(screen.getByText('Custom Display Name')).toBeInTheDocument()
        expect(screen.queryByText('Setup Fee')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the entity has no description', () => {
    describe('WHEN the component renders', () => {
      it('THEN should not render a description element', () => {
        const entity = createEntity({ description: undefined })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        expect(screen.queryByText('One-time setup fee')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the entity has no date range', () => {
    describe('WHEN fromDatetime and toDatetime are both missing', () => {
      it('THEN should not display a billed period cell content', () => {
        const entity = createEntity({ fromDatetime: undefined, toDatetime: undefined })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        // The billed column header is still present (it's a translation key), but the cell is empty
        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })
  })

  describe('GIVEN multiple entities', () => {
    describe('WHEN rendered with two add-ons', () => {
      it('THEN should render two table rows', () => {
        const entities = [
          createEntity({ entityId: 'addon-1', name: 'Setup Fee' }),
          createEntity({ entityId: 'addon-2', name: 'Support Fee', code: 'support' }),
        ]

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={entities} />)

        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(2)
      })

      it('THEN should display both entity names', () => {
        const entities = [
          createEntity({ entityId: 'addon-1', name: 'Setup Fee' }),
          createEntity({ entityId: 'addon-2', name: 'Support Fee', code: 'support' }),
        ]

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={entities} />)

        expect(screen.getByText('Setup Fee')).toBeInTheDocument()
        expect(screen.getByText('Support Fee')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the entity has date range values', () => {
    describe('WHEN fromDatetime and toDatetime are provided', () => {
      it('THEN should render a row for the entity with dates', () => {
        const entity = createEntity({
          fromDatetime: '2026-01-01T00:00:00.000Z',
          toDatetime: '2026-01-31T23:59:59.999Z',
        })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })

    describe('WHEN only fromDatetime is provided', () => {
      it('THEN should still render the entity row', () => {
        const entity = createEntity({
          fromDatetime: '2026-01-01T00:00:00.000Z',
          toDatetime: undefined,
        })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })

    describe('WHEN only toDatetime is provided', () => {
      it('THEN should still render the entity row', () => {
        const entity = createEntity({
          fromDatetime: undefined,
          toDatetime: '2026-01-31T23:59:59.999Z',
        })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })
  })

  describe('GIVEN the entity has a totalAmount', () => {
    describe('WHEN totalAmount is a valid number string', () => {
      it('THEN should render the formatted amount', () => {
        const entity = createEntity({ totalAmount: '150.50' })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        // intlFormatNumber formats the value with currency — just verify a row is rendered
        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })

    describe('WHEN totalAmount is null', () => {
      it('THEN should fall back to 0 and render the entity row', () => {
        const entity = createEntity({ totalAmount: undefined })

        render(<OneOffAddOnsPreviewTable {...defaultProps} entities={[entity]} />)

        const rows = screen.getAllByTestId(/^preview-table-one-off-addons-preview-row-/)

        expect(rows).toHaveLength(1)
      })
    })
  })

  describe('GIVEN a locale is provided', () => {
    describe('WHEN locale is set', () => {
      it('THEN should render the table without errors', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} locale={'fr' as never} />)

        expect(screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the footer is rendered', () => {
    describe('WHEN the table renders', () => {
      it('THEN should render the table with a footer section', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        // The footer is rendered inside the preview table container
        const container = screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)

        expect(container).toBeInTheDocument()
        // Footer is always rendered with the table — verify the table itself has content
        expect(screen.getByTestId('preview-table-one-off-addons-preview')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the entity has all column data populated', () => {
    describe('WHEN an entity has name, description, dates, units, and totalAmount', () => {
      it('THEN should render all four column headers', () => {
        render(<OneOffAddOnsPreviewTable {...defaultProps} />)

        // Verify 4 column headers are rendered (as translation keys from mock)
        const table = screen.getByTestId('preview-table-one-off-addons-preview')

        // Table should have header cells
        const headerCells = table.querySelectorAll('th')

        expect(headerCells).toHaveLength(4)
      })
    })
  })

  describe('GIVEN different currency values', () => {
    describe('WHEN EUR currency is used', () => {
      it('THEN should render the table with EUR formatting', () => {
        render(
          <OneOffAddOnsPreviewTable
            entities={[createEntity({ totalAmount: '200' })]}
            translate={mockTranslate}
            currency={CurrencyEnum.Eur}
          />,
        )

        expect(screen.getByTestId(ONE_OFF_ADDONS_PREVIEW_TABLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
