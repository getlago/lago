import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionPaymentSection } from '../SubscriptionPaymentSection'

const mockSectionHeader: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockPaymentMethodDetails: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockDrawer: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockSavePayment = jest.fn()

jest.mock('~/components/plans/details-v2/shared/SectionHeader', () => ({
  SectionHeader: (props: Record<string, unknown>) => {
    mockSectionHeader(props)

    return null
  },
}))

jest.mock('~/components/subscriptions/SubscriptionPaymentMethodDetails', () => ({
  SubscriptionPaymentMethodDetails: (props: Record<string, unknown>) => {
    mockPaymentMethodDetails(props)

    return null
  },
}))

jest.mock('~/components/subscriptions/form/PaymentSettingsDrawer', () => ({
  PaymentSettingsDrawer: (props: Record<string, unknown>) => {
    mockDrawer(props)

    return null
  },
}))

jest.mock('~/hooks/customer/useUpdateSubscriptionSettings', () => ({
  useUpdateSubscriptionSettings: () => ({ savePayment: mockSavePayment, saveInvoicing: jest.fn() }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: () => true }),
}))

const subscription = {
  id: 'sub_1',
  paymentMethodType: PaymentMethodTypeEnum.Provider,
  paymentMethod: { id: 'pm_1' },
  customer: { id: 'cust_1', externalId: 'ext_1' },
}

const renderSection = () => render(<SubscriptionPaymentSection subscription={subscription} />)

describe('SubscriptionPaymentSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders the payment section header, display and drawer', () => {
    renderSection()

    expect(mockSectionHeader).toHaveBeenCalledWith(
      expect.objectContaining({
        title: 'text_1782825858647rr5zp42t63m',
        description: 'text_1782825858647ro8ahgg7uys',
      }),
    )
    expect(mockPaymentMethodDetails).toHaveBeenCalledWith(
      expect.objectContaining({
        selectedPaymentMethod: {
          paymentMethodType: PaymentMethodTypeEnum.Provider,
          paymentMethodId: 'pm_1',
        },
        externalCustomerId: 'ext_1',
      }),
    )
    expect(mockDrawer).toHaveBeenCalledWith(
      expect.objectContaining({ onSave: mockSavePayment, externalCustomerId: 'ext_1' }),
    )
  })
})
