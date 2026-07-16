import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { forwardRef } from 'react'
import { mixed, object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { ComboBoxField, RadioField } from '~/components/form'
import { addToast } from '~/core/apolloClient'
import {
  EditCustomerDunningCampaignFragment,
  UpdateCustomerInput,
  useEditCustomerDunningCampaignMutation,
  useGetApplicableDunningCampaignsLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment EditCustomerDunningCampaign on Customer {
    id
    externalId
    currency
    appliedDunningCampaign {
      id
    }
    excludeFromDunningCampaign
  }

  query getApplicableDunningCampaigns($currency: [CurrencyEnum!]) {
    dunningCampaigns(currency: $currency) {
      collection {
        id
        name
        code
      }
    }
  }

  mutation editCustomerDunningCampaign($input: UpdateCustomerInput!) {
    updateCustomer(input: $input) {
      id
      appliedDunningCampaign {
        id
      }
      excludeFromDunningCampaign
    }
  }
`

export enum BehaviorType {
  FALLBACK = 'fallback',
  NEW_CAMPAIGN = 'newCampaign',
  DEACTIVATE = 'deactivate',
}

export const getInitialBehavior = (customer: EditCustomerDunningCampaignFragment): BehaviorType => {
  if (customer.appliedDunningCampaign?.id) return BehaviorType.NEW_CAMPAIGN
  if (customer.excludeFromDunningCampaign) return BehaviorType.DEACTIVATE
  return BehaviorType.FALLBACK
}

export type EditCustomerDunningCampaignDialogRef = DialogRef

interface EditCustomerDunningCampaignDialogProps {
  customer: EditCustomerDunningCampaignFragment
}

export const EditCustomerDunningCampaignDialog = forwardRef<
  DialogRef,
  EditCustomerDunningCampaignDialogProps
>(({ customer }: EditCustomerDunningCampaignDialogProps, ref) => {
  const { translate } = useInternationalization()
  const [getDunningCampaigns, { data, loading }] = useGetApplicableDunningCampaignsLazyQuery({
    variables: {
      currency: customer.currency,
    },
  })

  const [editCustomerDunningCampaignBehavior] = useEditCustomerDunningCampaignMutation({
    refetchQueries: ['getCustomerSettings'],
    onCompleted: () => {
      addToast({
        severity: 'success',
        message: translate('text_17295437652543pf2j5lqe67'),
      })
    },
  })

  const formikProps = useFormik<{
    behavior: BehaviorType | ''
    appliedDunningCampaignId: string
  }>({
    initialValues: {
      behavior: getInitialBehavior(customer),
      appliedDunningCampaignId: customer.appliedDunningCampaign?.id ?? '',
    },
    validationSchema: object().shape({
      behavior: mixed().oneOf(Object.values(BehaviorType)).required(''),
      appliedDunningCampaignId: string().when('behavior', {
        is: (val: BehaviorType) => val === BehaviorType.NEW_CAMPAIGN,
        then: (schema) => schema.required(''),
      }),
    }),
    onSubmit: async (values) => {
      let formattedValues: UpdateCustomerInput = {
        id: customer.id,
        externalId: customer.externalId,
      }

      switch (values.behavior) {
        case BehaviorType.FALLBACK:
          formattedValues = {
            ...formattedValues,
            appliedDunningCampaignId: null,
            excludeFromDunningCampaign: false,
          }
          break
        case BehaviorType.NEW_CAMPAIGN:
          formattedValues = {
            ...formattedValues,
            appliedDunningCampaignId: values.appliedDunningCampaignId,
          }
          break
        case BehaviorType.DEACTIVATE:
          formattedValues = {
            ...formattedValues,
            excludeFromDunningCampaign: true,
          }
          break
      }

      await editCustomerDunningCampaignBehavior({ variables: { input: formattedValues } })
    },
    validateOnMount: true,
    enableReinitialize: true,
  })

  return (
    <Dialog
      ref={ref}
      onOpen={async () => {
        await getDunningCampaigns()
      }}
      title={translate('text_1729543665906svxp253ug1g')}
      description={translate('text_1729543665907gw6pj8jsj3z')}
      actions={({ closeDialog }) => (
        <>
          <Button variant="quaternary" onClick={closeDialog}>
            {translate('text_63ea0f84f400488553caa6a5')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={async () => {
              await formikProps.submitForm()
              closeDialog()
            }}
          >
            {translate('text_17295436903260tlyb1gp1i7')}
          </Button>
        </>
      )}
    >
      <div className="mb-8 not-last-child:mb-4">
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.FALLBACK}
          label={translate('text_1729543665907g5bbnbl8yvr')}
          labelVariant="body"
        />
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.NEW_CAMPAIGN}
          label={translate('text_17295436659071kau9ol0axk')}
          labelVariant="body"
        />
        {formikProps.values.behavior === 'newCampaign' && (
          <ComboBoxField
            name="appliedDunningCampaignId"
            formikProps={formikProps}
            loading={loading}
            data={
              data?.dunningCampaigns.collection.map((campaign) => ({
                label: campaign.name,
                description: campaign.code,
                value: campaign.id,
              })) ?? []
            }
            isEmptyNull={false}
            placeholder={translate('text_1729543690326d4dmmcw7n89')}
            PopperProps={{ displayInDialog: true }}
            emptyText={translate('text_1731078338811aok1u8oopxl')}
          />
        )}
        <RadioField
          name="behavior"
          formikProps={formikProps}
          value={BehaviorType.DEACTIVATE}
          label={translate('text_1729543690326ndlmz7bdmy1')}
          sublabel={translate('text_17295436903267b0kiid8h8r')}
          labelVariant="body"
        />
      </div>
    </Dialog>
  )
})

EditCustomerDunningCampaignDialog.displayName = 'EditCustomerDunningCampaignDialog'
