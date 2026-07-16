import { act, fireEvent, render, renderHook, screen } from '@testing-library/react'
import { ReactNode } from 'react'

import { SubscriptionInformationSectionFragment } from '~/generated/graphql'

import { useSubscriptionInformationDrawer } from '../useSubscriptionInformationDrawer'

type CapturedDrawerArgs = {
  title?: ReactNode
  children?: ReactNode
  mainAction?: ReactNode
  form?: { id: string; submit: () => void }
  closeOnSubmitSuccess?: boolean
}

const mockOpen = jest.fn<void, [CapturedDrawerArgs]>()
const mockClose = jest.fn()
const mockHandleSubmit = jest.fn()
const mockResetForm = jest.fn()

// Mock the NiceModal-backed drawer hook so Jest never loads the drawer stack
// (drawerStack.ts uses import.meta and crashes Jest) and we can capture the
// args the hook passes to `open`.
jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({ open: mockOpen, close: mockClose }),
}))

jest.mock('~/hooks/customer/useUpdateSubscriptionInformation', () => ({
  useUpdateSubscriptionInformation: () => ({
    form: {
      handleSubmit: mockHandleSubmit,
      AppForm: ({ children }: { children: ReactNode }) => <>{children}</>,
      SubmitButton: ({ children, dataTest }: { children: ReactNode; dataTest?: string }) => (
        <button type="submit" data-test={dataTest}>
          {children}
        </button>
      ),
    },
    resetForm: mockResetForm,
  }),
}))

// Stub the form section: surface the name toggle so we can assert the drawer
// content owns reactive state (the toggle worked only once moved off the outer
// drawer, whose `children` are captured once on open).
jest.mock('~/components/subscriptions/form/SubscriptionInformationFormSection', () => ({
  SubscriptionInformationFormSection: ({
    shouldDisplaySubscriptionName,
    setShouldDisplaySubscriptionName,
  }: {
    shouldDisplaySubscriptionName: boolean
    setShouldDisplaySubscriptionName: (value: boolean) => void
  }) => {
    const React = jest.requireActual('react')

    return React.createElement(
      'div',
      null,
      shouldDisplaySubscriptionName ? 'name-shown' : 'name-hidden',
      React.createElement(
        'button',
        { onClick: () => setShouldDisplaySubscriptionName(true) },
        'add name',
      ),
    )
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const subscription = {
  id: 'sub-1',
  externalId: '',
  name: '',
  customer: { id: 'cust-1', applicableTimezone: null },
  plan: { id: 'plan-1', interval: null },
} as unknown as SubscriptionInformationSectionFragment

describe('useSubscriptionInformationDrawer', () => {
  beforeEach(() => {
    mockOpen.mockClear()
    mockClose.mockClear()
    mockHandleSubmit.mockClear()
    mockResetForm.mockClear()
  })

  it('opens the drawer with the edit title, form id and content', () => {
    const { result } = renderHook(() => useSubscriptionInformationDrawer(subscription))

    act(() => result.current.openDrawer())

    expect(mockResetForm).toHaveBeenCalledTimes(1)
    expect(mockOpen).toHaveBeenCalledTimes(1)

    const openArgs = mockOpen.mock.calls[0][0]

    expect(openArgs.title).toBe('text_62d7f6178ec94cd09370e63c')
    expect(openArgs.form?.id).toBe('subscription-information-drawer-form')
    expect(typeof openArgs.form?.submit).toBe('function')
    expect(openArgs.children).toBeDefined()
  })

  it('renders a submit button and submits through the drawer form handler', () => {
    const { result } = renderHook(() => useSubscriptionInformationDrawer(subscription))

    act(() => result.current.openDrawer())
    const openArgs = mockOpen.mock.calls[0][0]

    // The save action is a type="submit" button; it triggers the drawer form,
    // it does not wire its own onClick handler.
    render(<>{openArgs.mainAction}</>)
    expect(screen.getByRole('button', { name: 'text_17295436903260tlyb1gp1i7' })).toHaveAttribute(
      'type',
      'submit',
    )

    // The drawer form's submit handler drives the tanstack submission.
    openArgs.form?.submit()
    expect(mockHandleSubmit).toHaveBeenCalledTimes(1)
  })

  it('keeps close ownership in the drawer so a failed save leaves it open', () => {
    const { result } = renderHook(() => useSubscriptionInformationDrawer(subscription))

    act(() => result.current.openDrawer())
    const openArgs = mockOpen.mock.calls[0][0]

    expect(openArgs.closeOnSubmitSuccess).toBe(false)
  })

  it('reveals the subscription name field when its add button is clicked (state lives in the body)', () => {
    const { result } = renderHook(() => useSubscriptionInformationDrawer(subscription))

    act(() => result.current.openDrawer())
    const openArgs = mockOpen.mock.calls[0][0]

    render(<>{openArgs.children}</>)

    expect(screen.getByText('name-hidden')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: 'add name' }))

    expect(screen.getByText('name-shown')).toBeInTheDocument()
  })
})
