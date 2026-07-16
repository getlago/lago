import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { resendEmailFormDefaultValues } from './formInitialization'

type ResendEmailHeaderContentProps = {
  subject: string
}

const defaultProps: ResendEmailHeaderContentProps = {
  subject: 'Resend Email',
}

const ResendEmailHeaderContent = withForm({
  props: defaultProps,
  defaultValues: resendEmailFormDefaultValues,
  render: function Render({ form, subject }) {
    const { translate } = useInternationalization()

    return (
      <div className="grid grid-cols-[min-content_auto] grid-rows-4 gap-x-3 gap-y-4">
        {/* Margin top 12px to mimic vertical center */}
        <Typography color="grey700" className="mt-3">
          {translate('text_17706288935587mtvu3z5stp')}
        </Typography>
        <form.AppField name="to">
          {(field) => (
            <field.MultipleComboBoxField
              data={[]}
              PopperProps={{ displayInDialog: true }}
              placeholder={translate('text_626c0c09812bbc00e4c59e0b')}
              freeSolo
            />
          )}
        </form.AppField>
        <Typography color="grey700" className="mt-3">
          {translate('text_1770628893559thl29v6cswe')}
        </Typography>
        <form.AppField name="cc">
          {(field) => (
            <field.MultipleComboBoxField
              data={[]}
              PopperProps={{ displayInDialog: true }}
              placeholder={translate('text_626c0c09812bbc00e4c59e0b')}
              freeSolo
            />
          )}
        </form.AppField>
        <Typography color="grey700" className="mt-3">
          {translate('text_1770628893559w0k6n153vcy')}
        </Typography>
        <form.AppField name="bcc">
          {(field) => (
            <field.MultipleComboBoxField
              data={[]}
              PopperProps={{ displayInDialog: true }}
              placeholder={translate('text_626c0c09812bbc00e4c59e0b')}
              freeSolo
            />
          )}
        </form.AppField>
        <Typography color="grey700">{translate('text_1770641759899jnci1fphmyk')}</Typography>
        <Typography color="grey700">{subject}</Typography>
      </div>
    )
  },
})

export default ResendEmailHeaderContent
