import { FormikErrors, useFormik } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { array, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Drawer, DrawerRef } from '~/components/designSystem/Drawer'
import { Typography } from '~/components/designSystem/Typography'
import { MappingTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import NetsuiteAdditionalMappingForm from '~/pages/settings/integrations/NetsuiteAdditionalMappings/NetsuiteAdditionalMappingForm'
import { useNetsuiteAdditionalMappingsCUD } from '~/pages/settings/integrations/NetsuiteAdditionalMappings/useNetsuiteAdditionalMappingsCUD'

import {
  FormValuesType,
  NetsuiteAdditionalMappingDrawerProps,
  NetsuiteAdditionalMappingDrawerRef,
} from './types'

export const NetsuiteAdditionalMappingDrawer = forwardRef<NetsuiteAdditionalMappingDrawerRef>(
  (_, ref) => {
    const { translate } = useInternationalization()
    const drawerRef = useRef<DrawerRef>(null)
    const [localData, setLocalData] = useState<NetsuiteAdditionalMappingDrawerProps | undefined>(
      undefined,
    )

    const { createCollectionMapping, updateCollectionMapping, deleteCollectionMapping } =
      useNetsuiteAdditionalMappingsCUD()

    const getInitialValues = (): FormValuesType => {
      const mappings = localData?.mappings || []

      return {
        default: mappings,
      }
    }

    const validateForm = (
      values: FormValuesType,
    ): object | Promise<FormikErrors<FormValuesType>> => {
      // For delete action, form needs to be empty but valid
      if (Object.values(values).filter((v) => !!v).length === 0) {
        return {}
      }

      const hasOneEmptyField = values.default.some((valueObj) =>
        Object.values(valueObj).some((fieldValue) => !fieldValue),
      )

      if (hasOneEmptyField) {
        return {
          error: 'Fill all fields',
        }
      }

      return {}
    }

    const validationSchema = array().of(
      object().shape({
        currencyCode: string(),
        currencyExternalCode: string().required(),
      }),
    )

    const formikProps = useFormik<FormValuesType>({
      initialValues: getInitialValues(),
      validate(values) {
        return validateForm(values)
      },
      validationSchema,
      validateOnMount: true,
      enableReinitialize: true,
      onSubmit: async (values) => {
        const hasItemValues = !!values.default.length
        const hasInitialData = !!localData?.itemId
        const isCreate = !hasInitialData
        const isEdit = !isCreate && hasInitialData && hasItemValues
        const isDelete = !isCreate && !isEdit && !hasItemValues

        if (!localData || localData.type !== MappingTypeEnum.Currencies) {
          return
        }

        if (isDelete) {
          const answer = await deleteCollectionMapping({
            variables: {
              input: {
                id: localData?.itemId as string,
              },
            },
          })

          const { errors } = answer

          if (!errors?.length) {
            drawerRef?.current?.closeDrawer()
          }

          return
        }

        if (isCreate) {
          const answer = await createCollectionMapping({
            variables: {
              input: {
                integrationId: localData?.integrationId,
                mappingType: localData?.type,
                currencies: values.default,
              },
            },
          })

          const { errors } = answer

          if (!errors?.length) {
            drawerRef?.current?.closeDrawer()
          }

          return
        }

        if (isEdit) {
          const answer = await updateCollectionMapping({
            variables: {
              input: {
                id: localData?.itemId as string,
                integrationId: localData?.integrationId,
                mappingType: localData?.type,
                currencies: values.default,
              },
            },
          })

          const { errors } = answer

          if (!errors?.length) {
            drawerRef?.current?.closeDrawer()
          }
        }
      },
    })

    const title = translate('text_1762447116967mm930ergbsm')
    const description = translate('text_1762447116967j8jesn54y68')

    useImperativeHandle(ref, () => ({
      openDrawer: (props) => {
        setLocalData(props)
        drawerRef.current?.openDrawer()
      },
      closeDrawer: () => drawerRef.current?.closeDrawer(),
    }))

    return (
      <Drawer
        ref={drawerRef}
        title={title}
        onClose={() => {
          formikProps.resetForm()
          formikProps.validateForm()
        }}
        stickyBottomBar={
          <div className="flex justify-end gap-3">
            <Button variant="quaternary" onClick={() => drawerRef.current?.closeDrawer()}>
              {translate('text_6244277fe0975300fe3fb94a')}
            </Button>
            <Button
              disabled={!formikProps.isValid || !formikProps.dirty}
              onClick={formikProps.submitForm}
            >
              {translate('text_6630e51df0a194013daea624')}
            </Button>
          </div>
        }
      >
        <div className="flex flex-col gap-12">
          <div className="flex flex-col gap-1">
            <Typography variant="headline">{title}</Typography>
            <Typography>{description}</Typography>
          </div>
          <div className="mb-8 flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <Typography variant="subhead1">
                {translate('text_1762447672902pzry6bl0qnj')}
              </Typography>
              <Typography variant="caption">
                {translate('text_1762447672902fngpnyhdc9x')}
              </Typography>
            </div>
            <NetsuiteAdditionalMappingForm formikProps={formikProps} />
          </div>
        </div>
      </Drawer>
    )
  },
)

NetsuiteAdditionalMappingDrawer.displayName = 'NetsuiteAdditionalMappingDrawer'
