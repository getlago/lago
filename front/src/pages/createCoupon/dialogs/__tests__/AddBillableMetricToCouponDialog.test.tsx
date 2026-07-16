import { renderHook, screen } from '@testing-library/react'
import { ReactElement } from 'react'

import {
  BillableMetricsForCouponsFragment,
  useGetBillableMetricsForCouponsLazyQuery,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  ADD_BILLABLE_METRIC_FORM_ID,
  useAddBillableMetricToCouponDialog,
} from '../AddBillableMetricToCouponDialog'

const mockFormDialogOpen = jest.fn().mockResolvedValue({ reason: 'close' })

jest.mock('~/components/dialogs/FormDialog', () => ({
  useFormDialog: () => ({
    open: mockFormDialogOpen,
    close: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockGetBillableMetrics = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetBillableMetricsForCouponsLazyQuery: jest
    .fn()
    .mockReturnValue([jest.fn(), { loading: false, data: undefined }]),
}))

const mockedUseGetBillableMetricsForCouponsLazyQuery =
  useGetBillableMetricsForCouponsLazyQuery as jest.Mock

const mockBillableMetric: BillableMetricsForCouponsFragment = {
  id: 'bm-1',
  name: 'API Calls',
  code: 'api_calls',
}

const mockBillableMetric2: BillableMetricsForCouponsFragment = {
  id: 'bm-2',
  name: 'Storage',
  code: 'storage',
}

const mockBillableMetricsData = {
  billableMetrics: {
    collection: [mockBillableMetric, mockBillableMetric2],
  },
}

const openDialogAndGetChildren = () => {
  const onSubmit = jest.fn()

  const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

  result.current.openAddBillableMetricToCouponDialog({
    onSubmit,
    attachedBillableMetricsIds: ['bm-2'],
  })

  return mockFormDialogOpen.mock.calls[0][0].children as ReactElement
}

describe('useAddBillableMetricToCouponDialog', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN rendered', () => {
      it('THEN should return openAddBillableMetricToCouponDialog function', () => {
        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        expect(result.current.openAddBillableMetricToCouponDialog).toBeDefined()
        expect(typeof result.current.openAddBillableMetricToCouponDialog).toBe('function')
      })
    })
  })

  describe('GIVEN openAddBillableMetricToCouponDialog is called', () => {
    describe('WHEN opening the dialog', () => {
      it('THEN should call formDialog.open with correct props', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({
          onSubmit,
          attachedBillableMetricsIds: ['bm-existing'],
        })

        expect(mockFormDialogOpen).toHaveBeenCalledTimes(1)
        expect(mockFormDialogOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            description: expect.any(String),
            closeOnError: false,
            children: expect.anything(),
            mainAction: expect.anything(),
            form: expect.objectContaining({
              id: ADD_BILLABLE_METRIC_FORM_ID,
              submit: expect.any(Function),
            }),
          }),
        )
      })
    })

    describe('WHEN form submit is called without selecting a billable metric', () => {
      it('THEN should throw an error', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({ onSubmit })

        const { form } = mockFormDialogOpen.mock.calls[0][0]

        expect(() => form.submit()).toThrow('No billable metric selected')
        expect(onSubmit).not.toHaveBeenCalled()
      })
    })

    describe('WHEN form submit is called after selecting a billable metric', () => {
      it('THEN should call onSubmit with the selected billable metric', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({ onSubmit })

        const { children } = mockFormDialogOpen.mock.calls[0][0]

        // Simulate selection via the onSelect prop passed to AddBillableMetricContent
        const onSelect = children.props.onSelect

        onSelect(mockBillableMetric)

        const { form } = mockFormDialogOpen.mock.calls[0][0]

        form.submit()

        expect(onSubmit).toHaveBeenCalledTimes(1)
        expect(onSubmit).toHaveBeenCalledWith(mockBillableMetric)
      })
    })

    describe('WHEN the dialog is opened again after a previous selection', () => {
      it('THEN should reset the selected billable metric ref', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        // First open + select
        result.current.openAddBillableMetricToCouponDialog({ onSubmit })
        const firstChildren = mockFormDialogOpen.mock.calls[0][0].children

        firstChildren.props.onSelect(mockBillableMetric)

        // Second open (should reset)
        result.current.openAddBillableMetricToCouponDialog({ onSubmit })
        const secondForm = mockFormDialogOpen.mock.calls[1][0].form

        expect(() => secondForm.submit()).toThrow('No billable metric selected')
      })
    })

    describe('WHEN onSelect is called with undefined', () => {
      it('THEN should clear the selected billable metric', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({ onSubmit })

        const { children, form } = mockFormDialogOpen.mock.calls[0][0]

        // Select then deselect
        children.props.onSelect(mockBillableMetric)
        children.props.onSelect(undefined)

        expect(() => form.submit()).toThrow('No billable metric selected')
      })
    })

    describe('WHEN attachedBillableMetricsIds are provided', () => {
      it('THEN should pass them to the children component', () => {
        const onSubmit = jest.fn()
        const attachedIds = ['bm-1', 'bm-2']

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({
          onSubmit,
          attachedBillableMetricsIds: attachedIds,
        })

        const { children } = mockFormDialogOpen.mock.calls[0][0]

        expect(children.props.attachedBillableMetricsIds).toEqual(attachedIds)
      })
    })

    describe('WHEN no attachedBillableMetricsIds are provided', () => {
      it('THEN should pass undefined to the children component', () => {
        const onSubmit = jest.fn()

        const { result } = renderHook(() => useAddBillableMetricToCouponDialog())

        result.current.openAddBillableMetricToCouponDialog({ onSubmit })

        const { children } = mockFormDialogOpen.mock.calls[0][0]

        expect(children.props.attachedBillableMetricsIds).toBeUndefined()
      })
    })
  })

  describe('GIVEN AddBillableMetricContent is rendered', () => {
    describe('WHEN data is loading', () => {
      it('THEN should render the combobox in loading state', () => {
        mockedUseGetBillableMetricsForCouponsLazyQuery.mockReturnValue([
          mockGetBillableMetrics,
          { loading: true, data: undefined },
        ])

        const children = openDialogAndGetChildren()

        render(children)

        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    describe('WHEN data is loaded', () => {
      it('THEN should call getBillableMetrics on mount', () => {
        mockedUseGetBillableMetricsForCouponsLazyQuery.mockReturnValue([
          mockGetBillableMetrics,
          { loading: false, data: mockBillableMetricsData },
        ])

        const children = openDialogAndGetChildren()

        render(children)

        expect(mockGetBillableMetrics).toHaveBeenCalled()
      })

      it('THEN should render the warning alert', () => {
        mockedUseGetBillableMetricsForCouponsLazyQuery.mockReturnValue([
          mockGetBillableMetrics,
          { loading: false, data: mockBillableMetricsData },
        ])

        const children = openDialogAndGetChildren()

        render(children)

        expect(screen.getByTestId('alert-type-warning')).toBeInTheDocument()
      })
    })

    describe('WHEN no data is returned', () => {
      it('THEN should render the combobox with empty data', () => {
        mockedUseGetBillableMetricsForCouponsLazyQuery.mockReturnValue([
          mockGetBillableMetrics,
          { loading: false, data: undefined },
        ])

        const children = openDialogAndGetChildren()

        render(children)

        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    describe('WHEN the dialog is opened', () => {
      it('THEN should pass onSelect prop to the children component', () => {
        mockedUseGetBillableMetricsForCouponsLazyQuery.mockReturnValue([
          mockGetBillableMetrics,
          { loading: false, data: mockBillableMetricsData },
        ])

        const children = openDialogAndGetChildren()

        expect(children.props.onSelect).toBeDefined()
        expect(typeof children.props.onSelect).toBe('function')
      })
    })
  })
})
