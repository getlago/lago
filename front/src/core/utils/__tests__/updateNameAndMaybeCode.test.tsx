import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Formik, FormikProps } from 'formik'

import { TextInput, TextInputField } from '~/components/form'

import { updateNameAndMaybeCode } from '../updateNameAndMaybeCode'

// We use a simple component that replicates the behavior of TextInputs in a Formik form.
const TestFormComponent = ({
  initialValues,
}: {
  initialValues: { name: string; code?: string }
}) => {
  return (
    <Formik initialValues={initialValues} onSubmit={() => {}}>
      {(formikProps: FormikProps<{ name: string; code?: string }>) => (
        <form>
          <TextInput
            name="name"
            label="Name"
            value={formikProps.values.name}
            onChange={(name) => {
              updateNameAndMaybeCode({ name, formikProps })
            }}
            data-test="name-input"
          />

          <TextInputField
            name="code"
            label="Code"
            formikProps={formikProps}
            data-test="code-input"
          />
        </form>
      )}
    </Formik>
  )
}

describe('updateNameAndMaybeCode', () => {
  it('updates the code when a name is entered and code is empty and untouched', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: '' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.type(nameInput, 'My Awesome Plan')

    expect(nameInput).toHaveValue('My Awesome Plan')
    expect(codeInput).toHaveValue('my_awesome_plan')
  })

  it('does not update the code if the code field has an initial value', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: 'existing_code' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.type(nameInput, 'My Awesome Plan')

    expect(nameInput).toHaveValue('My Awesome Plan')
    expect(codeInput).toHaveValue('existing_code')
  })

  it('does not update the code if the code field has been touched (by focusing and blurring)', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: '' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.click(codeInput)
    await user.tab() // This will blur the code input and touch it

    await user.type(nameInput, 'My Awesome Plan')

    expect(nameInput).toHaveValue('My Awesome Plan')
    expect(codeInput).toHaveValue('')
  })

  it('does not update the code if the user types in the code field first', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: '' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.type(codeInput, 'user_defined_code')
    await user.type(nameInput, 'My Awesome Plan')

    expect(nameInput).toHaveValue('My Awesome Plan')
    expect(codeInput).toHaveValue('user_defined_code')
  })

  it('updates the code correctly for names with multiple spaces and mixed case', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: '' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.type(nameInput, 'Another Plan With  More   Spaces')

    expect(nameInput).toHaveValue('Another Plan With  More   Spaces')
    expect(codeInput).toHaveValue('another_plan_with__more___spaces')
  })

  it('clears the code when the name is cleared, if code was being auto-generated', async () => {
    const user = userEvent.setup()

    render(<TestFormComponent initialValues={{ name: '', code: '' }} />)

    const nameInput = screen.getByLabelText('Name')
    const codeInput = screen.getByLabelText('Code')

    await user.type(nameInput, 'Temporary Name')
    expect(codeInput).toHaveValue('temporary_name')

    await user.clear(nameInput)
    expect(codeInput).toHaveValue('')
  })
})
