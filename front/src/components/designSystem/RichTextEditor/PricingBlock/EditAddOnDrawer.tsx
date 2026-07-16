import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

export const editAddOnDrawerDefaultValues = {
  invoiceDisplayName: '',
  description: '',
  fromDatetime: '',
  toDatetime: '',
}

const DESCRIPTION_MAX_LENGTH = 255

const EditAddOnDrawer = withForm({
  defaultValues: editAddOnDrawerDefaultValues,
  render: function EditAddOnDrawerRender({ form }) {
    const { translate } = useInternationalization()

    return (
      <div className="flex flex-col gap-12">
        <div className="flex flex-col gap-1">
          <Typography variant="headline">{translate('text_1780302522400cvm8js8nfg2')}</Typography>
          <Typography>{translate('text_17800447462496abqig1cu57')}</Typography>
        </div>
        <div className="flex flex-col gap-6 pb-12 shadow-b">
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_17803025224002y9fcnkkbgr')}</Typography>
            <Typography variant="caption">{translate('text_1780302522400pnacismclbw')}</Typography>
          </div>
          <div className="grid grid-cols-2 gap-6">
            <form.AppField name="fromDatetime">
              {(field) => (
                <field.DatePickerField
                  label={translate('text_1779980717322k58g8b65e2i')}
                  placement="auto"
                />
              )}
            </form.AppField>

            <form.AppField name="toDatetime">
              {(field) => (
                <field.DatePickerField
                  label={translate('text_1779980717322igk4qqvn301')}
                  placement="auto"
                />
              )}
            </form.AppField>
          </div>
        </div>
        <div className="flex flex-col gap-6">
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_1780302522400k2n947rez9j')}</Typography>
            <Typography variant="caption">{translate('text_17803025224002dj16pqxyw2')}</Typography>
          </div>
          <form.AppField name="invoiceDisplayName">
            {(field) => (
              <field.TextInputField
                label={translate('text_1780302522400gadrdaf1b98')}
                placeholder={translate('text_1780315326244ealvuyps1ha')}
                isOptional
                description={translate('text_17803025224008vabqxzdl7e')}
              />
            )}
          </form.AppField>

          <div className="flex flex-col gap-1">
            <form.AppField name="description">
              {(field) => (
                <field.TextInputField
                  label={translate('text_6453819268763979024ad011')}
                  placeholder={translate('text_1779980717322yv9i0606bn2')}
                  multiline
                  inputProps={{ maxLength: DESCRIPTION_MAX_LENGTH }}
                  rows={3}
                  isOptional
                />
              )}
            </form.AppField>
            <Typography variant="caption">{translate('text_1780302661071iqcpu91vg0u')}</Typography>
          </div>
        </div>
      </div>
    )
  },
})

export default EditAddOnDrawer
