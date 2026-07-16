import { act, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { Button } from '~/components/designSystem/Button'
import { render } from '~/test-utils'

import { Table } from '../Table/Table'

const data = [
  {
    id: '1',
    name: 'John Doe',
    age: 30,
  },
  {
    id: '2',
    name: 'Jane Doe',
    age: 25,
  },
  {
    id: '3',
    name: 'James Smith',
    age: 40,
  },
  {
    id: '4',
    name: 'Jane Smith',
    age: 35,
  },
]

async function prepare({ props }: { props?: Record<string, any> } = {}) {
  await act(() =>
    render(
      <Table
        name="test"
        data={data}
        columns={
          props?.columns || [
            {
              key: 'name' as const,
              title: 'Name',
              content: (row: any) => row.name,
            },
            {
              key: 'age' as const,
              title: 'Age',
              content: (row: any) => row.age,
            },
          ]
        }
        {...props}
      />,
    ),
  )
}

describe('Table', () => {
  it('renders some basic table', async () => {
    await prepare()

    // Header
    expect(screen.queryAllByRole('columnheader')).toHaveLength(2)
    expect(screen.queryAllByRole('columnheader')[0]).toHaveTextContent('Name')
    expect(screen.queryAllByRole('columnheader')[1]).toHaveTextContent('Age')

    // Body
    expect(screen.queryAllByRole('rowgroup')).toHaveLength(2)
    const bodyRows = within(screen.queryAllByRole('rowgroup')[1]).queryAllByRole('row')

    expect(bodyRows).toHaveLength(4)
    expect(within(bodyRows[0]).queryAllByRole('cell')).toHaveLength(2)
    expect(within(bodyRows[0]).queryAllByRole('cell')[0]).toHaveTextContent('John Doe')
    expect(within(bodyRows[0]).queryAllByRole('cell')[1]).toHaveTextContent('30')
  })

  it('renders with interaction', async () => {
    const onEdit = jest.fn()
    const onDelete = jest.fn()
    const onRow = jest.fn()

    await prepare({
      props: {
        onRowActionLink: (row: any) => onRow(row),
        actionColumn: () => [
          {
            title: 'Edit',
            onAction: (row: any) => onEdit(row),
          },
          {
            title: 'Delete',
            onAction: (row: any) => onDelete(row),
          },
        ],
      },
    })

    // Header
    expect(screen.queryAllByRole('columnheader')).toHaveLength(3)
    expect(screen.queryAllByRole('columnheader')[2]).not.toHaveValue()

    // Body
    expect(screen.queryAllByRole('rowgroup')).toHaveLength(2)
    const bodyRows = within(screen.queryAllByRole('rowgroup')[1]).queryAllByRole('row')

    expect(bodyRows).toHaveLength(4)
    expect(within(bodyRows[0]).queryAllByRole('cell')).toHaveLength(3)
    expect(within(bodyRows[0]).queryByTestId('open-action-button')).toBeInTheDocument()

    // Click on action menu
    await userEvent.click(
      within(bodyRows[0]).queryByTestId('open-action-button') as HTMLButtonElement,
    )

    // Check if action menu is visible
    expect(screen.getByRole('tooltip')).toBeInTheDocument()
    expect(within(screen.getByRole('tooltip')).queryAllByRole('button')).toHaveLength(2)
    expect(screen.getByRole('button', { name: 'Edit' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Delete' })).toBeInTheDocument()

    // Click on Edit
    await userEvent.click(screen.getByRole('button', { name: 'Edit' }))
    expect(onEdit).toHaveBeenNthCalledWith(1, data[0])

    // Click on row
    await userEvent.click(bodyRows[0])
    expect(onRow).toHaveBeenNthCalledWith(1, data[0])
    expect(onEdit).toHaveBeenCalledTimes(1)
  })

  it('renders with custom action element', async () => {
    const onClick = jest.fn()
    const onRow = jest.fn()

    await prepare({
      props: {
        actionColumn: (row: any) => <Button onClick={onClick(row)}>Click me</Button>,
        onRowActionLink: (row: any) => onRow(row),
      },
    })

    // Header
    expect(screen.queryAllByRole('columnheader')).toHaveLength(3)
    expect(screen.queryAllByRole('columnheader')[2]).not.toHaveValue()

    // On row action
    const bodyRows = within(screen.queryAllByRole('rowgroup')[1]).queryAllByRole('row')

    await userEvent.click(bodyRows[0])
    expect(onRow).toHaveBeenNthCalledWith(1, data[0])

    // On click action
    await userEvent.click(within(bodyRows[0]).getByText('Click me'))
    expect(onClick).toHaveBeenNthCalledWith(1, data[0])
    expect(onRow).toHaveBeenCalledTimes(1)
  })

  it('renders with loading state', async () => {
    await prepare({
      props: {
        isLoading: true,
        data: [],
      },
    })

    // Header
    expect(screen.queryAllByRole('columnheader')).toHaveLength(2)
    expect(screen.queryAllByRole('columnheader')[0]).toHaveTextContent('Name')
    expect(screen.queryAllByRole('columnheader')[1]).toHaveTextContent('Age')

    // Body
    expect(screen.queryAllByRole('rowgroup')).toHaveLength(2)
    const bodyRows = within(screen.queryAllByRole('rowgroup')[1]).queryAllByRole('row')

    expect(bodyRows).toHaveLength(3)
    expect(within(bodyRows[0]).queryAllByRole('cell')).toHaveLength(2)
  })

  it('renders with empty state', async () => {
    await prepare({
      props: {
        isLoading: false,
        data: [],
      },
    })

    expect(screen.getByText('empty.svg')).toBeInTheDocument()
  })

  it('renders with error state', async () => {
    await prepare({
      props: {
        hasError: true,
      },
    })

    expect(screen.getByText('error.svg')).toBeInTheDocument()
  })
})
