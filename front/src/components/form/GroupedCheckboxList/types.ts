import { useStore } from '@tanstack/react-form'
import { ComponentType, ReactNode } from 'react'

import { RowConfig } from '~/components/designSystem/Table/TableWithGroups'
import { TypographyProps } from '~/components/designSystem/Typography'

// ============================================================================
// Data Types
// ============================================================================

type CheckboxGroupItem = {
  id: string // Unique key (e.g., "customer.created")
  label: string // Main title - MANDATORY
  sublabel?: string // Subtitle - OPTIONAL (e.g., description)
}

export type CheckboxGroup = {
  id: string // Group key (e.g., "customers")
  label: string // Group name (e.g., "Customers")
  items: CheckboxGroupItem[]
}

type GroupedCheckboxListProps = {
  // Dynamic texts
  title: string
  subtitle: string
  searchPlaceholder: string

  // Data
  groups: CheckboxGroup[]

  // Behavior
  isEditable?: boolean
  isLoading?: boolean
  errors?: string[]

  // Appearance
  /** Typography variant for item labels (e.g., "captionCode" for monospace). Defaults to Typography's default. */
  itemLabelVariant?: TypographyProps['variant']

  // Optional: custom scroll target for error alert
  errorScrollTarget?: string
}

// ============================================================================
// Internal Types
// ============================================================================

export type RowConfigWithSublabel = RowConfig & {
  sublabel?: string
}

export type GroupingMap = Record<
  string,
  {
    id: string
    label: string
    items: Array<{ id: string; label: string; sublabel?: string }>
  }
>

// ============================================================================
// TanStack Form Integration Types
// ============================================================================

/**
 * Interface for the field API provided by TanStack Form's AppField children render prop.
 * Contains the CheckboxField component used for individual checkbox rendering.
 */
export interface CheckboxFieldApi {
  CheckboxField: ComponentType<{ label: null; disabled?: boolean }>
}

/**
 * Minimal interface for TanStack Form's field group API.
 * This captures only the methods and properties used by GroupedCheckboxList,
 * avoiding the need to import complex generic types from TanStack Form.
 *
 * @template TValues - The shape of checkbox values (Record<string, boolean>)
 */
export interface FieldGroupApi<TValues extends Record<string, boolean>> {
  /** Store containing form state - used with useStore to subscribe to value changes */
  store: Parameters<typeof useStore>[0]
  /** Set a field value with optional validation control */
  setFieldValue: (
    name: keyof TValues & string,
    value: boolean,
    options?: { dontValidate?: boolean },
  ) => void
  /** Component for rendering form fields with TanStack Form integration */
  AppField: ComponentType<{
    name: keyof TValues & string
    key?: string
    children: (field: CheckboxFieldApi) => ReactNode
  }>
}

export type GroupedCheckboxListComponentProps<TValues extends Record<string, boolean>> =
  GroupedCheckboxListProps & {
    group: FieldGroupApi<TValues>
  }
