import { act, createRef, ReactNode } from 'react'

import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { ViewTypeEnum } from '../../../paymentMethodsInvoiceSettings/types'
import { PaymentSettingsDrawer, PaymentSettingsDrawerRef } from '../PaymentSettingsDrawer'

const mockOpen = jest.fn()
const mockClose = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key, locale: 'en' }),
}))

jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({ open: mockOpen, close: mockClose }),
}))

jest.mock('~/components/drawers/useFocusTrap', () => ({
  focusFirstInput: jest.fn(),
}))

const mockFieldsProps: { current: { error?: string } | null } = { current: null }

jest.mock('~/components/paymentMethodSelection/PaymentMethodFields', () => ({
  PaymentMethodFields: (props: { error?: string }) => {
    mockFieldsProps.current = props

    return <div data-test="pm-fields" />
  },
}))

describe('PaymentSettingsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockFieldsProps.current = null
  })

  const renderDrawer = (onSave = jest.fn()) => {
    const ref = createRef<PaymentSettingsDrawerRef>()

    render(
      <PaymentSettingsDrawer
        ref={ref}
        viewType={ViewTypeEnum.Subscription}
        externalCustomerId="ext_1"
        onSave={onSave}
      />,
    )

    return { ref, onSave }
  }

  it('renders nothing until opened', () => {
    const { container } = render(
      <PaymentSettingsDrawer
        viewType={ViewTypeEnum.Subscription}
        externalCustomerId="ext_1"
        onSave={jest.fn()}
      />,
    )

    expect(container.firstChild).toBeNull()
    expect(mockOpen).not.toHaveBeenCalled()
  })

  it('opens the drawer with the Payment settings title', () => {
    const { ref } = renderDrawer()

    act(() => {
      ref.current?.openDrawer({
        paymentMethod: { paymentMethodId: null, paymentMethodType: PaymentMethodTypeEnum.Provider },
      })
    })

    expect(mockOpen).toHaveBeenCalledTimes(1)
    expect(mockOpen).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'text_17828013737948943pe3k8nc' }),
    )
  })

  it('commits the seeded draft through onSave on submit, then closes', async () => {
    const { ref, onSave } = renderDrawer()

    const seeded = {
      paymentMethod: { paymentMethodId: 'pm_1', paymentMethodType: PaymentMethodTypeEnum.Provider },
    }

    act(() => {
      ref.current?.openDrawer(seeded)
    })

    const { form } = mockOpen.mock.calls[0][0] as { form: { submit: () => Promise<void> } }

    await act(async () => {
      await form.submit()
    })

    expect(onSave).toHaveBeenCalledWith(seeded)
    expect(mockClose).toHaveBeenCalled()
  })

  it('blocks submit and surfaces the error when "specific" is picked with no method', async () => {
    const { ref, onSave } = renderDrawer()

    act(() => {
      ref.current?.openDrawer({
        paymentMethod: {
          paymentMethodId: undefined,
          paymentMethodType: PaymentMethodTypeEnum.Provider,
        },
      })
    })

    const opened = mockOpen.mock.calls[0][0] as {
      form: { submit: () => Promise<void> }
      children: ReactNode
    }

    // Mount the drawer content so the field error can surface on the inline
    // fields (drawer.open is mocked, so children isn't rendered otherwise).
    render(<>{opened.children}</>)

    await act(async () => {
      await opened.form.submit()
    })

    expect(onSave).not.toHaveBeenCalled()
    expect(mockClose).not.toHaveBeenCalled()
    expect(mockFieldsProps.current?.error).toBe('text_624ea7c29103fd010732ab7d')
  })
})
