import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { RadioGroupField } from '~/components/form'
import {
  CreditNoteExportTypeEnum,
  DataExportFormatTypeEnum,
  InvoiceExportTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'

type ExportTypeEnum = CreditNoteExportTypeEnum | InvoiceExportTypeEnum

type ExportForm = {
  format: DataExportFormatTypeEnum
  resourceType: ExportTypeEnum
}

export type ExportValues<T> = {
  clientMutationId?: string
  format: DataExportFormatTypeEnum
  resourceType: T
}

type ExportDialogProps = {
  totalCountLabel: string
  // TODO: Fix this type
  // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
  onExport: Function
  disableExport?: boolean
  resourceTypeOptions: {
    label: string
    sublabel: string
    value: ExportForm['resourceType']
  }[]
}

export interface ExportDialogRef {
  openDialog: () => unknown
  closeDialog: () => unknown
}

export const ExportDialog = forwardRef<ExportDialogRef, ExportDialogProps>(
  (
    { totalCountLabel, onExport, disableExport = false, resourceTypeOptions }: ExportDialogProps,
    ref,
  ) => {
    const { translate } = useInternationalization()
    const { currentUser } = useCurrentUser()

    const formikProps = useFormik<Omit<ExportForm, 'filters'>>({
      initialValues: {
        format: DataExportFormatTypeEnum.Csv,
        resourceType: resourceTypeOptions[0].value,
      },
      validationSchema: object().shape({
        format: string().required(''),
      }),
      validateOnMount: true,
      enableReinitialize: true,
      onSubmit: (values) => onExport(values),
    })

    return (
      <Dialog
        ref={ref}
        title={translate('text_66b21236c939426d07ff9930')}
        description={translate('text_66b21236c939426d07ff9932')}
        onClose={() => {
          formikProps.resetForm()
          formikProps.validateForm()
        }}
        actions={({ closeDialog }) => (
          <>
            <Button variant="quaternary" onClick={closeDialog}>
              {translate('text_63eba8c65a6c8043feee2a14')}
            </Button>
            <Button
              variant="primary"
              disabled={!formikProps.isValid || disableExport}
              onClick={async () => {
                await formikProps.submitForm()
                closeDialog()
              }}
            >
              {translate('text_66b21236c939426d07ff9940')}
            </Button>
          </>
        )}
      >
        <div className="mb-8">
          <div className="grid grid-cols-[140px_1fr] items-center gap-3">
            <Typography variant="caption" color="grey600">
              {translate('text_6419c64eace749372fc72b27')}
            </Typography>
            <Typography variant="body" color="grey700">
              {currentUser?.email}
            </Typography>

            <Typography variant="caption" color="grey600">
              {translate('text_66b21236c939426d07ff9936')}
            </Typography>
            <Typography variant="body" color="grey700">
              {translate('text_66b21236c939426d07ff9935')}
            </Typography>

            <Typography variant="caption" color="grey600">
              {translate('text_66b21236c939426d07ff9938')}
            </Typography>
            <Typography variant="body" color="grey700">
              {totalCountLabel}
            </Typography>
          </div>

          <div className="my-8 w-full border-b border-grey-300" />

          <div className="mb-4">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_66b21236c939426d07ff9939')}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate('text_66b21236c939426d07ff993a')}
            </Typography>
          </div>

          <RadioGroupField
            name="resourceType"
            optionsGapSpacing={4}
            optionLabelVariant="body"
            options={resourceTypeOptions}
            formikProps={formikProps}
          />
        </div>
      </Dialog>
    )
  },
)

ExportDialog.displayName = 'ExportDialog'
