import { useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { object } from 'yup'

import { CreditNoteForm } from '~/components/creditNote/types'
import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { metadataSchema } from '~/formValidation/metadataSchema'
import { GetCreditNoteForDetailsQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import MetadataFormCard from '~/pages/createCreditNote/metadataForm/MetadataFormCard'

import { useEditCreditNote } from './useEditCreditNote'

type MetadataEditDrawerProps = {
  creditNote: GetCreditNoteForDetailsQuery['creditNote']
}

export interface MetadataEditDrawerRef {
  openDrawer: (props: MetadataEditDrawerProps) => unknown
  closeDrawer: () => unknown
}

export const MetadataEditDrawer = forwardRef<MetadataEditDrawerRef>((_, ref) => {
  const { translate } = useInternationalization()
  const drawerRef = useRef<DrawerRef>(null)
  const [localData, setLocalData] = useState<MetadataEditDrawerProps | undefined>(undefined)

  const { updateCreditNote, isUpdatingCreditNote } = useEditCreditNote()

  const formikProps = useFormik<Partial<CreditNoteForm>>({
    initialValues: {
      metadata: (localData?.creditNote?.metadata || []).map((metadata) => ({
        key: metadata.key,
        value: metadata.value || '',
      })),
    },
    enableReinitialize: true,
    validationSchema: object().shape({
      metadata: metadataSchema({
        keyMaxLength: 40,
        valueMaxLength: 255,
      }),
    }),
    onSubmit: async (values) => {
      if (!localData?.creditNote) return

      const answer = await updateCreditNote({
        variables: {
          input: {
            id: localData.creditNote.id,
            metadata: (values.metadata || []).map((metadata) => ({
              key: metadata.key,
              value: metadata.value,
            })),
          },
        },
      })

      const { errors } = answer

      if (errors?.length) {
        return
      }

      addToast({
        message: translate('text_17647718978181hu15vk5h86'),
        severity: 'success',
      })
      drawerRef.current?.closeDrawer()
    },
  })

  useImperativeHandle(ref, () => ({
    openDrawer: (props) => {
      setLocalData(props)
      drawerRef.current?.openDrawer()
    },
    closeDrawer: () => drawerRef.current?.closeDrawer(),
  }))

  const isFormButtonDisabled = !formikProps.isValid || !formikProps.dirty

  return (
    <Drawer ref={drawerRef} title={translate('text_176466851340792f3wzvqvb8')}>
      <div className="flex flex-col gap-6">
        <div className="flex flex-col gap-1 px-8">
          <Typography variant="headline">{translate('text_176466851340792f3wzvqvb8')}</Typography>
          <Typography variant="body" color="grey600">
            {translate('text_17646706795118k0wulsr7oq')}
          </Typography>
        </div>
        <MetadataFormCard formikProps={formikProps} />
        <div className="px-8 pb-8">
          <Button
            fullWidth
            variant="primary"
            loading={formikProps.isSubmitting || isUpdatingCreditNote}
            disabled={isFormButtonDisabled}
            onClick={formikProps.submitForm}
          >
            {translate('text_1764684767320qeu0x6az165')}
          </Button>
        </div>
      </div>
    </Drawer>
  )
})

MetadataEditDrawer.displayName = 'MetadataEditDrawer'
