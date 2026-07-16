import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  CouponExpiration,
  CouponFrequency,
  CouponTypeEnum,
  CurrencyEnum,
} from '~/generated/graphql'
// Import after mocks
import { useCreateEditCoupon } from '~/hooks/useCreateEditCoupon'
import { render, testMockNavigateFn } from '~/test-utils'

import CreateCoupon, {
  COUPON_AMOUNT_INPUT_TEST_ID,
  COUPON_DESCRIPTION_INPUT_TEST_ID,
  COUPON_EXPIRATION_SECTION_TEST_ID,
  COUPON_LIMIT_ERROR_TEST_ID,
  COUPONS_FORM_ID,
} from '../CreateCoupon'

const getNameInput = () => document.querySelector('input[name="name"]') as HTMLInputElement
const getCodeInput = () => document.querySelector('input[name="code"]') as HTMLInputElement

const mockOnSave = jest.fn()

// Must use "mock" prefix for variables referenced in jest.mock
const mockDefaultUseCreateEditCoupon = {
  isEdition: false,
  loading: false,
  coupon: undefined,
  errorCode: undefined,
  onSave: mockOnSave,
}

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      id: 'org-1',
      defaultCurrency: 'USD',
      timezone: 'UTC',
    },
  }),
}))

jest.mock('~/hooks/useCreateEditCoupon', () => ({
  useCreateEditCoupon: jest.fn(() => mockDefaultUseCreateEditCoupon),
}))

// Mock the dialog hooks - capture onSubmit/onAction callbacks
let capturedAddPlanOnSubmit: ((plan: any) => void) | undefined
let capturedAddBillableMetricOnSubmit: ((bm: any) => void) | undefined
let capturedWarningOnAction: (() => void) | undefined

jest.mock('~/pages/createCoupon/dialogs/AddPlanToCouponDialog', () => ({
  useAddPlanToCouponDialog: () => ({
    openAddPlanToCouponDialog: (params: any) => {
      capturedAddPlanOnSubmit = params.onSubmit
    },
  }),
}))

jest.mock('~/pages/createCoupon/dialogs/AddBillableMetricToCouponDialog', () => ({
  useAddBillableMetricToCouponDialog: () => ({
    openAddBillableMetricToCouponDialog: (params: any) => {
      capturedAddBillableMetricOnSubmit = params.onSubmit
    },
  }),
}))

jest.mock('~/components/coupons/CouponCodeSnippet', () => ({
  CouponCodeSnippet: jest.fn(() => <div data-test="coupon-code-snippet">Code Snippet</div>),
}))

jest.mock('~/components/dialogs/CentralizedDialog', () => ({
  useCentralizedDialog: () => ({
    open: (props: any) => {
      capturedWarningOnAction = props.onAction
      return Promise.resolve({ reason: 'close' })
    },
    close: jest.fn(),
  }),
}))

const mockedUseCreateEditCoupon = useCreateEditCoupon as jest.Mock

describe('CreateCoupon', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedAddPlanOnSubmit = undefined
    capturedAddBillableMetricOnSubmit = undefined
    capturedWarningOnAction = undefined
    mockedUseCreateEditCoupon.mockReturnValue(mockDefaultUseCreateEditCoupon)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered in create mode', () => {
    describe('WHEN the page loads', () => {
      it('THEN should display the form', () => {
        render(<CreateCoupon />)

        const form = document.getElementById(COUPONS_FORM_ID)

        expect(form).toBeInTheDocument()
      })

      it('THEN should display the code snippet component', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('coupon-code-snippet')).toBeInTheDocument()
      })

      it('THEN should display the name input field', () => {
        render(<CreateCoupon />)

        expect(getNameInput()).toBeInTheDocument()
      })

      it('THEN should display the code input field', () => {
        render(<CreateCoupon />)

        expect(getCodeInput()).toBeInTheDocument()
      })

      it('THEN should display the submit button', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })
    })

    describe('WHEN the page is loading', () => {
      it('THEN should not display form fields', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          loading: true,
        })

        render(<CreateCoupon />)

        // When loading, form input fields should not be displayed
        expect(getNameInput()).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component is rendered in edit mode', () => {
    const mockCoupon = {
      id: 'coupon-1',
      name: 'Test Coupon',
      code: 'TEST_COUPON',
      description: 'A test coupon',
      couponType: CouponTypeEnum.FixedAmount,
      amountCents: 1000,
      amountCurrency: CurrencyEnum.Usd,
      percentageRate: undefined,
      frequency: CouponFrequency.Once,
      frequencyDuration: undefined,
      reusable: true,
      expiration: CouponExpiration.NoExpiration,
      expirationAt: undefined,
      appliedCouponsCount: 0,
      plans: [],
      billableMetrics: [],
    }

    describe('WHEN editing an existing coupon', () => {
      it('THEN should populate the name field with coupon name', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: mockCoupon,
        })

        render(<CreateCoupon />)

        expect(getNameInput()).toHaveValue('Test Coupon')
      })

      it('THEN should populate the code field with coupon code', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: mockCoupon,
        })

        render(<CreateCoupon />)

        expect(getCodeInput()).toHaveValue('TEST_COUPON')
      })
    })

    describe('WHEN coupon has been applied', () => {
      it('THEN should disable the code field', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: {
            ...mockCoupon,
            appliedCouponsCount: 5,
          },
        })

        render(<CreateCoupon />)

        expect(getCodeInput()).toBeDisabled()
      })
    })
  })

  describe('GIVEN auto-generation of code from name', () => {
    describe('WHEN the user types a name and code has not been manually edited', () => {
      it('THEN should auto-generate the code from the name', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        await user.type(getNameInput(), 'My New Coupon')

        await waitFor(() => {
          expect(getCodeInput()).toHaveValue('my_new_coupon')
        })
      })
    })
  })

  describe('GIVEN editing a coupon with a description', () => {
    describe('WHEN the coupon has a description', () => {
      it('THEN should display the description field pre-populated', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: {
            id: 'coupon-1',
            name: 'Test Coupon',
            code: 'TEST_COUPON',
            description: 'A test coupon description',
            couponType: CouponTypeEnum.FixedAmount,
            amountCents: 1000,
            amountCurrency: CurrencyEnum.Usd,
            frequency: CouponFrequency.Once,
            reusable: true,
            expiration: CouponExpiration.NoExpiration,
            appliedCouponsCount: 0,
            plans: [],
            billableMetrics: [],
          },
        })

        render(<CreateCoupon />)

        const descriptionContainer = screen.getByTestId(COUPON_DESCRIPTION_INPUT_TEST_ID)
        const descriptionTextarea = descriptionContainer.querySelector('textarea')

        expect(descriptionTextarea).toBeInTheDocument()
        expect(descriptionTextarea).toHaveValue('A test coupon description')
      })
    })
  })

  describe('GIVEN form interactions', () => {
    describe('WHEN user clicks the add description button', () => {
      it('THEN should show the description textarea', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Initially, description textarea should not be visible
        expect(screen.queryByTestId(COUPON_DESCRIPTION_INPUT_TEST_ID)).not.toBeInTheDocument()

        // Click the add description button
        const addDescriptionButton = screen.getByTestId('show-description')

        await user.click(addDescriptionButton)

        // Now description textarea should be visible
        await waitFor(() => {
          const descriptionContainer = screen.getByTestId(COUPON_DESCRIPTION_INPUT_TEST_ID)
          const descriptionTextarea = descriptionContainer.querySelector('textarea')

          expect(descriptionTextarea).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN coupon type selection', () => {
    describe('WHEN FixedAmount is selected by default', () => {
      it('THEN should display amount input field', () => {
        render(<CreateCoupon />)

        const amountInputContainer = screen.getByTestId(COUPON_AMOUNT_INPUT_TEST_ID)
        const amountInput = amountInputContainer.querySelector('input')

        expect(amountInput).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the settings section', () => {
    describe('WHEN the settings section is displayed', () => {
      it('THEN should show the reusable checkbox', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('checkbox-isReusable')).toBeInTheDocument()
      })

      it('THEN should show the expiration checkbox', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('checkbox-hasLimit')).toBeInTheDocument()
      })

      it('THEN should show the plan/billable metric limit checkbox', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the submit button', () => {
    describe('WHEN in create mode', () => {
      it('THEN should display the submit button', () => {
        render(<CreateCoupon />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })
    })

    describe('WHEN in edit mode', () => {
      it('THEN should display the submit button', () => {
        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: {
            id: 'coupon-1',
            name: 'Test',
            code: 'TEST',
            couponType: CouponTypeEnum.FixedAmount,
            amountCents: 1000,
            amountCurrency: CurrencyEnum.Usd,
            frequency: CouponFrequency.Once,
            reusable: true,
            expiration: CouponExpiration.NoExpiration,
            appliedCouponsCount: 0,
            plans: [],
            billableMetrics: [],
          },
        })

        render(<CreateCoupon />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN attachPlanToCoupon', () => {
    describe('WHEN a plan is attached and no plans exist yet', () => {
      it('THEN should add the plan to the list', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Enable the plan/billable metric limit checkbox first
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Click the "add plan" button to trigger openAddPlanToCouponDialog
        const addPlanButton = screen.getByTestId('add-plan-limit')

        await user.click(addPlanButton)

        const mockPlan = { id: 'plan-1', name: 'Plan 1', code: 'plan_1' }

        await waitFor(() => {
          expect(capturedAddPlanOnSubmit).toBeDefined()
        })

        capturedAddPlanOnSubmit?.(mockPlan)

        await waitFor(() => {
          expect(screen.getByTestId('limited-plan-0')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN a plan is attached and plans already exist', () => {
      it('THEN should append the plan to the list', async () => {
        const user = userEvent.setup()

        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          coupon: {
            id: 'coupon-1',
            name: 'Test',
            code: 'TEST',
            couponType: CouponTypeEnum.FixedAmount,
            amountCents: 1000,
            amountCurrency: CurrencyEnum.Usd,
            frequency: CouponFrequency.Once,
            reusable: true,
            expiration: CouponExpiration.NoExpiration,
            appliedCouponsCount: 0,
            plans: [{ id: 'plan-existing', name: 'Existing Plan', code: 'existing_plan' }],
            billableMetrics: [],
          },
        })

        render(<CreateCoupon />)

        // Click the "add plan" button to trigger openAddPlanToCouponDialog
        const addPlanButton = screen.getByTestId('add-plan-limit')

        await user.click(addPlanButton)

        const newPlan = { id: 'plan-2', name: 'Plan 2', code: 'plan_2' }

        await waitFor(() => {
          expect(capturedAddPlanOnSubmit).toBeDefined()
        })

        capturedAddPlanOnSubmit?.(newPlan)

        await waitFor(() => {
          expect(screen.getByTestId('limited-plan-0')).toBeInTheDocument()
          expect(screen.getByTestId('limited-plan-1')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN attachBillableMetricToCoupon', () => {
    describe('WHEN a billable metric is attached and no billable metrics exist yet', () => {
      it('THEN should add the billable metric to the list', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Enable the plan/billable metric limit checkbox first
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Click the "add billable metric" button to trigger openAddBillableMetricToCouponDialog
        const addBMButton = screen.getByTestId('add-billable-metric-limit')

        await user.click(addBMButton)

        const mockBillableMetric = { id: 'bm-1', name: 'BM 1', code: 'bm_1' }

        await waitFor(() => {
          expect(capturedAddBillableMetricOnSubmit).toBeDefined()
        })

        capturedAddBillableMetricOnSubmit?.(mockBillableMetric)

        await waitFor(() => {
          expect(screen.getByTestId('limited-billable-metric-0')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN a billable metric is attached and billable metrics already exist', () => {
      it('THEN should append the billable metric to the list', async () => {
        const user = userEvent.setup()

        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          coupon: {
            id: 'coupon-1',
            name: 'Test',
            code: 'TEST',
            couponType: CouponTypeEnum.FixedAmount,
            amountCents: 1000,
            amountCurrency: CurrencyEnum.Usd,
            frequency: CouponFrequency.Once,
            reusable: true,
            expiration: CouponExpiration.NoExpiration,
            appliedCouponsCount: 0,
            plans: [],
            billableMetrics: [{ id: 'bm-existing', name: 'Existing BM', code: 'existing_bm' }],
          },
        })

        render(<CreateCoupon />)

        // Click the "add billable metric" button to trigger openAddBillableMetricToCouponDialog
        const addBMButton = screen.getByTestId('add-billable-metric-limit')

        await user.click(addBMButton)

        const newBM = { id: 'bm-2', name: 'BM 2', code: 'bm_2' }

        await waitFor(() => {
          expect(capturedAddBillableMetricOnSubmit).toBeDefined()
        })

        capturedAddBillableMetricOnSubmit?.(newBM)

        await waitFor(() => {
          expect(screen.getByTestId('limited-billable-metric-0')).toBeInTheDocument()
          expect(screen.getByTestId('limited-billable-metric-1')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN couponCloseRedirection', () => {
    describe('WHEN the coupon has an id (edit mode)', () => {
      it('THEN should navigate to the coupon details route via warning dialog', async () => {
        const user = userEvent.setup()

        mockedUseCreateEditCoupon.mockReturnValue({
          ...mockDefaultUseCreateEditCoupon,
          isEdition: true,
          coupon: {
            id: 'coupon-123',
            name: 'Test',
            code: 'TEST',
            couponType: CouponTypeEnum.FixedAmount,
            amountCents: 1000,
            amountCurrency: CurrencyEnum.Usd,
            frequency: CouponFrequency.Once,
            reusable: true,
            expiration: CouponExpiration.NoExpiration,
            appliedCouponsCount: 0,
            plans: [],
            billableMetrics: [],
          },
        })

        render(<CreateCoupon />)

        // Make the form dirty by typing in the name field
        await user.type(getNameInput(), 'changed')

        // Click the close button to trigger the warning dialog
        const closeButton = screen.getByTestId('close-create-coupon')

        await user.click(closeButton)

        // The warning dialog's onAction should have been captured
        await waitFor(() => {
          expect(capturedWarningOnAction).toBeDefined()
        })

        capturedWarningOnAction?.()

        expect(testMockNavigateFn).toHaveBeenCalledWith('/coupon/coupon-123/overview')
      })
    })

    describe('WHEN there is no coupon (create mode)', () => {
      it('THEN should navigate to the coupons list route via warning dialog', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Make the form dirty by typing in the name field
        await user.type(getNameInput(), 'changed')

        // Click the close button to trigger the warning dialog
        const closeButton = screen.getByTestId('close-create-coupon')

        await user.click(closeButton)

        await waitFor(() => {
          expect(capturedWarningOnAction).toBeDefined()
        })

        capturedWarningOnAction?.()

        expect(testMockNavigateFn).toHaveBeenCalledWith('/coupons')
      })
    })
  })

  describe('GIVEN COUPONS_FORM_ID export', () => {
    describe('WHEN importing the constant', () => {
      it('THEN should have the correct value', () => {
        expect(COUPONS_FORM_ID).toBe('coupon-form')
      })
    })
  })

  describe('GIVEN form submission', () => {
    describe('WHEN user fills required fields and submits the form', () => {
      it('THEN should call onSave with correct form data', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Fill in the name field
        await user.type(getNameInput(), 'My Test Coupon')

        // Fill in the code field (auto-generated from name, but let's set it explicitly)
        await user.clear(getCodeInput())
        await user.type(getCodeInput(), 'MY_TEST_COUPON')

        // Fill in the amount field
        const amountInputContainer = screen.getByTestId(COUPON_AMOUNT_INPUT_TEST_ID)
        const amountInput = amountInputContainer.querySelector('input') as HTMLInputElement

        await user.type(amountInput, '50')

        // Submit the form
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        // Verify onSave was called with the correct data
        await waitFor(() => {
          expect(mockOnSave).toHaveBeenCalledTimes(1)
          expect(mockOnSave).toHaveBeenCalledWith(
            expect.objectContaining({
              name: 'My Test Coupon',
              code: 'MY_TEST_COUPON',
              amountCents: '50',
              couponType: CouponTypeEnum.FixedAmount,
              frequency: CouponFrequency.Once,
              expiration: CouponExpiration.NoExpiration,
              reusable: true,
            }),
          )
        })
      })
    })

    describe('WHEN user submits with empty required fields', () => {
      it('THEN should NOT call onSave due to validation', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Submit the form without filling any fields
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        // Wait a bit to ensure async validation completes
        await waitFor(() => {
          expect(mockOnSave).not.toHaveBeenCalled()
        })
      })
    })
  })

  describe('GIVEN checkbox validation errors on submit', () => {
    describe('WHEN the expiration checkbox is checked but no date is selected', () => {
      it('THEN should show the expiration date error after submit', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the expiration checkbox
        const expirationCheckbox = screen.getByTestId('checkbox-hasLimit')

        await user.click(expirationCheckbox)

        // Expiration section should be visible but input should not have error state before submit
        const expirationSection = screen.getByTestId(COUPON_EXPIRATION_SECTION_TEST_ID)
        const dateInput = expirationSection.querySelector('input') as HTMLInputElement

        expect(dateInput).not.toHaveAttribute('aria-invalid', 'true')

        // Submit the form
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        // Date input should have error state after submit
        await waitFor(() => {
          expect(dateInput).toHaveAttribute('aria-invalid', 'true')
        })
      })
    })

    describe('WHEN the expiration checkbox is unchecked after submit', () => {
      it('THEN should hide the expiration date section', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the expiration checkbox
        const expirationCheckbox = screen.getByTestId('checkbox-hasLimit')

        await user.click(expirationCheckbox)

        // Submit the form to trigger errors
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        await waitFor(() => {
          const expirationSection = screen.getByTestId(COUPON_EXPIRATION_SECTION_TEST_ID)
          const dateInput = expirationSection.querySelector('input') as HTMLInputElement

          expect(dateInput).toHaveAttribute('aria-invalid', 'true')
        })

        // Uncheck the expiration checkbox
        await user.click(expirationCheckbox)

        // Expiration section should no longer be visible
        await waitFor(() => {
          expect(screen.queryByTestId(COUPON_EXPIRATION_SECTION_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN the plan/metric limit checkbox is checked but no items are added', () => {
      it('THEN should show the limit selection error after submit', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the plan/metric limit checkbox
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Error should NOT be visible before submit
        expect(screen.queryByTestId(COUPON_LIMIT_ERROR_TEST_ID)).not.toBeInTheDocument()

        // Submit the form
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        // Error Alert should be visible after submit
        await waitFor(() => {
          expect(screen.getByTestId(COUPON_LIMIT_ERROR_TEST_ID)).toBeInTheDocument()
        })
      })
    })

    describe('WHEN a plan is added after submit with limit error', () => {
      it('THEN should hide the limit selection error', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the plan/metric limit checkbox
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Submit the form to trigger errors
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        await waitFor(() => {
          expect(screen.getByTestId(COUPON_LIMIT_ERROR_TEST_ID)).toBeInTheDocument()
        })

        // Click the "add plan" button to trigger openAddPlanToCouponDialog
        const addPlanButton = screen.getByTestId('add-plan-limit')

        await user.click(addPlanButton)

        await waitFor(() => {
          expect(capturedAddPlanOnSubmit).toBeDefined()
        })

        capturedAddPlanOnSubmit?.({ id: 'plan-1', name: 'Plan 1', code: 'plan_1' })

        // Error should disappear after adding a plan
        await waitFor(() => {
          expect(screen.queryByTestId(COUPON_LIMIT_ERROR_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN a billable metric is added after submit with limit error', () => {
      it('THEN should hide the limit selection error', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the plan/metric limit checkbox
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Submit the form to trigger errors
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        await waitFor(() => {
          expect(screen.getByTestId(COUPON_LIMIT_ERROR_TEST_ID)).toBeInTheDocument()
        })

        // Click the "add billable metric" button to trigger openAddBillableMetricToCouponDialog
        const addBMButton = screen.getByTestId('add-billable-metric-limit')

        await user.click(addBMButton)

        await waitFor(() => {
          expect(capturedAddBillableMetricOnSubmit).toBeDefined()
        })

        capturedAddBillableMetricOnSubmit?.({ id: 'bm-1', name: 'BM 1', code: 'bm_1' })

        // Error should disappear after adding a billable metric
        await waitFor(() => {
          expect(screen.queryByTestId(COUPON_LIMIT_ERROR_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN the plan/metric limit checkbox is unchecked after submit', () => {
      it('THEN should hide the limit selection error', async () => {
        const user = userEvent.setup()

        render(<CreateCoupon />)

        // Check the plan/metric limit checkbox
        const limitCheckbox = screen.getByTestId('checkbox-hasPlanOrBillableMetricLimit')

        await user.click(limitCheckbox)

        // Submit the form to trigger errors
        const submitButton = screen.getByTestId('submit')

        await user.click(submitButton)

        await waitFor(() => {
          expect(screen.getByTestId(COUPON_LIMIT_ERROR_TEST_ID)).toBeInTheDocument()
        })

        // Uncheck the plan/metric limit checkbox
        await user.click(limitCheckbox)

        // Error should disappear
        await waitFor(() => {
          expect(screen.queryByTestId(COUPON_LIMIT_ERROR_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })
  })
})
