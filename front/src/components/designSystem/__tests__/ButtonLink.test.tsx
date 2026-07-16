import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { ButtonLink, ButtonLinkBaseProps } from '../ButtonLink'

async function prepare(
  {
    children,
    props,
    type,
    to,
  }: {
    children?: React.ReactNode
    props?: Record<string, any>
    type: ButtonLinkBaseProps['type']
    to: string
  } = { type: 'button', to: '/' },
) {
  await act(() =>
    render(
      <ButtonLink
        title={props?.title}
        type={type}
        to={to}
        onClick={props?.onClick}
        disabled={props?.disabled}
        buttonProps={props?.buttonProps}
      >
        {children}
      </ButtonLink>,
    ),
  )
}

describe('ButtonLink', () => {
  afterEach(cleanup)

  describe('when type is button', () => {
    it('renders with some basic children', async () => {
      await prepare({ children: <div>hello button</div>, type: 'button', to: '/' })

      expect(screen.queryByTestId('button-link-button')).toHaveTextContent('hello button')
    })

    it('renders with icons', async () => {
      await prepare({
        type: 'button',
        to: '/',
        props: {
          buttonProps: {
            icon: 'processing',
            startIcon: 'pen',
            endIcon: 'trash',
          },
        },
      })

      expect(screen.queryByTestId('button-link-button')).toBeInTheDocument()
      expect(screen.queryByTestId('processing/medium')).toBeInTheDocument()
      expect(screen.queryByTestId('pen/medium')).toBeInTheDocument()
      expect(screen.queryByTestId('trash/medium')).toBeInTheDocument()
    })

    it('should trigger the confirm action on click', async () => {
      const onContinueMock = jest.fn()

      await prepare({ type: 'button', to: '/', props: { onClick: onContinueMock } })

      expect(onContinueMock).not.toHaveBeenCalled()

      await userEvent.click(screen.queryByTestId('button-link-button') as HTMLElement)

      expect(onContinueMock).toHaveBeenCalled()
    })

    it('should not trigger the confirm action on click if button is disabled', async () => {
      const onContinueMock = jest.fn()

      await prepare({
        type: 'button',
        to: '/',
        props: { onClick: onContinueMock, disabled: true, title: 'title' },
      })

      expect(onContinueMock).not.toHaveBeenCalled()
      expect(screen.queryByTestId('button-link-button')).toBeDisabled()
      expect(screen.queryByTestId('tab-internal-button-link-title')).toHaveClass(
        'pointer-events-none',
      )
    })

    it('should be wrapped by a link with correct path', async () => {
      await prepare({
        type: 'button',
        to: '/this-is-my-route',
        props: { title: 'title' },
      })

      expect(screen.queryByTestId('tab-internal-button-link-title')).toHaveAttribute(
        'href',
        '/this-is-my-route',
      )
    })
  })
})
