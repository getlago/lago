import { useFormik } from 'formik'
import { Icon } from 'lago-design-system'
import { DateTime } from 'luxon'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { mixed, object, string } from 'yup'

import {
  isValidJSON,
  wrappedEvaluateExpression,
  wrappedParseExpression,
} from '~/components/billableMetrics/utils'
import { Button } from '~/components/designSystem/Button'
import { Chip } from '~/components/designSystem/Chip'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Typography } from '~/components/designSystem/Typography'
import { JsonEditorField } from '~/components/form/JsonEditor'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type CustomExpressionDrawerState = {
  expression?: string | null
  billableMetricCode?: string | null
  isEditable?: boolean
}

export interface CustomExpressionDrawerRef extends DrawerRef {
  openDrawer: (data?: CustomExpressionDrawerState) => unknown
  closeDrawer: () => unknown
}

type CustomExpressionDrawerProps = {
  onSave: (expression: string) => void
}

export type EventPayload = {
  event: {
    transaction_id: string
    external_subscription_id: string
    code: string
    timestamp: number
    properties: {
      [key: string]: string
    }
  }
}

type CustomExpressionInput = {
  expression: string
  eventPayload: EventPayload
}

export type ValidationResult = {
  result?: string | null
  error?: string | null
}

const CUSTOM_EXPRESSION_EXAMPLES = [
  'event.properties.tokens * event.properties.replicas',
  "concat(event.properties.user_id, '-' , event.properties.app_id)",
  '(event.properties.ended_at - event.timestamp) / 3600',
]

const TIMESTAMP = DateTime.now().toMillis()

export const CustomExpressionDrawer = forwardRef<
  CustomExpressionDrawerRef,
  CustomExpressionDrawerProps
>(({ onSave }, ref) => {
  const { translate } = useInternationalization()

  const drawerRef = useRef<DrawerRef>(null)
  const [localData, setLocalData] = useState<CustomExpressionDrawerState>()
  const [validationResult, setValidationResult] = useState<ValidationResult>()

  const closeDrawer = () => {
    formikProps.resetForm()
    setValidationResult({})
    drawerRef.current?.closeDrawer()
  }

  const formikProps = useFormik<CustomExpressionInput>({
    initialValues: {
      expression: localData?.expression || '',
      eventPayload: {
        event: {
          transaction_id: 'trx_id_123456789',
          external_subscription_id: 'sub_id_123456789',
          code: localData?.billableMetricCode || '__BILLABLE_METRIC_CODE__',
          timestamp: TIMESTAMP,
          properties: {
            property_name: '__YOUR__VALUE__',
          },
        },
      },
    },
    validationSchema: object().shape({
      expression: string().test((value) => wrappedParseExpression(value)),
      eventPayload: mixed().test((value) => isValidJSON(value)),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: (values) => {
      if (values?.expression) {
        onSave(values.expression)

        closeDrawer()
      }
    },
  })

  const onValidateExpression = async () => {
    const result = wrappedEvaluateExpression(
      formikProps.values.expression,
      formikProps.values.eventPayload,
      translate,
    )

    setValidationResult(result)
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (data) => {
      setLocalData(data)
      drawerRef.current?.openDrawer()
    },
    closeDrawer: () => drawerRef.current?.closeDrawer(),
  }))

  const hasErrors = !!(formikProps.errors.expression || formikProps.errors.eventPayload)

  return (
    <Drawer
      className="px-12 pt-12"
      ref={drawerRef}
      title={translate('text_1729771640162lug0w6ztlyr')}
      onClose={closeDrawer}
      stickyBottomBarClassName="z-10"
      stickyBottomBar={() => {
        return (
          <div className="flex justify-end gap-3">
            <Button
              size="large"
              variant="secondary"
              onClick={onValidateExpression}
              disabled={hasErrors}
            >
              {translate('text_1729773655417m826qhyr465')}
            </Button>

            {localData?.isEditable ? (
              <Button
                size="large"
                onClick={formikProps.submitForm}
                disabled={!validationResult?.result}
              >
                {translate('text_17297736554176g6clgo34du')}
              </Button>
            ) : (
              <Button size="large" onClick={() => drawerRef?.current?.closeDrawer()}>
                {translate('text_62f50d26c989ab03196884ae')}
              </Button>
            )}
          </div>
        )
      }}
    >
      <div>
        <div className="mb-12">
          <Typography variant="headline" color="grey700" className="mb-1">
            {translate('text_1729771640162lug0w6ztlyr')}
          </Typography>

          <Typography variant="subhead2" color="grey600">
            {translate('text_1729771640162z7ndqn1ju9h')}
          </Typography>
        </div>

        <Typography variant="subhead1" color="grey700" className="mb-6">
          {translate('text_1729771640162c0o1estqusi')}
        </Typography>

        <div className="mb-12 pb-12 shadow-b">
          <JsonEditorField
            name="expression"
            disabled={!localData?.isEditable}
            label={translate('text_17297736554164pkbpqi0ke8')}
            editorMode="text"
            customInvalidError={translate('text_1729864793151rrlucly2t6d')}
            showHelperOnError={true}
            formikProps={formikProps}
            placeholder={translate('text_1729771640162kaf49b93e20') + '\n'}
            helperText={
              <div className="mt-1">
                <Typography variant="body" color="grey600">
                  {translate('text_1729773655417n5w5fu02lbm')}
                </Typography>

                <div className="mt-1 flex flex-col items-start gap-1">
                  {CUSTOM_EXPRESSION_EXAMPLES.map((example, index) => (
                    <Chip
                      key={`ce-drawer-${index}`}
                      className="!px-2 !py-0.5"
                      size="small"
                      variant="captionCode"
                      color="grey600"
                      label={example}
                    />
                  ))}
                </div>
              </div>
            }
          />
        </div>

        <div className="mb-6">
          <Typography variant="subhead1" color="grey700" className="mb-2">
            {translate('text_1729773655417vo5dm6vqzpu')}
          </Typography>
          <Typography variant="body" color="grey600">
            {translate('text_1729773655417khuj828ti9j')}
          </Typography>
        </div>

        <JsonEditorField
          name="eventPayload"
          height="300px"
          label={translate('text_1729773655417k0y7nxt5c5j')}
          formikProps={formikProps}
          customInvalidError={translate('text_6638a3538de76801ac2f451b')}
          placeholder={translate('text_17297753616921jc1iyf6mke')}
        />

        <div className="mt-6">
          <Typography variant="body" color="grey600" className="mb-1">
            {translate('text_1729773655417b4y4j7oatnq')}
          </Typography>

          {validationResult?.error && (
            <div className="flex items-center gap-2">
              <Icon name="warning-filled" color="warning" />

              <Typography variant="subhead1" color="grey600">
                {validationResult?.error}
              </Typography>
            </div>
          )}

          {!validationResult?.result && !validationResult?.error && (
            <Typography variant="subhead2" color="grey500">
              {translate('text_17297736554178ifm0gd8093')}
            </Typography>
          )}

          {validationResult?.result && !validationResult?.error && (
            <Typography variant="subhead2" color="grey700">
              {validationResult?.result}
            </Typography>
          )}
        </div>
      </div>
    </Drawer>
  )
})

CustomExpressionDrawer.displayName = 'CustomExpressionDrawer'
