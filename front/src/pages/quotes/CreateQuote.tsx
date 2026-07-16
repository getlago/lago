import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useCallback, useMemo } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useCentralizedDialog } from '~/components/dialogs/CentralizedDialog'
import { ComboboxItem } from '~/components/form'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { QUOTES_LIST_ROUTE, useNavigate } from '~/core/router'
import {
  CurrencyEnum,
  OrderTypeEnum,
  StatusTypeEnum,
  useGetCustomersForCreateQuoteLazyQuery,
  useGetCustomerSubscriptionsForCreateQuoteLazyQuery,
  useGetMembersForCreateQuoteQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { getQuoteOrderTypeTranslationKey } from './common/getQuoteOrderTypeTranslationKey'
import { getQuoteTypeDescriptionTranslationKey } from './common/getQuoteTypeDescriptionTranslationKey'
import { type CreateQuoteFormValues, createQuoteSchema } from './createQuote/validationSchema'
import { useCreateQuote } from './hooks/useCreateQuote'

export const CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID = 'create-quote-customer-combobox'
export const CREATE_QUOTE_ORDER_TYPE_TEST_ID = 'create-quote-order-type'
export const CREATE_QUOTE_CURRENCY_COMBOBOX_TEST_ID = 'create-quote-currency-combobox'
export const CREATE_QUOTE_SUBSCRIPTION_COMBOBOX_TEST_ID = 'create-quote-subscription-combobox'
export const CREATE_QUOTE_OWNERS_COMBOBOX_TEST_ID = 'create-quote-owners-combobox'
export const CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID = 'create-quote-submit-button'

gql`
  query getCustomersForCreateQuote($page: Int, $limit: Int, $searchTerm: String) {
    customers(page: $page, limit: $limit, searchTerm: $searchTerm) {
      collection {
        id
        displayName
        externalId
        currency
      }
    }
  }

  query getCustomerSubscriptionsForCreateQuote($customerId: ID!) {
    customer(id: $customerId) {
      id
      subscriptions {
        id
        name
        externalId
        status
        plan {
          id
          name
          code
        }
      }
    }
  }

  query getMembersForCreateQuote($page: Int, $limit: Int) {
    memberships(page: $page, limit: $limit) {
      collection {
        id
        user {
          id
          email
        }
      }
    }
  }
`

const defaultValues: CreateQuoteFormValues = {
  customerId: '',
  orderType: OrderTypeEnum.SubscriptionCreation,
  subscriptionId: '',
  owners: undefined,
  currency: undefined,
}

const CreateQuote = (): JSX.Element => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const warningDialog = useCentralizedDialog()
  const { onSave, loading: mutationLoading } = useCreateQuote()

  const [getCustomers, { data: customersData, loading: customersLoading }] =
    useGetCustomersForCreateQuoteLazyQuery({
      variables: { page: 1, limit: 50 },
    })

  const [getCustomerSubscriptions, { data: subscriptionsData, loading: subscriptionsLoading }] =
    useGetCustomerSubscriptionsForCreateQuoteLazyQuery()

  const { data: membersData, loading: membersLoading } = useGetMembersForCreateQuoteQuery({
    variables: { page: 1, limit: 100 },
  })

  const form = useAppForm({
    defaultValues,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: createQuoteSchema,
    },
    onSubmit: async ({ value }) => {
      await onSave({
        customerId: value.customerId,
        orderType: value.orderType,
        subscriptionId: value.subscriptionId || undefined,
        owners: value.owners?.map((owner) => owner.value),
        currency: value.currency,
        customerExternalId: selectedCustomer?.externalId ?? '',
        hasCustomerCurrency,
      })
    },
  })

  const customerId = useStore(form.store, (state) => state.values.customerId)
  const orderType = useStore(form.store, (state) => state.values.orderType)
  const isDirty = useStore(form.store, (state) => state.isDirty)

  const comboboxCustomersData = useMemo(() => {
    if (!customersData?.customers?.collection) return []

    return customersData.customers.collection.map((customer) => ({
      label: customer.displayName || customer.externalId || '',
      labelNode: (
        <ComboboxItem>
          <Typography variant="body" color="grey700" noWrap>
            {customer.displayName || customer.externalId || ''}
          </Typography>
          {customer.externalId && (
            <Typography variant="caption" color="grey600" noWrap>
              {customer.externalId}
            </Typography>
          )}
        </ComboboxItem>
      ),
      value: customer.id,
    }))
  }, [customersData?.customers?.collection])

  const selectedCustomer = useMemo(() => {
    if (!customerId || !customersData?.customers?.collection) return null
    return customersData.customers.collection.find((c) => c.id === customerId) ?? null
  }, [customerId, customersData?.customers?.collection])

  const hasCustomerCurrency = !!selectedCustomer?.currency

  const currencyOptions = useMemo(() => {
    if (!selectedCustomer?.currency) {
      return Object.values(CurrencyEnum).map((currencyType) => ({ value: currencyType }))
    }
    return [{ value: selectedCustomer.currency }]
  }, [selectedCustomer?.currency])

  const comboboxOwnersData = useMemo(() => {
    if (!membersData?.memberships?.collection) return []

    return membersData.memberships.collection
      .filter((membership) => !!membership.user.email)
      .map((membership) => ({
        label: membership.user.email as string,
        value: membership.user.id,
      }))
  }, [membersData?.memberships?.collection])

  const comboboxSubscriptionsData = useMemo(() => {
    if (!subscriptionsData?.customer?.subscriptions) return []

    return subscriptionsData.customer.subscriptions
      .filter((sub) => sub.status === StatusTypeEnum.Active)
      .map((subscription) => ({
        label: subscription.name || subscription.plan.name,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {subscription.name || subscription.plan.name}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {subscription.externalId}
            </Typography>
          </ComboboxItem>
        ),
        value: subscription.id,
      }))
  }, [subscriptionsData?.customer?.subscriptions])

  const handleClose = useCallback(() => {
    if (isDirty) {
      warningDialog.open({
        title: translate('text_665deda4babaf700d603ea13'),
        description: translate('text_665dedd557dc3c00c62eb83d'),
        actionText: translate('text_645388d5bdbd7b00abffa033'),
        colorVariant: 'danger',
        onAction: () => navigate(QUOTES_LIST_ROUTE),
      })
    } else {
      navigate(QUOTES_LIST_ROUTE)
    }
  }, [isDirty, navigate, warningDialog, translate])

  const orderTypeOptions = useMemo(
    () =>
      [
        {
          label: translate(getQuoteOrderTypeTranslationKey(OrderTypeEnum.SubscriptionCreation)),
          value: OrderTypeEnum.SubscriptionCreation,
        },
        {
          label: translate(getQuoteOrderTypeTranslationKey(OrderTypeEnum.SubscriptionAmendment)),
          value: OrderTypeEnum.SubscriptionAmendment,
        },
        {
          label: translate(getQuoteOrderTypeTranslationKey(OrderTypeEnum.OneOff)),
          value: OrderTypeEnum.OneOff,
        },
      ].map((option) => ({
        ...option,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {option.label}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {translate(getQuoteTypeDescriptionTranslationKey(option.value))}
            </Typography>
          </ComboboxItem>
        ),
      })),
    [translate],
  )

  const handleSubmit = (e: React.FormEvent): void => {
    e.preventDefault()
    form.handleSubmit()
  }

  return (
    <>
      <CenteredPage.Wrapper>
        <form
          id="create-quote"
          className="flex size-full min-h-full flex-col overflow-auto"
          onSubmit={handleSubmit}
        >
          <CenteredPage.Header>
            <Typography variant="bodyHl" color="textSecondary" noWrap>
              {translate('text_1776330750402hykqn73y0j4')}
            </Typography>
            <Button variant="quaternary" icon="close" onClick={handleClose} />
          </CenteredPage.Header>

          <CenteredPage.Container>
            <CenteredPage.SectionWrapper>
              <CenteredPage.PageTitle
                title={translate('text_1776238919927a1b2c3d4e5f')}
                description={translate('text_1776330750403sv23qvgefob')}
              />

              <div className="flex flex-col gap-6">
                <div className="flex flex-col gap-2">
                  <Typography variant="subhead1">
                    {translate('text_1776330750403pg99mcn8en5')}
                  </Typography>
                  <Typography variant="caption">
                    {translate('text_1776330750403fljblm2majw')}
                  </Typography>
                </div>
                <form.AppField
                  name="customerId"
                  listeners={{
                    onChange: ({ value }) => {
                      form.setFieldValue('subscriptionId', '')

                      if (value) {
                        getCustomerSubscriptions({ variables: { customerId: value } })
                        const customer = customersData?.customers?.collection?.find(
                          (c) => c.id === value,
                        )

                        form.setFieldValue('currency', customer?.currency ?? undefined)
                      } else {
                        form.setFieldValue('currency', undefined)
                      }
                    },
                  }}
                >
                  {(field) => (
                    <field.ComboBoxField
                      dataTest={CREATE_QUOTE_CUSTOMER_COMBOBOX_TEST_ID}
                      label={translate('text_1776238919927l1m2n3o4p5q')}
                      placeholder={translate('text_1776238919927r6s7t8u9v0w')}
                      data={comboboxCustomersData}
                      loading={customersLoading}
                      searchQuery={getCustomers}
                    />
                  )}
                </form.AppField>

                {customerId && (
                  <form.AppField name="currency">
                    {(field) => (
                      <field.ComboBoxField
                        dataTest={CREATE_QUOTE_CURRENCY_COMBOBOX_TEST_ID}
                        disabled={hasCustomerCurrency}
                        disableClearable
                        label={translate('text_632b4acf0c41206cbcb8c324')}
                        data={currencyOptions}
                      />
                    )}
                  </form.AppField>
                )}

                <form.AppField
                  name="orderType"
                  listeners={{
                    onChange: ({ value }) => {
                      form.setFieldValue('subscriptionId', '')

                      if (value === OrderTypeEnum.SubscriptionAmendment && customerId) {
                        getCustomerSubscriptions({ variables: { customerId } })
                      }
                    },
                  }}
                >
                  {(field) => (
                    <field.ComboBoxField
                      dataTest={CREATE_QUOTE_ORDER_TYPE_TEST_ID}
                      disableClearable
                      label={translate('text_1776238919927x1y2z3a4b5c')}
                      data={orderTypeOptions}
                    />
                  )}
                </form.AppField>

                {orderType === OrderTypeEnum.SubscriptionAmendment && (
                  <form.AppField name="subscriptionId">
                    {(field) => (
                      <field.ComboBoxField
                        dataTest={CREATE_QUOTE_SUBSCRIPTION_COMBOBOX_TEST_ID}
                        label={translate('text_1776238919927d6e7f8g9h0i')}
                        placeholder={translate('text_1776238919927j1k2l3m4n5o')}
                        data={comboboxSubscriptionsData}
                        loading={subscriptionsLoading}
                        emptyText={translate('text_1776238919927b6c7d8e9f0g')}
                      />
                    )}
                  </form.AppField>
                )}

                <form.AppField name="owners">
                  {(field) => (
                    <field.MultipleComboBoxField
                      dataTest={CREATE_QUOTE_OWNERS_COMBOBOX_TEST_ID}
                      label={translate('text_1776429591588dnpx1guz0cl')}
                      placeholder={translate('text_1776429591588ale04shf9wf')}
                      data={comboboxOwnersData}
                      loading={membersLoading}
                      disableCloseOnSelect
                    />
                  )}
                </form.AppField>
              </div>
            </CenteredPage.SectionWrapper>
          </CenteredPage.Container>

          <CenteredPage.StickyFooter>
            <Button variant="quaternary" onClick={handleClose}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <form.AppForm>
              <form.SubmitButton
                size="large"
                disabled={mutationLoading}
                dataTest={CREATE_QUOTE_SUBMIT_BUTTON_TEST_ID}
              >
                {translate('text_1776238919927p6q7r8s9t0u')}
              </form.SubmitButton>
            </form.AppForm>
          </CenteredPage.StickyFooter>
        </form>
      </CenteredPage.Wrapper>
    </>
  )
}

export default CreateQuote
