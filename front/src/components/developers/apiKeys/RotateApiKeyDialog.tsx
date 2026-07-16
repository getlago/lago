import { gql } from '@apollo/client'
import { revalidateLogic } from '@tanstack/react-form'
import { Icon } from 'lago-design-system'
import { DateTime } from 'luxon'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { z } from 'zod'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { intlFormatDateTime } from '~/core/timezone/utils'
import {
  ApiKeyForRotateApiKeyDialogFragment,
  ApiKeyRevealedForApiKeysListFragment,
  ApiKeyRevealedForApiKeysListFragmentDoc,
  TimezoneEnum,
  useRotateApiKeyMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'
import { useCurrentUser } from '~/hooks/useCurrentUser'

export const ROTATE_API_KEY_DIALOG_SUBMIT_BUTTON_TEST_ID = 'rotate-api-key-submit-button'

const ROTATE_API_KEY_FORM_ID = 'rotate-api-key-form'

const ExpirationValuesEnum = {
  Now: 'Now',
  OneHour: 'OneHour',
  OneDay: 'OneDay',
  TwoDays: 'TwoDays',
  OneWeek: 'OneWeek',
} as const

const ExpirationValuesTranslationLookup: Record<keyof typeof ExpirationValuesEnum, string> = {
  Now: 'text_17321824557181ur2gp8q0sn',
  OneHour: 'text_17321824557189ifksfwy6aa',
  OneDay: 'text_173218245571817juc2f7m13',
  TwoDays: 'text_1732286530467ge3ab3gsu84',
  OneWeek: 'text_17322865304678tljv20a3mg',
}

const rotateApiKeyValidationSchema = z.object({
  expiresAt: z.string().min(1),
})

gql`
  fragment ApiKeyForRotateApiKeyDialog on SanitizedApiKey {
    id
    lastUsedAt
    name
  }

  mutation rotateApiKey($input: RotateApiKeyInput!) {
    rotateApiKey(input: $input) {
      id
      ...ApiKeyRevealedForApiKeysList
    }
  }

  ${ApiKeyRevealedForApiKeysListFragmentDoc}
`

type RotateApiKeyDialogProps = {
  apiKey: ApiKeyForRotateApiKeyDialogFragment
  callBack: (itemToReveal: ApiKeyRevealedForApiKeysListFragment) => void
}

export interface RotateApiKeyDialogRef {
  openDialog: (data: RotateApiKeyDialogProps) => unknown
  closeDialog: () => unknown
}

export const RotateApiKeyDialog = forwardRef<
  RotateApiKeyDialogRef,
  { openPremiumDialog: VoidFunction }
>(({ openPremiumDialog }, ref) => {
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const dialogRef = useRef<DialogRef>(null)
  const [localData, setLocalData] = useState<RotateApiKeyDialogProps | undefined>(undefined)
  const apiKey = localData?.apiKey

  const form = useAppForm({
    defaultValues: {
      expiresAt: ExpirationValuesEnum.Now as string,
    },
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: rotateApiKeyValidationSchema,
    },
    onSubmit: async ({ value: { expiresAt } }) => {
      const ExpirationValuesAsTime = {
        Now: null,
        OneHour: DateTime.now().toUTC().plus({ hours: 1 }).toISO(),
        OneDay: DateTime.now().toUTC().plus({ days: 1 }).toISO(),
        TwoDays: DateTime.now().toUTC().plus({ days: 2 }).toISO(),
        OneWeek: DateTime.now().toUTC().plus({ weeks: 1 }).toISO(),
      }
      const transformedExpiredAt =
        ExpirationValuesAsTime[expiresAt as keyof typeof ExpirationValuesEnum]

      try {
        await rotateApiKey({
          variables: {
            input: {
              id: apiKey?.id || '',
              expiresAt: transformedExpiredAt,
              name: localData?.apiKey.name,
            },
          },
        })

        dialogRef.current?.closeDialog()
      } catch {
        addToast({
          severity: 'danger',
          translateKey: 'text_62b31e1f6a5b8b1b745ece48',
        })
      }
    },
  })

  const [rotateApiKey] = useRotateApiKeyMutation({
    onCompleted(data) {
      if (!!data?.rotateApiKey?.id) {
        localData?.callBack(data.rotateApiKey)

        addToast({
          message: translate('text_1731506310510htbvgegpzd8'),
          severity: 'success',
        })
      }
    },
    refetchQueries: ['getApiKeys'],
  })

  useImperativeHandle(ref, () => ({
    openDialog: (data) => {
      setLocalData(data)
      dialogRef.current?.openDialog()
    },
    closeDialog: () => {
      dialogRef.current?.closeDialog()
    },
  }))

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <Dialog
      ref={dialogRef}
      title={translate('text_173151476175058ugha8fd08')}
      description={translate('text_1731514761750dnh1s073j9o')}
      onClose={() => form.reset()}
      formId={ROTATE_API_KEY_FORM_ID}
      formSubmit={handleFormSubmit}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_64352657267c3d916f962769')}
          </Button>
          <Button
            danger
            type="submit"
            variant="primary"
            data-test={ROTATE_API_KEY_DIALOG_SUBMIT_BUTTON_TEST_ID}
          >
            {translate('text_173151476175058ugha8fd08')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 flex flex-col gap-8">
        <div className="flex w-full items-center">
          <Typography className="w-35" variant="caption" color="grey600">
            {translate('text_1731515447290xbe4iqm5n6r')}
          </Typography>
          <Typography className="flex-1" variant="body" color="grey700">
            {!!apiKey?.lastUsedAt
              ? intlFormatDateTime(apiKey?.lastUsedAt, {
                  timezone: TimezoneEnum.TzUtc,
                }).date
              : '-'}
          </Typography>
        </div>
        <div className="flex flex-col">
          <div className="mb-4">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_1732286530467qf204t1o5ol')}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate('text_17322865304677r38axxm3cc')}
            </Typography>
          </div>

          <div className="flex flex-col gap-4">
            <form.AppField name="expiresAt">
              {(field) => (
                <>
                  <field.RadioField
                    labelVariant="body"
                    value={ExpirationValuesEnum.Now}
                    label={translate(ExpirationValuesTranslationLookup.Now)}
                  />
                  {!isPremium && (
                    <div className="flex w-full flex-row items-center justify-between gap-2 rounded-xl bg-grey-100 px-6 py-4">
                      <div className="flex flex-col">
                        <div className="flex flex-row items-center gap-2">
                          <Typography variant="bodyHl" color="grey700">
                            {translate('text_1732286530467ezav2z7ypj1')}
                          </Typography>
                          <Icon name="sparkles" />
                        </div>

                        <Typography variant="caption" color="grey600">
                          {translate('text_1732286530467gnhwm6q5ftl')}
                        </Typography>
                      </div>
                      <Button endIcon="sparkles" variant="tertiary" onClick={openPremiumDialog}>
                        {translate('text_65ae73ebe3a66bec2b91d72d')}
                      </Button>
                    </div>
                  )}
                  <field.RadioField
                    labelVariant="body"
                    disabled={!isPremium}
                    value={ExpirationValuesEnum.OneHour}
                    label={translate(ExpirationValuesTranslationLookup.OneHour)}
                  />
                  <field.RadioField
                    labelVariant="body"
                    disabled={!isPremium}
                    value={ExpirationValuesEnum.OneDay}
                    label={translate(ExpirationValuesTranslationLookup.OneDay)}
                  />
                  <field.RadioField
                    labelVariant="body"
                    disabled={!isPremium}
                    value={ExpirationValuesEnum.TwoDays}
                    label={translate(ExpirationValuesTranslationLookup.TwoDays)}
                  />
                  <field.RadioField
                    labelVariant="body"
                    disabled={!isPremium}
                    value={ExpirationValuesEnum.OneWeek}
                    label={translate(ExpirationValuesTranslationLookup.OneWeek)}
                  />
                </>
              )}
            </form.AppField>
          </div>
        </div>
      </div>
    </Dialog>
  )
})

RotateApiKeyDialog.displayName = 'RotateApiKeyDialog'
