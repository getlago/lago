import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { Button } from '../Button'

async function prepare({
  children,
  props,
}: { children?: React.ReactNode; props?: Record<string, any> } = {}) {
  await act(() =>
    render(
      <Button
        icon={props?.icon}
        disabled={props?.disabled}
        startIcon={props?.startIcon}
        endIcon={props?.endIcon}
        onClick={props?.onClick}
      >
        {children}
      </Button>,
    ),
  )
}

describe('Button', () => {
  afterEach(cleanup)

  it('renders with some basic children', async () => {
    await prepare({ children: <div>hello button</div> })

    expect(screen.queryByTestId('button')).toHaveTextContent('hello button')
  })

  it('renders with icons', async () => {
    await prepare({
      props: {
        icon: 'processing',
        startIcon: 'pen',
        endIcon: 'trash',
      },
    })

    expect(screen.queryByTestId('button')).toBeInTheDocument()
    expect(screen.queryByTestId('processing/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('pen/medium')).toBeInTheDocument()
    expect(screen.queryByTestId('trash/medium')).toBeInTheDocument()
  })

  it('should trigger the confirm action on click', async () => {
    const onContinueMock = jest.fn()

    await prepare({ props: { onClick: onContinueMock } })

    expect(onContinueMock).not.toHaveBeenCalled()

    await waitFor(() => userEvent.click(screen.queryByTestId('button') as HTMLElement))

    expect(onContinueMock).toHaveBeenCalled()
  })

  it('should not trigger the confirm action on click if button is disabled', async () => {
    const onContinueMock = jest.fn()

    await prepare({ props: { onClick: onContinueMock, disabled: true } })

    expect(onContinueMock).not.toHaveBeenCalled()
    expect(screen.queryByTestId('button')).toBeDisabled()
  })
})
