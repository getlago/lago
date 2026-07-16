import { screen } from '@testing-library/react'
import { ReactNode } from 'react'

import { render } from '~/test-utils'

import { PreviewTable, type PreviewTableColumn } from '../PreviewTable'

type TestItem = {
  id: string
  name: string
  value: number
}

const testData: TestItem[] = [
  { id: '1', name: 'Item One', value: 100 },
  { id: '2', name: 'Item Two', value: 200 },
]

const testColumns: PreviewTableColumn<TestItem>[] = [
  {
    key: 'name',
    title: 'Name',
    maxSpace: true,
    content: (item) => <span>{item.name}</span>,
  },
  {
    key: 'value',
    title: 'Value',
    textAlign: 'right',
    content: (item) => <span>{item.value}</span>,
  },
]

const defaultProps = {
  name: 'test-table',
  data: testData,
  columns: testColumns,
}

describe('PreviewTable', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state with data', () => {
      it('THEN should render the table with correct data-test id', () => {
        render(<PreviewTable {...defaultProps} />)

        expect(screen.getByTestId('preview-table-test-table')).toBeInTheDocument()
      })

      it('THEN should render column headers', () => {
        render(<PreviewTable {...defaultProps} />)

        expect(screen.getByText('Name')).toBeInTheDocument()
        expect(screen.getByText('Value')).toBeInTheDocument()
      })

      it('THEN should render data rows', () => {
        render(<PreviewTable {...defaultProps} />)

        expect(screen.getByText('Item One')).toBeInTheDocument()
        expect(screen.getByText('Item Two')).toBeInTheDocument()
      })

      it('THEN should render the correct number of rows', () => {
        render(<PreviewTable {...defaultProps} />)

        const rows = screen.getAllByTestId(/^preview-table-test-table-row-/)

        expect(rows).toHaveLength(2)
      })

      it.each([
        ['first row', 'preview-table-test-table-row-0'],
        ['second row', 'preview-table-test-table-row-1'],
      ])('THEN should render data-test id for %s', (_, testId) => {
        render(<PreviewTable {...defaultProps} />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the table has no data', () => {
    describe('WHEN data array is empty', () => {
      it('THEN should still render the table with headers', () => {
        render(<PreviewTable {...defaultProps} data={[]} />)

        expect(screen.getByTestId('preview-table-test-table')).toBeInTheDocument()
        expect(screen.getByText('Name')).toBeInTheDocument()
        expect(screen.getByText('Value')).toBeInTheDocument()
      })

      it('THEN should not render any data rows', () => {
        render(<PreviewTable {...defaultProps} data={[]} />)

        expect(screen.queryByTestId('preview-table-test-table-row-0')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the table has a footer', () => {
    describe('WHEN footer prop is provided', () => {
      it('THEN should render the footer content', () => {
        const footer: ReactNode = <div data-test="table-footer">Footer content</div>

        render(<PreviewTable {...defaultProps} footer={footer} />)

        expect(screen.getByTestId('table-footer')).toBeInTheDocument()
        expect(screen.getByText('Footer content')).toBeInTheDocument()
      })
    })

    describe('WHEN footer prop is not provided', () => {
      it('THEN should not render footer content', () => {
        render(<PreviewTable {...defaultProps} />)

        expect(screen.queryByTestId('table-footer')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN columns with minWidth', () => {
    describe('WHEN a column has minWidth set', () => {
      it('THEN should render the table without errors', () => {
        const columnsWithMinWidth: PreviewTableColumn<TestItem>[] = [
          { ...testColumns[0] },
          { ...testColumns[1], minWidth: 200 },
        ]

        render(<PreviewTable {...defaultProps} columns={columnsWithMinWidth} />)

        expect(screen.getByTestId('preview-table-test-table')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a containerClassName is provided', () => {
    describe('WHEN the table renders', () => {
      it('THEN should render the table with the container', () => {
        render(<PreviewTable {...defaultProps} containerClassName="custom-class" />)

        expect(screen.getByTestId('preview-table-test-table')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN columns with ReactNode titles', () => {
    describe('WHEN a column title is a ReactNode', () => {
      it('THEN should render the ReactNode title', () => {
        const columnsWithNodeTitle: PreviewTableColumn<TestItem>[] = [
          {
            key: 'name',
            title: <span data-test="custom-title">Custom Title</span>,
            content: (item) => <span>{item.name}</span>,
          },
        ]

        render(<PreviewTable {...defaultProps} columns={columnsWithNodeTitle} />)

        expect(screen.getByTestId('custom-title')).toBeInTheDocument()
        expect(screen.getByText('Custom Title')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple maxSpace columns', () => {
    describe('WHEN two columns have maxSpace enabled', () => {
      it('THEN should render both columns without errors', () => {
        const columnsWithTwoMaxSpace: PreviewTableColumn<TestItem>[] = [
          {
            key: 'name',
            title: 'Name',
            maxSpace: true,
            content: (item) => <span>{item.name}</span>,
          },
          {
            key: 'value',
            title: 'Value',
            maxSpace: true,
            content: (item) => <span>{item.value}</span>,
          },
        ]

        render(<PreviewTable {...defaultProps} columns={columnsWithTwoMaxSpace} />)

        expect(screen.getByText('Item One')).toBeInTheDocument()
        expect(screen.getByText('Item Two')).toBeInTheDocument()
      })
    })
  })
})
