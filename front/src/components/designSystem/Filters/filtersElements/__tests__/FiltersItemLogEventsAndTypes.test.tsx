import { render, screen, waitFor } from '@testing-library/react'

import { LogEventEnum, LogTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemLogEventsAndTypes } from '../FiltersItemLogEventsAndTypes'

jest.mock('~/components/designSystem/Filters/useFilters', () => ({
  useFilters: () => ({
    displayInDialog: false,
  }),
}))

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string, enumToUse?: typeof LogEventEnum | typeof LogTypeEnum) => {
  return render(
    <FiltersItemLogEventsAndTypes
      value={value}
      setFilterValue={mockSetFilterValue}
      enumToUse={enumToUse || LogEventEnum}
    />,
    {
      wrapper: AllTheProviders,
    },
  )
}

describe('FiltersItemLogEventsAndTypes', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no initial value', () => {
    it('THEN displays the combobox', async () => {
      renderComponent()

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN undefined value', () => {
    it('THEN should not crash and displays the combobox', async () => {
      renderComponent(undefined)

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a single value', () => {
    describe('WHEN value is "api_key_created"', () => {
      it('THEN displays the chip', async () => {
        renderComponent(LogEventEnum.ApiKeyCreated)

        await waitFor(() => {
          expect(screen.getByText(LogEventEnum.ApiKeyCreated)).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "user_signed_up"', () => {
      it('THEN displays the chip', async () => {
        renderComponent(LogEventEnum.UserSignedUp)

        await waitFor(() => {
          expect(screen.getByText(LogEventEnum.UserSignedUp)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multiple values', () => {
    describe('WHEN two log events are selected', () => {
      it('THEN displays all chips', async () => {
        const multipleValues = `${LogEventEnum.ApiKeyCreated},${LogEventEnum.UserSignedUp}`

        renderComponent(multipleValues)

        await waitFor(() => {
          expect(screen.getByText(LogEventEnum.ApiKeyCreated)).toBeInTheDocument()
          expect(screen.getByText(LogEventEnum.UserSignedUp)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN LogTypeEnum is used', () => {
    describe('GIVEN no initial value', () => {
      it('THEN displays the combobox', async () => {
        renderComponent(undefined, LogTypeEnum)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })

    describe('GIVEN a single value', () => {
      describe('WHEN value is "api_key"', () => {
        it('THEN displays the chip', async () => {
          renderComponent(LogTypeEnum.ApiKey, LogTypeEnum)

          await waitFor(() => {
            expect(screen.getByText(LogTypeEnum.ApiKey)).toBeInTheDocument()
          })
        })
      })

      describe('WHEN value is "user"', () => {
        it('THEN displays the chip', async () => {
          renderComponent(LogTypeEnum.User, LogTypeEnum)

          await waitFor(() => {
            expect(screen.getByText(LogTypeEnum.User)).toBeInTheDocument()
          })
        })
      })
    })

    describe('GIVEN multiple values', () => {
      describe('WHEN two log types are selected', () => {
        it('THEN displays all chips', async () => {
          const multipleValues = `${LogTypeEnum.ApiKey},${LogTypeEnum.User}`

          renderComponent(multipleValues, LogTypeEnum)

          await waitFor(() => {
            expect(screen.getByText(LogTypeEnum.ApiKey)).toBeInTheDocument()
            expect(screen.getByText(LogTypeEnum.User)).toBeInTheDocument()
          })
        })
      })
    })
  })
})
