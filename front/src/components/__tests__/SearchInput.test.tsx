import { screen } from '@testing-library/react'
import { debounce } from 'lodash'

import { SearchInput } from '~/components/SearchInput'
import { render } from '~/test-utils'

describe('SearchInput', () => {
  it('caps the input value at 255 characters', async () => {
    render(<SearchInput onChange={debounce(jest.fn(), 0)} placeholder="Search" />)

    expect(screen.getByRole('textbox')).toHaveAttribute('maxlength', '255')
  })
})
