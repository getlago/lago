import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { SelectedPaymentMethod } from '../../../paymentMethodSelection/types'
import { PaymentSettingsSection } from '../PaymentSettingsSection'

const mockSelector: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockDrawer: jest.Mock<null, [Record<string, unknown>]> = jest.fn()

jest.mock('~/components/designSystem/Selector', () => ({
  Selector: (props: Record<string, unknown>) => {
    mockSelector(props)

    return null
  },
}))

jest.mock('../PaymentSettingsDrawer', () => ({
  PaymentSettingsDrawer: function MockPaymentSettingsDrawer(props: Record<string, unknown>) {
    mockDrawer(props)

    return null
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
  useStore: (store: { state: unknown }, selector: (state: unknown) => unknown) =>
    selector(store.state),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(),
  withForm: jest.fn(
    ({
      render: RenderComponent,
      props: defaultProps,
    }: {
      render: React.FC<Record<string, unknown>>
      defaultValues: Record<string, unknown>
      props: Record<string, unknown>
    }) => {
      const WithFormWrapper = (receivedProps: Record<string, unknown>) => (
        <RenderComponent {...defaultProps} {...receivedProps} />
      )

      WithFormWrapper.displayName = 'WithFormWrapper'

      return WithFormWrapper
    },
  ),
}))

const renderSection = (paymentMethod?: SelectedPaymentMethod, externalCustomerId = 'ext-1') => {
  const state = { values: { paymentMethod } }
  const form = { setFieldValue: jest.fn(), state, store: { state } }

  render(
    // @ts-expect-error - mock form shape
    <PaymentSettingsSection form={form} externalCustomerId={externalCustomerId} />,
  )

  return { form }
}

const lastSubtitle = () =>
  (mockSelector.mock.calls.at(-1)?.[0] as { subtitle?: string } | undefined)?.subtitle

describe('PaymentSettingsSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('summarises the fallback (customer default) behaviour', () => {
    renderSection(undefined)

    expect(lastSubtitle()).toBe('text_1782801373795rfpcgchgkv2')
  })

  it('summarises a specific payment method', () => {
    renderSection({ paymentMethodId: 'pm_1', paymentMethodType: PaymentMethodTypeEnum.Provider })

    expect(lastSubtitle()).toBe('text_1782801373795gxafl6ekcte')
  })

  it('summarises the manual behaviour', () => {
    renderSection({ paymentMethodId: null, paymentMethodType: PaymentMethodTypeEnum.Manual })

    expect(lastSubtitle()).toBe('text_1782801373795pwkwintj6s8')
  })

  it('forwards the external customer id to the drawer', () => {
    renderSection(undefined, 'ext-42')

    expect(mockDrawer).toHaveBeenCalledWith(
      expect.objectContaining({ externalCustomerId: 'ext-42' }),
    )
  })

  it('wires the drawer onSave back to the paymentMethod form field', () => {
    const { form } = renderSection(undefined)

    const { onSave } = mockDrawer.mock.calls.at(-1)?.[0] as {
      onSave: (v: { paymentMethod: SelectedPaymentMethod }) => void
    }

    const next: SelectedPaymentMethod = {
      paymentMethodId: 'pm_9',
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }

    onSave({ paymentMethod: next })

    expect(form.setFieldValue).toHaveBeenCalledWith('paymentMethod', next)
  })
})
