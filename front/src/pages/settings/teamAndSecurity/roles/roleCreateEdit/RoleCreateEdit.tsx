import { revalidateLogic, useStore } from '@tanstack/react-form'
import { generatePath } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import NameAndCodeGroup from '~/components/form/NameAndCodeGroup/NameAndCodeGroup'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { hasDefinedGQLError } from '~/core/apolloClient'
import { RoleItem } from '~/core/constants/roles'
import { scrollToFirstInputError } from '~/core/form/scrollToFirstInputError'
import { ROLE_DETAILS_ROUTE, TEAM_AND_SECURITY_GROUP_ROUTE, useNavigate } from '~/core/router'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { mapFromApiToForm } from '~/pages/settings/teamAndSecurity/roles/common/rolePermissionsForm/mappers/mapFromApiToForm'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

import { useRoleCreateEdit } from './useRoleCreateEdit'

import { teamAndSecurityGroupOptions } from '../../common/teamAndSecurityConst'
import { mapFromFormToApi } from '../common/rolePermissionsForm/mappers/mapFromFormToApi'
import RolePermissionsForm from '../common/rolePermissionsForm/RolePermissionsForm'
import { validationSchema } from '../common/rolePermissionsForm/validationSchema'
import { useRoleDetails } from '../hooks/useRoleDetails'

export const SUBMIT_ROLE_DATA_TEST = 'submit-role-button'
export const ROLE_CREATE_EDIT_FORM_ID = 'role-create-edit-form'

const RoleCreateEdit = () => {
  const navigate = useNavigate()

  const { translate } = useInternationalization()

  const centralizedDialog = useCentralizedDialog()

  const { roleId, isEdition, handleSave } = useRoleCreateEdit()

  const { role, isLoadingRole } = useRoleDetails({ roleId })

  const getRoleToMapFrom = (): RoleItem | undefined => {
    if (!role) return undefined

    if (isEdition) {
      return role
    }

    // Duplicating a role: reset name, description and code
    return { ...role, name: '', description: '', code: '' } as RoleItem | undefined
  }

  const roleToMapFrom: RoleItem | undefined = getRoleToMapFrom()

  const isFormReady = !isLoadingRole

  const submitButtonText = isEdition
    ? translate('text_1765528921745ibx4b56q1mt')
    : translate('text_1766138146087w2ax628r6j1')

  const formTitle = isEdition
    ? translate('text_1766138146087vq4eqb2moza')
    : translate('text_176613814608779rumjj7r2d')

  const formDescription = translate('text_176613820114657nlabp19lm')

  const form = useAppForm({
    defaultValues: mapFromApiToForm(roleToMapFrom),
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const formattedValues = mapFromFormToApi(value)

      const answer = await handleSave(formattedValues)

      const { errors } = answer

      const errorsToDisplay = {
        onDynamic: {
          fields: {},
        },
      }

      if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        errorsToDisplay.onDynamic.fields = {
          ...errorsToDisplay.onDynamic.fields,
          code: {
            message: 'text_1772549222703l8p7bejr3g9',
            path: ['code'],
          },
        }
      }

      if (hasDefinedGQLError('ValueIsInvalid', errors, 'code')) {
        errorsToDisplay.onDynamic.fields = {
          ...errorsToDisplay.onDynamic.fields,
          code: {
            message: 'text_1767881112174odn29xztnvi',
            path: ['code'],
          },
        }
      }

      formApi.setErrorMap(errorsToDisplay)
    },
    onSubmitInvalid({ formApi }) {
      scrollToFirstInputError(ROLE_CREATE_EDIT_FORM_ID, formApi.state.errorMap.onDynamic || {})

      const onlyHasErrorsOnPermissions =
        formApi.state.errorMap.onDynamic?.permissions &&
        formApi.state.errorMap.onDynamic.permissions.length > 0 &&
        Object.keys(formApi.state.errorMap.onDynamic).length === 1

      if (onlyHasErrorsOnPermissions) {
        // Use querySelector to simplify scrolling to the alert error container instead of passing ref
        const alertError = document.querySelector(
          '[data-scroll-target="role-permissions-form-errors"]',
        )

        alertError?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    },
  })

  const handleClose = () => {
    if (isEdition && roleId) {
      navigate(generatePath(ROLE_DETAILS_ROUTE, { roleId }))
    } else {
      navigate(
        generatePath(TEAM_AND_SECURITY_GROUP_ROUTE, {
          group: teamAndSecurityGroupOptions.roles,
        }),
      )
    }
  }
  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    form.handleSubmit()
  }

  const handleAbort = () => {
    if (form.state.isDirty) {
      centralizedDialog.open({
        title: translate('text_665deda4babaf700d603ea13'),
        description: translate('text_665dedd557dc3c00c62eb83d'),
        actionText: translate('text_645388d5bdbd7b00abffa033'),
        onAction: handleClose,
      })
      return
    }

    handleClose()
  }

  const permissionsErrors = useStore(
    form.store,
    (state) => state.errorMap.onDynamic?.permissions || [],
  ).map((error) => error.message)

  return (
    <CenteredPage.Wrapper>
      <form
        id={ROLE_CREATE_EDIT_FORM_ID}
        className="flex min-h-full flex-col"
        onSubmit={handleSubmit}
      >
        <CenteredPage.Header>
          <Typography variant="bodyHl" noWrap>
            {formTitle}
          </Typography>
          <Button variant="quaternary" icon="close" onClick={handleAbort} />
        </CenteredPage.Header>

        {!isFormReady && (
          <CenteredPage.Container>
            <FormLoadingSkeleton id={ROLE_CREATE_EDIT_FORM_ID} />
          </CenteredPage.Container>
        )}

        {isFormReady && (
          <CenteredPage.Container>
            <div className="flex flex-col gap-1">
              <Typography variant="headline">{formTitle}</Typography>
              <Typography variant="body">{formDescription}</Typography>
            </div>
            <div className="flex flex-col gap-6 pb-12 shadow-b">
              <div className="flex flex-col gap-1">
                <Typography variant="subhead1">
                  {translate('text_1767012423699qiisp5z4jqy')}
                </Typography>
                <Typography variant="body">{translate('text_1767013866975h2lgwgojt4s')}</Typography>
              </div>
              <NameAndCodeGroup
                form={form}
                fields={{ name: 'name', code: 'code' }}
                disableCodeInput={isEdition}
              />
              <form.AppField name="description">
                {(field) => (
                  <field.TextInputField
                    label={translate('text_6388b923e514213fed58331c')}
                    placeholder={translate('text_176614189875029z5fbpnkne')}
                    isOptional
                    rows="3"
                    multiline
                  />
                )}
              </form.AppField>
            </div>

            <RolePermissionsForm
              form={form}
              fields="permissions"
              isEditable={true}
              isLoading={isLoadingRole}
              errors={permissionsErrors}
            />
          </CenteredPage.Container>
        )}

        <CenteredPage.StickyFooter>
          <Button variant="quaternary" onClick={handleAbort}>
            {translate('text_62e79671d23ae6ff149de968')}
          </Button>
          <form.AppForm>
            <form.SubmitButton dataTest={SUBMIT_ROLE_DATA_TEST}>
              {submitButtonText}
            </form.SubmitButton>
          </form.AppForm>
        </CenteredPage.StickyFooter>
      </form>
    </CenteredPage.Wrapper>
  )
}

export default RoleCreateEdit
