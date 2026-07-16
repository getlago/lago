import { render } from '@testing-library/react'
import { createRef } from 'react'

import { PrivilegeValueTypeEnum } from '~/generated/graphql'

import {
  FeatureEntitlementDrawer,
  FeatureEntitlementDrawerRef,
  FeatureEntitlementFormValues,
} from '../FeatureEntitlementDrawer'

// --- Capture callbacks ---

let capturedOnSubmit:
  ((args: { value: Record<string, unknown> }) => void | Promise<void>) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined

// --- Mocks ---

jest.mock('../FeatureEntitlementDrawerContent', () => ({
  FeatureEntitlementDrawerContent: () => <div data-test="feature-entitlement-drawer-content" />,
}))

const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: jest.fn(),
    close: mockDrawerClose,
  }),
}))

jest.mock('~/components/drawers/const', () => ({
  DRAWER_TRANSITION_DURATION: 0,
}))

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useGetFeatureDetailsForFeatureEntitlementPrivilegeSectionQuery: jest.fn(() => ({
      data: null,
      loading: false,
    })),
    useGetFeaturesListForPlanSectionLazyQuery: jest.fn(() => [jest.fn(), { data: null }]),
  }
})

jest.mock('~/core/utils/domUtils', () => ({
  scrollToAndClickElement: jest.fn(),
}))

// Mock TanStack form infrastructure
const mockHandleSubmit = jest.fn()
const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()
const mockRemoveFieldValue = jest.fn()

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
}))

const createMockForm = (defaultValues: Record<string, unknown>) => {
  const store = {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({ isDirty: false, values: defaultValues })),
  }

  return {
    store,
    useStore: jest.fn(() => defaultValues),
    state: { values: defaultValues },
    reset: mockReset,
    handleSubmit: mockHandleSubmit,
    setFieldValue: mockSetFieldValue,
    removeFieldValue: mockRemoveFieldValue,
    getFieldValue: jest.fn(),
    AppField: ({
      children,
      name,
    }: {
      children: (field: unknown) => React.ReactNode
      name: string
      listeners?: unknown
    }) => {
      return <div data-field-name={name}>{children({ name })}</div>
    },
    AppForm: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    SubmitButton: ({ children }: { children: React.ReactNode }) => (
      <button type="submit">{children}</button>
    ),
    Subscribe: ({
      children,
      selector,
    }: {
      children: (value: unknown) => React.ReactNode
      selector: (state: { canSubmit: boolean; values: Record<string, unknown> }) => unknown
    }) => {
      const value = selector({ canSubmit: true, values: defaultValues })

      return <>{children(value)}</>
    },
  }
}

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(
    ({
      onSubmit,
      defaultValues,
    }: {
      onSubmit?: (args: { value: Record<string, unknown> }) => void | Promise<void>
      defaultValues: Record<string, unknown>
    }) => {
      capturedOnSubmit = onSubmit
      capturedDefaultValues = defaultValues

      const form = createMockForm(defaultValues)

      return {
        ...form,
        handleSubmit: () => {
          mockHandleSubmit()
          onSubmit?.({ value: defaultValues })
        },
      }
    },
  ),
}))

describe('FeatureEntitlementDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<FeatureEntitlementDrawerRef>

  const defaultFormValues: FeatureEntitlementFormValues = {
    featureId: 'feature-1',
    featureName: 'Feature One',
    featureCode: 'feature_one',
    privileges: [],
  }

  const privilegeRow = {
    privilegeCode: 'priv-1',
    privilegeName: 'Privilege One',
    value: '',
    valueType: PrivilegeValueTypeEnum.String,
    config: undefined,
  }

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    drawerRef = createRef<FeatureEntitlementDrawerRef>()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  // --- Drawer ref ---

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it is initially closed', () => {
      it('THEN should expose ref methods', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(drawerRef.current).toBeDefined()
        expect(drawerRef.current?.openDrawer).toBeDefined()
        expect(drawerRef.current?.closeDrawer).toBeDefined()
      })

      it('THEN should expose openDrawer and closeDrawer as functions', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })
  })

  // --- openDrawer ---

  describe('GIVEN the drawer ref is exposed', () => {
    describe('WHEN openDrawer is called with values', () => {
      it('THEN should reset the form with keepDefaultValues true', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockReset).toHaveBeenCalledWith(
          { ...defaultFormValues, privileges: [] },
          { keepDefaultValues: true },
        )
      })
    })

    describe('WHEN openDrawer is called with values including privileges', () => {
      it('THEN should reset with the provided privileges array', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        const valuesWithPrivileges = {
          ...defaultFormValues,
          privileges: [privilegeRow],
        }

        drawerRef.current?.openDrawer(valuesWithPrivileges)

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({ privileges: [privilegeRow] }),
          { keepDefaultValues: true },
        )
      })
    })

    describe('WHEN openDrawer is called with undefined privileges', () => {
      it('THEN should default privileges to empty array via nullish coalescing', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        const valuesWithoutPrivileges = {
          ...defaultFormValues,
          privileges: undefined as unknown as FeatureEntitlementFormValues['privileges'],
        }

        drawerRef.current?.openDrawer(valuesWithoutPrivileges)

        expect(mockReset).toHaveBeenCalledWith(expect.objectContaining({ privileges: [] }), {
          keepDefaultValues: true,
        })
      })
    })

    describe('WHEN openDrawer is called without values', () => {
      it('THEN should reset the form without arguments', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        drawerRef.current?.openDrawer()

        expect(mockReset).toHaveBeenCalledWith()
      })
    })
  })

  // --- Form default values ---

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN featureId defaults to empty string', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(capturedDefaultValues?.featureId).toBe('')
      })

      it('THEN featureName defaults to empty string', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(capturedDefaultValues?.featureName).toBe('')
      })

      it('THEN featureCode defaults to empty string', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(capturedDefaultValues?.featureCode).toBe('')
      })

      it('THEN privileges defaults to empty array', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        expect(capturedDefaultValues?.privileges).toEqual([])
      })
    })
  })

  // --- onSubmit ---

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN values are submitted', () => {
      it('THEN should call onSave with correct values', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            featureId: 'feature-1',
            featureName: 'Feature One',
            featureCode: 'feature_one',
            privileges: [],
          }),
        )
      })
    })

    describe('WHEN privileges is undefined', () => {
      it('THEN should normalize to empty array', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        capturedOnSubmit?.({
          value: { ...defaultFormValues, privileges: undefined },
        })

        expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ privileges: [] }))
      })
    })

    describe('WHEN values are submitted with privileges', () => {
      it('THEN should pass privileges through to onSave', () => {
        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={mockOnSave}
            existingFeatureCodes={[]}
          />,
        )

        capturedOnSubmit?.({
          value: { ...defaultFormValues, privileges: [privilegeRow] },
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ privileges: [privilegeRow] }),
        )
      })
    })

    describe('WHEN onSave resolves to false (cascade cancelled)', () => {
      it('THEN should NOT close the drawer', async () => {
        const abortingOnSave = jest.fn().mockResolvedValue(false)

        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={abortingOnSave}
            existingFeatureCodes={[]}
          />,
        )

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(abortingOnSave).toHaveBeenCalled()
        expect(mockDrawerClose).not.toHaveBeenCalled()
      })
    })

    describe('WHEN onSave resolves to true', () => {
      it('THEN should close the drawer', async () => {
        const confirmingOnSave = jest.fn().mockResolvedValue(true)

        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={confirmingOnSave}
            existingFeatureCodes={[]}
          />,
        )

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })

    describe('WHEN onSave returns void (sync)', () => {
      it('THEN should close the drawer', async () => {
        const voidOnSave = jest.fn().mockReturnValue(undefined)

        render(
          <FeatureEntitlementDrawer
            ref={drawerRef}
            onSave={voidOnSave}
            existingFeatureCodes={[]}
          />,
        )

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })
  })
})
