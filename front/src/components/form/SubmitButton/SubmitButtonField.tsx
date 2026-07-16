import { Button, ButtonProps } from '~/components/designSystem/Button'
import { useFormContext } from '~/hooks/forms/formContext'

const SubmitButtonField = ({
  children,
  size,
  variant,
  fullWidth,
  danger,
  disabled,
  dataTest,
}: ButtonProps & { dataTest?: string }) => {
  const form = useFormContext()

  return (
    <form.Subscribe
      selector={(state) => ({
        isSubmitting: state.isSubmitting,
        canSubmit: state.canSubmit,
      })}
    >
      {({ isSubmitting, canSubmit }) => (
        <Button
          size={size}
          variant={variant}
          fullWidth={fullWidth}
          danger={danger}
          disabled={disabled || !canSubmit || isSubmitting}
          loading={isSubmitting}
          type="submit"
          data-test={dataTest}
        >
          {children}
        </Button>
      )}
    </form.Subscribe>
  )
}

export default SubmitButtonField
