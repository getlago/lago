import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { buildCodeComboboxItem } from '../codeComboboxItem'

describe('buildCodeComboboxItem', () => {
  it('builds the value and `name (code)` label', () => {
    const item = buildCodeComboboxItem({ id: 'bm-1', name: 'API Calls', code: 'api_calls' })

    expect(item.value).toBe('bm-1')
    expect(item.label).toBe('API Calls (api_calls)')
  })

  it('renders a two-line label node showing both name and code', () => {
    const item = buildCodeComboboxItem({ id: 'bm-1', name: 'API Calls', code: 'api_calls' })

    render(<>{item.labelNode}</>)

    expect(screen.getByText('API Calls')).toBeInTheDocument()
    expect(screen.getByText('api_calls')).toBeInTheDocument()
  })
})
