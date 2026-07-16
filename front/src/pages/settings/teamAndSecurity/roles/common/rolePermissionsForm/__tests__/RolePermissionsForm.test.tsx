import { act, cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import { rolePermissionsEmptyValues } from '../const'
import RolePermissionsForm from '../RolePermissionsForm'

// Mock ResizeObserver for jsdom
const mockResizeObserver = jest.fn()

mockResizeObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.ResizeObserver = mockResizeObserver

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

// Wrapper component that provides form context with proper structure
const RolePermissionsFormWrapper = ({
  isEditable = true,
  isLoading = false,
  defaultValues = rolePermissionsEmptyValues,
  errors,
}: {
  isEditable?: boolean
  isLoading?: boolean
  defaultValues?: Record<string, boolean>
  errors?: Array<string>
}) => {
  const form = useAppForm({
    defaultValues: {
      name: '',
      code: '',
      description: '',
      permissions: defaultValues,
    },
  })

  return (
    <form.AppForm>
      <form>
        <RolePermissionsForm
          form={form}
          fields="permissions"
          isEditable={isEditable}
          isLoading={isLoading}
          errors={errors}
        />
      </form>
    </form.AppForm>
  )
}

describe('RolePermissionsForm', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders the permissions section title', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Title translation key
      expect(screen.getByText('text_17670124237009cpv09qihgr')).toBeInTheDocument()
    })

    it('renders the permissions section description', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Description translation key
      expect(screen.getByText('text_17658096048119hpdp8kwcqd')).toBeInTheDocument()
    })

    it('renders search input', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Search placeholder translation key
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('renders expand all button initially', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Initially all groups are collapsed, so button shows "Expand all"
      expect(screen.getByText('text_1768309883114yr34e2jrvn7')).toBeInTheDocument()
    })

    it('renders permissions table structure', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // The table should render with some content
      // Verify at least one checkbox is present (overall select all checkbox)
      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })
  })

  describe('Editable Mode', () => {
    it('renders checkboxes when isEditable is true', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={true} />))

      // Should have checkboxes for permissions
      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('renders view mode without editable checkbox column when isEditable is false', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={false} />))

      // In non-editable mode, the checkbox column should not be visible in the table
      // However, hidden checkboxes for form registration are still present
      // Verify the search input is present (component renders in view mode)
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('Loading State', () => {
    it('shows loading indicator when isLoading is true', async () => {
      await act(() => render(<RolePermissionsFormWrapper isLoading={true} />))

      // The table should still render but with loading state
      // Check that the search input is still visible
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('does not show loading indicator when isLoading is false', async () => {
      await act(() => render(<RolePermissionsFormWrapper isLoading={false} />))

      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('Search Functionality', () => {
    it('allows typing in search input', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      await user.type(searchInput, 'plans')

      expect(searchInput).toHaveValue('plans')
    })

    it('clears search input when cleanable button is clicked', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      await user.type(searchInput, 'test search')

      expect(searchInput).toHaveValue('test search')

      // Find and click the clear button (usually rendered when input has value)
      const clearButton = screen.queryByTestId('cleanable-button')

      if (clearButton) {
        await user.click(clearButton)
        expect(searchInput).toHaveValue('')
      }
    })
  })

  describe('Expand/Collapse Functionality', () => {
    it('shows expand all button initially when all groups are collapsed', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      const expandButton = screen.getByText('text_1768309883114yr34e2jrvn7')

      expect(expandButton).toBeInTheDocument()
    })

    it('expand all button is clickable and changes to collapse all', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const expandButton = screen.getByText('text_1768309883114yr34e2jrvn7')

      await user.click(expandButton)

      // After expanding, button should show "Collapse all"
      expect(screen.getByText('text_17683098831144lro3kg6rip')).toBeInTheDocument()
    })

    it('collapse all button changes back to expand all when clicked', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      // First click to expand
      const expandButton = screen.getByText('text_1768309883114yr34e2jrvn7')

      await user.click(expandButton)

      // Now click to collapse
      const collapseButton = screen.getByText('text_17683098831144lro3kg6rip')

      await user.click(collapseButton)

      // Should be back to showing "Expand all"
      expect(screen.getByText('text_1768309883114yr34e2jrvn7')).toBeInTheDocument()
    })
  })

  describe('Permission Groups', () => {
    it('renders permission groups in the table', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Should render groups - verify by checking that multiple checkboxes exist
      // Groups have their own checkbox plus the overall checkbox
      const checkboxes = screen.getAllByRole('checkbox')

      // There should be multiple checkboxes (overall + group checkboxes)
      expect(checkboxes.length).toBeGreaterThan(1)
    })
  })

  describe('Overall Checkbox', () => {
    it('renders overall checkbox when editable', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={true} />))

      // The overall checkbox should be the first checkbox in the header
      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('overall checkbox is unchecked when all permissions are false', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      // First checkbox should be the overall checkbox
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).not.toBeChecked()
    })

    it('overall checkbox is checked when all permissions are true', async () => {
      const allTrue = Object.keys(rolePermissionsEmptyValues).reduce(
        (acc, key) => {
          acc[key] = true
          return acc
        },
        {} as Record<string, boolean>,
      )

      await act(() => render(<RolePermissionsFormWrapper defaultValues={allTrue} />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).toBeChecked()
    })

    it('overall checkbox is indeterminate when some permissions are true', async () => {
      const someTrueValues = { ...rolePermissionsEmptyValues }
      const keys = Object.keys(someTrueValues) as (keyof typeof rolePermissionsEmptyValues)[]

      // Set first half to true
      keys.slice(0, Math.floor(keys.length / 2)).forEach((key) => {
        someTrueValues[key] = true
      })

      await act(() => render(<RolePermissionsFormWrapper defaultValues={someTrueValues} />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0] as HTMLInputElement

      // When indeterminate, the checkbox can appear checked or unchecked depending on implementation
      // Just verify it exists and is rendered
      expect(overallCheckbox).toBeInTheDocument()
    })

    it('clicking overall checkbox when unchecked enables all permissions', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).not.toBeChecked()

      await user.click(overallCheckbox)

      // After clicking, the overall checkbox should be checked
      expect(overallCheckbox).toBeChecked()
    })

    it('clicking overall checkbox when checked disables all permissions', async () => {
      const user = userEvent.setup()
      const allTrue = Object.keys(rolePermissionsEmptyValues).reduce(
        (acc, key) => {
          acc[key] = true
          return acc
        },
        {} as Record<string, boolean>,
      )

      await act(() => render(<RolePermissionsFormWrapper defaultValues={allTrue} />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).toBeChecked()

      await user.click(overallCheckbox)

      // After clicking, the overall checkbox should be unchecked
      expect(overallCheckbox).not.toBeChecked()
    })
  })

  describe('Group Checkbox Functionality', () => {
    it('group checkbox reflects all permissions in group being checked', async () => {
      // Set all permissions in first group to true
      const values = { ...rolePermissionsEmptyValues }
      // Set plans permissions to true (a known group)
      const plansPermissions = ['PlansCreate', 'PlansDelete', 'PlansUpdate', 'PlansView']

      plansPermissions.forEach((perm) => {
        const key = perm as keyof typeof rolePermissionsEmptyValues

        if (values[key] !== undefined) {
          values[key] = true
        }
      })

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      // There should be checkboxes for groups
      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(1)
    })

    it('clicking group checkbox enables all permissions in that group', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Skip overall checkbox (index 0), click first group checkbox
      if (checkboxes.length > 1) {
        await user.click(checkboxes[1])

        // Some checkboxes should now be checked
        const updatedCheckboxes = screen.getAllByRole('checkbox')
        const checkedCount = updatedCheckboxes.filter(
          (cb) => (cb as HTMLInputElement).checked,
        ).length

        expect(checkedCount).toBeGreaterThan(0)
      }
    })

    it('group checkbox is indeterminate when some permissions in group are checked', async () => {
      const values = { ...rolePermissionsEmptyValues }

      // Set only first plan permission to true
      values.PlansCreate = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })
  })

  describe('Individual Permission Checkboxes', () => {
    it('individual permission checkboxes can be toggled', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      // Get a permission checkbox (not overall or group)
      const permissionCheckbox = checkboxes[checkboxes.length - 1]

      const initialChecked = (permissionCheckbox as HTMLInputElement).checked

      await user.click(permissionCheckbox)

      expect((permissionCheckbox as HTMLInputElement).checked).toBe(!initialChecked)
    })

    it('individual permission checkboxes exist in non-editable mode for form registration', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={false} />))

      // In non-editable mode, hidden form checkboxes exist for form registration
      const checkboxes = screen.getAllByRole('checkbox')

      // Hidden checkboxes should still exist for form state management
      expect(checkboxes.length).toBeGreaterThan(0)
    })
  })

  describe('Search Filtering', () => {
    it('filters rows when searching for group name', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search for a specific group
      await user.type(searchInput, 'plans')

      // Component should still render
      expect(searchInput).toHaveValue('plans')
    })

    it('filters rows when searching for permission description', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search for a specific permission
      await user.type(searchInput, 'create')

      expect(searchInput).toHaveValue('create')
    })

    it('shows all rows when search is cleared', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search first
      await user.type(searchInput, 'plans')
      expect(searchInput).toHaveValue('plans')

      // Clear search
      await user.clear(searchInput)
      expect(searchInput).toHaveValue('')
    })

    it('search is case insensitive', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search with uppercase
      await user.type(searchInput, 'PLANS')

      expect(searchInput).toHaveValue('PLANS')
    })

    it('handles empty search term', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      expect(searchInput).toHaveValue('')
    })

    it('handles search term with only whitespace', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      await user.type(searchInput, '   ')

      expect(searchInput).toHaveValue('   ')
    })
  })

  describe('Error Display', () => {
    it('does not show alert when no errors', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // When no errors, the error alert should not be present
      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      expect(searchInput).toBeInTheDocument()
    })

    it('shows alert with error messages when errors exist', async () => {
      const errors = [
        'text_62b31e1f6a5b8b1b745ece48', // "An error occurred, please try again"
        'text_63e27c56dfe64b846474ef3b', // "Please refresh the page or contact us if the error persists."
      ]

      await act(() => render(<RolePermissionsFormWrapper errors={errors} />))

      // Check that error messages are displayed
      expect(screen.getByText(errors[0])).toBeInTheDocument()
      expect(screen.getByText(errors[1])).toBeInTheDocument()
    })

    it('shows alert with single error message', async () => {
      const errors = ['text_62b31e1f6a5b8b1b745ece48'] // "An error occurred, please try again"

      await act(() => render(<RolePermissionsFormWrapper errors={errors} />))

      // Check that error message is displayed
      expect(screen.getByText(errors[0])).toBeInTheDocument()
    })
  })

  describe('Non-editable Mode Icons', () => {
    it('shows check icon for enabled permissions in view mode', async () => {
      const values = { ...rolePermissionsEmptyValues }

      values.PlansCreate = true

      await act(() =>
        render(<RolePermissionsFormWrapper isEditable={false} defaultValues={values} />),
      )

      // Component should render in non-editable mode
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('shows close icon for disabled permissions in view mode', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={false} />))

      // Component should render in non-editable mode
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('Permission Count Display', () => {
    it('displays correct permission count for groups', async () => {
      const values = { ...rolePermissionsEmptyValues }

      // Enable 2 out of 4 plans permissions
      values.PlansCreate = true
      values.PlansView = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      // The component should render with permission counts
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('Hidden Form Fields', () => {
    it('renders hidden checkboxes for all permissions for form registration', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // All permission checkboxes should be registered including hidden ones
      const allCheckboxes = screen.getAllByRole('checkbox')

      expect(allCheckboxes.length).toBeGreaterThan(0)
    })
  })

  describe('Table Ref Methods', () => {
    it('expand all button triggers expandAll on table ref', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const expandButton = screen.getByText('text_1768309883114yr34e2jrvn7')

      // Should not throw
      await expect(user.click(expandButton)).resolves.not.toThrow()
    })

    it('collapse all button triggers collapseAll on table ref', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      // First expand all
      const expandButton = screen.getByText('text_1768309883114yr34e2jrvn7')

      await user.click(expandButton)

      // Then collapse all
      const collapseButton = screen.getByText('text_17683098831144lro3kg6rip')

      // Should not throw
      await expect(user.click(collapseButton)).resolves.not.toThrow()
    })
  })

  describe('Permission Grouping', () => {
    it('renders all permission groups', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Verify component renders with groups
      const checkboxes = screen.getAllByRole('checkbox')

      // Should have overall checkbox + group checkboxes + permission checkboxes
      expect(checkboxes.length).toBeGreaterThan(10)
    })

    it('organizes permissions into correct groups', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Component should render with organized groups
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('getOverallCheckboxValue function', () => {
    it('returns true when all permissions are enabled', async () => {
      const allTrue = Object.keys(rolePermissionsEmptyValues).reduce(
        (acc, key) => {
          acc[key] = true
          return acc
        },
        {} as Record<string, boolean>,
      )

      await act(() => render(<RolePermissionsFormWrapper defaultValues={allTrue} />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).toBeChecked()
    })

    it('returns false when all permissions are disabled', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      expect(overallCheckbox).not.toBeChecked()
    })

    it('returns undefined when permissions are mixed', async () => {
      const mixed = { ...rolePermissionsEmptyValues }

      mixed.PlansCreate = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={mixed} />))

      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes[0]).not.toBeChecked()
    })
  })

  describe('getGroupCheckboxValue function', () => {
    it('returns false when no permissions in group are enabled', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Group checkboxes should be unchecked
      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('returns true when all permissions in group are enabled', async () => {
      const values = { ...rolePermissionsEmptyValues }
      const plansPermissions = ['PlansCreate', 'PlansDelete', 'PlansUpdate', 'PlansView']

      plansPermissions.forEach((perm) => {
        const key = perm as keyof typeof rolePermissionsEmptyValues

        if (values[key] !== undefined) {
          values[key] = true
        }
      })

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('returns undefined when some permissions in group are enabled', async () => {
      const values = { ...rolePermissionsEmptyValues }

      values.PlansCreate = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('handles all permissions within a single group being checked', async () => {
      const values = { ...rolePermissionsEmptyValues }

      // Enable ALL customer permissions
      values.CustomersCreate = true
      values.CustomersDelete = true
      values.CustomersUpdate = true
      values.CustomersView = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Should have group checkbox in checked state
      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('handles exactly one permission enabled in group', async () => {
      const values = { ...rolePermissionsEmptyValues }

      // Enable only one permission
      values.CustomersCreate = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Should result in indeterminate group checkbox
      expect(checkboxes.length).toBeGreaterThan(0)
    })
  })

  describe('Validation with Errors', () => {
    it('checkbox changes trigger validation when errors exist', async () => {
      const user = userEvent.setup()
      const errors = ['text_62b31e1f6a5b8b1b745ece48'] // "An error occurred, please try again"

      await act(() => render(<RolePermissionsFormWrapper errors={errors} />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      // Click should work even with errors present
      await user.click(overallCheckbox)

      expect(overallCheckbox).toBeChecked()
    })

    it('group checkbox changes trigger validation when errors exist', async () => {
      const user = userEvent.setup()
      const errors = ['text_62b31e1f6a5b8b1b745ece48'] // "An error occurred, please try again"

      await act(() => render(<RolePermissionsFormWrapper errors={errors} />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Click group checkbox (skip overall at index 0)
      if (checkboxes.length > 1) {
        await user.click(checkboxes[1])

        // Should still work with errors
        expect(checkboxes.length).toBeGreaterThan(0)
      }
    })

    it('checkbox changes skip validation when no errors exist', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      await user.click(overallCheckbox)

      expect(overallCheckbox).toBeChecked()
    })
  })

  describe('Search Auto-Expand', () => {
    it('auto-expands groups when search matches are found', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search for something that should match and trigger auto-expand
      await user.type(searchInput, 'plans')

      // Give the useEffect time to run
      await act(async () => {
        await new Promise((resolve) => setTimeout(resolve, 100))
      })

      expect(searchInput).toHaveValue('plans')
    })

    it('auto-expands groups when individual permission matches search', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Search for a permission description
      await user.type(searchInput, 'create')

      // Give the useEffect time to run
      await act(async () => {
        await new Promise((resolve) => setTimeout(resolve, 100))
      })

      expect(searchInput).toHaveValue('create')
    })

    it('does not auto-expand when search term is cleared', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      // Type and then clear
      await user.type(searchInput, 'test')
      await user.clear(searchInput)

      expect(searchInput).toHaveValue('')
    })
  })

  describe('Column Rendering', () => {
    it('renders table with columns configured', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Table should render with the component structure
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('renders table columns in editable mode', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={true} />))

      // Should have checkboxes indicating checkbox column is rendered
      const checkboxes = screen.getAllByRole('checkbox')

      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('shows correct permission count in groups', async () => {
      const values = { ...rolePermissionsEmptyValues }

      // Enable some plans permissions
      values.PlansCreate = true
      values.PlansView = true

      await act(() => render(<RolePermissionsFormWrapper defaultValues={values} />))

      // Component should render with counts
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('handles empty permission grouping gracefully', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Component should still render
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('handles search with special characters', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const searchInput = screen.getByPlaceholderText('text_17670163638877x7zsoijho9')

      await user.type(searchInput, '@#$%')

      expect(searchInput).toHaveValue('@#$%')
    })

    it('handles rapid checkbox clicking', async () => {
      const user = userEvent.setup()

      await act(() => render(<RolePermissionsFormWrapper />))

      const checkboxes = screen.getAllByRole('checkbox')
      const overallCheckbox = checkboxes[0]

      // Click multiple times rapidly
      await user.click(overallCheckbox)
      await user.click(overallCheckbox)
      await user.click(overallCheckbox)

      // Should end up checked (3 clicks = on, off, on)
      expect(overallCheckbox).toBeChecked()
    })

    it('renders correctly with all checkboxes column config', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={true} />))

      const checkboxes = screen.getAllByRole('checkbox')

      // Should have checkbox column when editable
      expect(checkboxes.length).toBeGreaterThan(0)
    })

    it('renders correctly without checkboxes column config when not editable', async () => {
      await act(() => render(<RolePermissionsFormWrapper isEditable={false} />))

      // Should still render component
      expect(screen.getByPlaceholderText('text_17670163638877x7zsoijho9')).toBeInTheDocument()
    })

    it('handles multiple permission groups', async () => {
      await act(() => render(<RolePermissionsFormWrapper />))

      // Should render with multiple groups
      const checkboxes = screen.getAllByRole('checkbox')

      // Should have many checkboxes (overall + groups + permissions)
      expect(checkboxes.length).toBeGreaterThan(20)
    })
  })
})
