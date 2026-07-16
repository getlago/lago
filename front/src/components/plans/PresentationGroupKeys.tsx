import { gql } from '@apollo/client'

import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Typography } from '~/components/designSystem/Typography'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment PresentationGroupKeys on Properties {
    presentationGroupKeys {
      value
      options {
        displayInInvoice
      }
    }
  }
`

const MAX_PRESENTATION_GROUP_KEYS = 2

const PresentationGroupKeys = () => {
  const { form, propertyCursor, disabled } = useChargeFormContext()
  const valuePointer = usePropertyValues(form, propertyCursor)
  const { translate } = useInternationalization()

  const presentationGroupKeys = valuePointer?.presentationGroupKeys || []

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <Typography variant="captionHl" color="textSecondary">
          {translate('text_17774502138912d3etwcacpe')}
        </Typography>
        <Typography variant="caption">{translate('text_17774502138910ajpyk51rzl')}</Typography>
      </div>

      {!!presentationGroupKeys.length && (
        <div className="-mx-4 overflow-auto px-4 pb-2">
          <ChargeTable
            name="presentation-group-keys-table"
            className="w-full"
            data={presentationGroupKeys.map((key) => ({
              ...key,
              disabledDelete: disabled,
            }))}
            onDeleteRow={(_row, i) => {
              const newKeys = presentationGroupKeys.filter((_, index) => index !== i)

              form.setFieldValue(`${propertyCursor}.presentationGroupKeys`, newKeys)
            }}
            columns={[
              {
                title: (
                  <Typography className="px-4" variant="captionHl">
                    {translate('text_17774502138912d3etwcacpe')}
                  </Typography>
                ),
                size: 200,
                content: (_, i) =>
                  disabled ? (
                    <Typography className="px-4" variant="body" noWrap>
                      {presentationGroupKeys[i]?.value}
                    </Typography>
                  ) : (
                    <form.AppField name={`${propertyCursor}.presentationGroupKeys[${i}].value`}>
                      {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                      {(field: any) => (
                        <field.TextInputField
                          variant="outlined"
                          placeholder={translate('text_1777450213892iqwuovg4s4v')}
                          displayErrorText={false}
                        />
                      )}
                    </form.AppField>
                  ),
              },
              {
                title: (
                  <Typography className="px-4" variant="captionHl" noWrap>
                    {translate('text_17774521952176h65ipy7idk')}
                  </Typography>
                ),
                size: 144,
                content: (_, i) =>
                  disabled ? (
                    <Typography className="px-4" variant="body" noWrap>
                      {presentationGroupKeys[i]?.options?.displayInInvoice === undefined && '-'}
                      {presentationGroupKeys[i]?.options?.displayInInvoice &&
                        translate('text_65251f46339c650084ce0d57')}
                      {!presentationGroupKeys[i]?.options?.displayInInvoice &&
                        translate('text_65251f4cd55aeb004e5aa5ef')}
                    </Typography>
                  ) : (
                    <form.AppField
                      name={`${propertyCursor}.presentationGroupKeys[${i}].options.displayInInvoice`}
                    >
                      {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                      {(field: any) => (
                        <field.ComboBoxField
                          variant="outlined"
                          placeholder={translate('text_66ab42d4ece7e6b7078993b1')}
                          displayErrorText={false}
                          data={[
                            {
                              label: translate('text_65251f46339c650084ce0d57'),
                              value: 'true',
                            },
                            {
                              label: translate('text_65251f4cd55aeb004e5aa5ef'),
                              value: 'false',
                            },
                          ]}
                        />
                      )}
                    </form.AppField>
                  ),
              },
            ]}
          />
        </div>
      )}

      <Button
        fitContent
        startIcon="plus"
        variant="inline"
        disabled={disabled || presentationGroupKeys.length >= MAX_PRESENTATION_GROUP_KEYS}
        onClick={() => {
          const newKeys = [
            ...presentationGroupKeys,
            { value: '', options: { displayInInvoice: undefined } },
          ]

          form.setFieldValue(`${propertyCursor}.presentationGroupKeys`, newKeys)
        }}
      >
        {translate('text_17774502138919dkx20lgvpi')}
      </Button>
    </div>
  )
}

export default PresentationGroupKeys
