import { cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useEffect } from 'react'

import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import {
  CONSOLIDATION_SECTION_TEST_ID,
  SubscriptionInvoiceConsolidationSection,
} from '../SubscriptionInvoiceConsolidationSection'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

type WrapperProps = {
  initialValue?: boolean
  onValueChange?: (value: boolean) => void
}

const Wrapper = ({ initialValue = true, onValueChange }: WrapperProps) => {
  const form = useAppForm({
    defaultValues: { consolidateInvoice: initialValue },
  })

  useEffect(() => {
    if (!onValueChange) return
    const subscription = form.store.subscribe(() => {
      onValueChange(form.state.values.consolidateInvoice)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [form, onValueChange])

  return (
    <form.AppForm>
      <SubscriptionInvoiceConsolidationSection
        form={form}
        fields={{ consolidateInvoice: 'consolidateInvoice' }}
      />
    </form.AppForm>
  )
}

describe('SubscriptionInvoiceConsolidationSection', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should display the section container', () => {
        render(<Wrapper />)

        expect(screen.getByTestId(CONSOLIDATION_SECTION_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render two radio inputs', () => {
        render(<Wrapper />)

        const radios = screen
          .getByTestId(CONSOLIDATION_SECTION_TEST_ID)
          .querySelectorAll('input[type="radio"]')

        expect(radios).toHaveLength(2)
      })
    })

    describe('WHEN initial value is provided', () => {
      it('THEN should bind both radios to the consolidateInvoice form field', () => {
        render(<Wrapper initialValue={true} />)

        const inputs = screen
          .getByTestId(CONSOLIDATION_SECTION_TEST_ID)
          .querySelectorAll<HTMLInputElement>('input[type="radio"]')

        expect(inputs).toHaveLength(2)
        inputs.forEach((input) => {
          expect(input).toHaveAttribute('name', 'consolidateInvoice')
        })
      })
    })
  })

  describe('GIVEN the user interacts with the radios', () => {
    const getRadios = () =>
      Array.from(
        screen
          .getByTestId(CONSOLIDATION_SECTION_TEST_ID)
          .querySelectorAll<HTMLInputElement>('input[type="radio"]'),
      )

    describe('WHEN clicking the consolidate radio', () => {
      it('THEN should update the form value to true', async () => {
        const onValueChange = jest.fn()
        const user = userEvent.setup()

        render(<Wrapper initialValue={false} onValueChange={onValueChange} />)

        const [consolidate] = getRadios()

        await user.click(consolidate)

        expect(onValueChange).toHaveBeenLastCalledWith(true)
      })
    })

    describe('WHEN clicking the isolate radio', () => {
      it('THEN should update the form value to false', async () => {
        const onValueChange = jest.fn()
        const user = userEvent.setup()

        render(<Wrapper initialValue={true} onValueChange={onValueChange} />)

        const [, isolate] = getRadios()

        await user.click(isolate)

        expect(onValueChange).toHaveBeenLastCalledWith(false)
      })
    })
  })
})
