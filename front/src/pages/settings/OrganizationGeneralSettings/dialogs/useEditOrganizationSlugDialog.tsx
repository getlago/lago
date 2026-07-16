import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { useRef } from 'react'

import { useFormDialog } from '~/components/dialogs/FormDialog'
import { DialogResult } from '~/components/dialogs/types'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { rewriteSlugInLocationHistory } from '~/core/apolloClient/reactiveVars'
import { GENERAL_SETTINGS_ROUTE, useNavigate } from '~/core/router'
import { LagoApiError, useUpdateOrganizationSlugMutation } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import {
  editOrganizationSlugDefaultValues,
  editOrganizationSlugValidationSchema,
} from './validationSchema'

gql`
  mutation updateOrganizationSlug($input: UpdateOrganizationInput!) {
    updateOrganization(input: $input) {
      id
      slug
    }
  }
`

const EDIT_ORGANIZATION_SLUG_FORM_ID = 'form-edit-organization-slug'

type EditOrganizationSlugDialogData = {
  currentSlug: string
}

export const useEditOrganizationSlugDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const dataRef = useRef<EditOrganizationSlugDialogData | null>(null)
  const successRef = useRef<{ orgId: string; savedSlug: string } | null>(null)

  const [updateOrganizationSlug] = useUpdateOrganizationSlugMutation({
    // The mutation's return type is `CurrentOrganization`, which is a separate
    // cache entry from the `Organization` that lives inside the current user's
    // memberships. Apollo's auto-normalization only touches the returned type,
    // so without this `update` the memberships would still carry the old slug
    // and `OrganizationLayout` would render Error404 for the new URL until a
    // full refetch landed — the race that caused the 404 flash on submit.
    // Patching the `Organization:${id}` entry directly keeps the SPA flow
    // (no hard reload, no cache clearing) while staying in sync instantly.
    update(cache, { data }) {
      if (!data?.updateOrganization?.id || !data.updateOrganization.slug) return

      cache.modify({
        id: cache.identify({
          __typename: 'Organization',
          id: data.updateOrganization.id,
        }),
        fields: {
          slug: () => data.updateOrganization?.slug ?? '',
        },
      })
    },
  })

  const form = useAppForm({
    defaultValues: editOrganizationSlugDefaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: editOrganizationSlugValidationSchema,
    },
    onSubmit: async ({ value, formApi }) => {
      const result = await updateOrganizationSlug({
        variables: { input: { slug: value.slug } },
        context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
      })

      const { errors, data } = result

      if (hasDefinedGQLError('ValueAlreadyExist', errors, 'slug')) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              slug: {
                message: 'text_1776867582730tgxmf57unmt',
                path: ['slug'],
              },
            },
          },
        })

        return
      }

      if (errors?.length) {
        formApi.setErrorMap({
          onDynamic: {
            fields: {
              slug: {
                message: 'text_1776867582730967zpytg618',
                path: ['slug'],
              },
            },
          },
        })

        return
      }

      const savedSlug = data?.updateOrganization?.slug
      const orgId = data?.updateOrganization?.id

      if (savedSlug && orgId) {
        successRef.current = { orgId, savedSlug }
      }
    },
  })

  const handleSubmit = async (): Promise<DialogResult> => {
    successRef.current = null
    await form.handleSubmit()

    if (!successRef.current) {
      throw new Error('Submit failed')
    }

    return { reason: 'success' }
  }

  const openEditOrganizationSlugDialog = (data: EditOrganizationSlugDialogData) => {
    dataRef.current = data
    form.reset()
    form.setFieldValue('slug', data.currentSlug)

    formDialog
      .open({
        title: translate('text_1776867582729jiym04jk1ax'),
        description: translate('text_1776867582730aqe2kknmohd'),
        children: (
          <div className="flex flex-col gap-6 px-6 pb-2 pt-6">
            <div className="flex items-center gap-3 overflow-hidden rounded-xl border border-grey-300 px-3 py-2">
              <span className="font-mono shrink-0 rounded-md bg-grey-100 px-2 py-1 text-sm text-grey-700">
                {translate('text_1776867582730qd932fynpjo')}
              </span>
              <form.Subscribe selector={(state) => state.values.slug}>
                {(slugValue) => (
                  <span className="font-mono truncate text-sm text-grey-700">
                    {window.location.origin}
                    {'/'}
                    {slugValue}
                  </span>
                )}
              </form.Subscribe>
            </div>

            <form.AppField name="slug">
              {(field) => (
                <field.TextInputField
                  label={translate('text_1776867582729ra096lnt5hc')}
                  placeholder={translate('text_1776867582730tl36ydvczz2')}
                  beforeChangeFormatter={['lowercase', 'dashSeparator']}
                  helperText={translate('text_1776867582730967zpytg618')}
                />
              )}
            </form.AppField>
          </div>
        ),
        closeOnError: false,
        mainAction: (
          <form.AppForm>
            <form.SubmitButton>{translate('text_1776867582730tnsmp9njbz7')}</form.SubmitButton>
          </form.AppForm>
        ),
        form: {
          id: EDIT_ORGANIZATION_SLUG_FORM_ID,
          submit: handleSubmit,
        },
      })
      .then((response) => {
        if (response.reason === 'success' && successRef.current && dataRef.current) {
          const { savedSlug } = successRef.current
          const { currentSlug: oldSlug } = dataRef.current

          // Keep `goBack(...)` consumers (e.g. "Back to app" in
          // SettingsNavLayout) in sync with the new slug so they don't
          // navigate to the pre-rename URL and land on Error404.
          rewriteSlugInLocationHistory(oldSlug, savedSlug)

          // The `update` callback on the mutation already patched the
          // `Organization:${id}` cache entry with the new slug, so by the
          // time OrganizationLayout re-renders under the new URL it finds
          // the membership matching the new slug and renders normally.
          navigate(`/${savedSlug}${GENERAL_SETTINGS_ROUTE}`, {
            skipSlugPrepend: true,
          })

          addToast({
            severity: 'success',
            translateKey: 'text_17768675827302s9i3t87uhn',
          })
        }

        form.reset()
        dataRef.current = null
        successRef.current = null
      })
  }

  return { openEditOrganizationSlugDialog }
}
