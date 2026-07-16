import { gql } from '@apollo/client'
import { FormikProps } from 'formik'
import { tw } from 'lago-design-system'
import { useCallback, useId, useMemo, useState } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ButtonSelector, MultipleComboBox, TextInput } from '~/components/form'
import {
  getPrivilegeValueTypeTranslationKey,
  MUI_INPUT_BASE_ROOT_CLASSNAME,
  SEARCH_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME,
} from '~/core/constants/form'
import { scrollToAndClickElement } from '~/core/utils/domUtils'
import { FeaturePrivilegeAccordionFragment, PrivilegeValueTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { FeatureFormValues } from '~/pages/features/FeatureForm'

gql`
  fragment FeaturePrivilegeAccordion on PrivilegeObject {
    id
    code
    name
    valueType
    config {
      selectOptions
    }
  }
`
type FeaturePrivilegeAccordionProps = {
  id: string
  isEdition: boolean
  privilege: FeaturePrivilegeAccordionFragment
  privilegeIndex: number
  formikProps: FormikProps<FeatureFormValues>
}

export const FeaturePrivilegeAccordion = ({
  id,
  isEdition,
  privilege,
  privilegeIndex,
  formikProps,
}: FeaturePrivilegeAccordionProps) => {
  const componentId = useId()
  const { translate } = useInternationalization()
  const privilegeErrors = formikProps.errors.privileges?.[privilegeIndex]

  const [showSelectOptionsInput, setShowSelectOptionsInput] = useState(false)

  const setFieldValue = useCallback(
    (field: string, value: string | string[] | undefined) => {
      formikProps.setFieldValue(field, value)
    },
    [formikProps],
  )

  const deletePrivilege = useCallback(
    (privilegeIndexToDelete: number) => {
      formikProps.setFieldValue(
        'privileges',
        formikProps.values.privileges.filter((_, index) => index !== privilegeIndexToDelete),
      )
    },
    [formikProps],
  )

  const initialSelectOptions = useMemo(() => {
    return formikProps.initialValues?.privileges?.[privilegeIndex]?.config?.selectOptions || []
  }, [formikProps.initialValues?.privileges, privilegeIndex])

  const currentSearchClassName = useMemo(() => {
    // Replace all colons with dashes to make the class name valid for querySelector
    const usableComponentId = componentId.replace(/:/g, '-')

    return `${SEARCH_PRIVILEGE_SELECT_OPTIONS_INPUT_CLASSNAME}-${usableComponentId}`
  }, [componentId])

  const privilegeName = useMemo(() => {
    if (!!privilege.name) return privilege.name
    if (!!privilege.id) return '-'
    return translate('text_1752695518075tkwsxrwmwxh', {
      index: privilegeIndex + 1,
    })
  }, [privilege.name, privilege.id, privilegeIndex, translate])

  return (
    <Accordion
      id={id}
      initiallyOpen={!privilege.code}
      summary={
        <div className="flex w-full items-center justify-between gap-3 overflow-hidden">
          <div className="flex flex-col">
            <Typography variant="bodyHl" color="grey700">
              {privilegeName}
            </Typography>
            <Typography variant="caption" color="grey600">
              {privilege.code ||
                translate('text_1752697009139hdybjlkx3w6', {
                  index: privilegeIndex + 1,
                })}
            </Typography>
          </div>

          <Tooltip placement="top-end" title={translate('text_63aa085d28b8510cd46443ff')}>
            <Button
              icon="trash"
              variant="quaternary"
              onClick={(e) => {
                e.stopPropagation()

                deletePrivilege(privilegeIndex)
              }}
            />
          </Tooltip>
        </div>
      }
    >
      <div className="flex flex-col gap-6">
        <div className="flex gap-6">
          <TextInput
            className="flex-1"
            name={`privileges.${privilegeIndex}.name`}
            label={translate('text_1753122279978r7koj4iy2vy')}
            placeholder={translate('text_645bb193927b375079d28ace')}
            value={privilege.name || ''}
            onChange={(name) => {
              setFieldValue(`privileges.${privilegeIndex}.name`, name)
            }}
          />
          <TextInput
            className="flex-1"
            name={`privileges.${privilegeIndex}.code`}
            beforeChangeFormatter={['code']}
            disabled={isEdition && !!privilege.id}
            label={translate('text_1752845254936jdsefrsvmam')}
            placeholder={translate('text_645bb193927b375079d28b02')}
            value={privilege.code || ''}
            error={
              typeof privilegeErrors === 'string'
                ? privilegeErrors
                : privilegeErrors?.code || undefined
            }
            onChange={(code) => {
              setFieldValue(`privileges.${privilegeIndex}.code`, code)
            }}
          />
        </div>

        <ButtonSelector
          disabled={isEdition && !!privilege.id}
          label={translate('text_175287350361170qk4c93fmm')}
          description={translate('text_17528462240740oes60zeoas')}
          value={privilege.valueType || PrivilegeValueTypeEnum.Boolean}
          onChange={(value) => {
            setFieldValue(`privileges.${privilegeIndex}.valueType`, value.toString())

            if (value === PrivilegeValueTypeEnum.Select) {
              setShowSelectOptionsInput(true)

              setTimeout(() => {
                const element = document.querySelector(
                  `.${currentSearchClassName} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                ) as HTMLElement

                if (!element) return

                element.scrollBy({ top: 300, behavior: 'smooth' })
                element.click()
              }, 0)
            }
          }}
          options={[
            {
              label: translate(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Boolean]),
              value: PrivilegeValueTypeEnum.Boolean,
            },
            {
              label: translate(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Integer]),
              value: PrivilegeValueTypeEnum.Integer,
            },
            {
              label: translate(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.String]),
              value: PrivilegeValueTypeEnum.String,
            },
            {
              label: translate(getPrivilegeValueTypeTranslationKey[PrivilegeValueTypeEnum.Select]),
              value: PrivilegeValueTypeEnum.Select,
            },
          ]}
        />

        {privilege.valueType === PrivilegeValueTypeEnum.Select && (
          <div className="flex flex-col gap-3">
            <div className="flex flex-col gap-1">
              <Typography variant="captionHl" color="grey700">
                {translate('text_1752862804124q8fjgwp3ep9')}
              </Typography>
              <Typography variant="caption" color="grey600">
                {translate('text_1752862804124sm9d1gl8aha')}
              </Typography>
            </div>

            {!!privilege.config?.selectOptions?.length && (
              <div className="flex flex-wrap gap-2">
                {privilege.config?.selectOptions?.map(
                  (selectOption: string, selectOptionIndex: number) => (
                    <Chip
                      key={`privilege-${privilegeIndex}-option-${selectOptionIndex}`}
                      label={selectOption}
                      onDelete={
                        isEdition && !!privilege.id && initialSelectOptions.includes(selectOption)
                          ? undefined
                          : () => {
                              const newSelectOptions =
                                privilege.config?.selectOptions?.filter(
                                  (_, index) => index !== selectOptionIndex,
                                ) || []

                              setFieldValue(
                                `privileges.${privilegeIndex}.config.selectOptions`,
                                newSelectOptions,
                              )
                            }
                      }
                    />
                  ),
                )}
              </div>
            )}

            {showSelectOptionsInput ? (
              <div className="flex gap-3">
                <MultipleComboBox
                  freeSolo
                  hideTags
                  disableClearable
                  disableCloseOnSelect
                  className={tw('w-full', currentSearchClassName)}
                  placeholder={translate('text_1752863499298r6x9j41ndoy')}
                  data={[]}
                  value={
                    privilege.config?.selectOptions?.map((selectOption: string) => ({
                      value: selectOption,
                    })) || []
                  }
                  onChange={(newValue) => {
                    const transformedValue =
                      newValue?.map((item) => item.value.trim()).filter((item) => !!item) || []

                    setFieldValue(
                      `privileges.${privilegeIndex}.config.selectOptions`,
                      transformedValue,
                    )
                  }}
                />

                <Tooltip
                  className="mt-1"
                  placement="top-end"
                  title={translate('text_63aa085d28b8510cd46443ff')}
                >
                  <Button
                    icon="trash"
                    variant="quaternary"
                    onClick={() => {
                      setShowSelectOptionsInput(false)
                    }}
                  />
                </Tooltip>
              </div>
            ) : (
              <Button
                fitContent
                startIcon="plus"
                variant="inline"
                onClick={() => {
                  setShowSelectOptionsInput(true)

                  scrollToAndClickElement({
                    selector: `.${currentSearchClassName} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                  })
                }}
              >
                {translate('text_6661fc17337de3591e29e427')}
              </Button>
            )}
          </div>
        )}
      </div>
    </Accordion>
  )
}
