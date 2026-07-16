import { gql } from '@apollo/client'
import { useEffect, useMemo, useRef } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { useFormDialog } from '~/components/dialogs/FormDialog'
import { ComboboxItem } from '~/components/form'
import {
  BillableMetricsForCouponsFragment,
  BillableMetricsForCouponsFragmentDoc,
  useGetBillableMetricsForCouponsLazyQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm } from '~/hooks/forms/useAppform'

import { DialogActionButton, useSetDisabledRef } from './DialogActionButton'

gql`
  fragment BillableMetricsForCoupons on BillableMetric {
    id
    name
    code
  }

  query getBillableMetricsForCoupons($page: Int, $limit: Int, $searchTerm: String) {
    billableMetrics(page: $page, limit: $limit, searchTerm: $searchTerm) {
      collection {
        ...BillableMetricsForCoupons
      }
    }
  }

  ${BillableMetricsForCouponsFragmentDoc}
`

export const ADD_BILLABLE_METRIC_FORM_ID = 'add-billable-metric-to-coupon-form'

interface AddBillableMetricContentProps {
  attachedBillableMetricsIds?: string[]
  onSelect: (billableMetric: BillableMetricsForCouponsFragment | undefined) => void
}

const AddBillableMetricContent = ({
  attachedBillableMetricsIds,
  onSelect,
}: AddBillableMetricContentProps) => {
  const { translate } = useInternationalization()
  const [getBillableMetrics, { loading, data }] = useGetBillableMetricsForCouponsLazyQuery({
    variables: { limit: 50 },
  })

  const form = useAppForm({
    defaultValues: {
      selectedBillableMetric: '',
    },
  })

  useEffect(() => {
    getBillableMetrics()
  }, [getBillableMetrics])

  const comboboxBillableMetricsData = useMemo(() => {
    if (!data || !data?.billableMetrics || !data?.billableMetrics?.collection) return []

    return data?.billableMetrics?.collection.map((billableMetric) => {
      const { id, name, code } = billableMetric

      return {
        label: `${name} (${code})`,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {name}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {code}
            </Typography>
          </ComboboxItem>
        ),
        value: id,
        disabled: attachedBillableMetricsIds?.includes(id),
      }
    })
  }, [data, attachedBillableMetricsIds])

  return (
    <div className="p-8">
      <form.AppField
        name="selectedBillableMetric"
        listeners={{
          onChange: ({ value }) => {
            const billableMetric = data?.billableMetrics?.collection.find((b) => b.id === value)

            onSelect(value ? billableMetric : undefined)
          },
        }}
      >
        {(field) => (
          <field.ComboBoxField
            className="mb-8"
            data={comboboxBillableMetricsData}
            label={translate('text_64352657267c3d916f962757')}
            loading={loading}
            placeholder={translate('text_64352657267c3d916f96275d')}
            PopperProps={{ displayInDialog: true }}
            searchQuery={getBillableMetrics}
          />
        )}
      </form.AppField>
      <Alert type="warning">{translate('text_64352657267c3d916f962763')}</Alert>
    </div>
  )
}

interface OpenAddBillableMetricToCouponDialogParams {
  onSubmit: (billableMetric: BillableMetricsForCouponsFragment) => void
  attachedBillableMetricsIds?: string[]
}

export const useAddBillableMetricToCouponDialog = () => {
  const formDialog = useFormDialog()
  const { translate } = useInternationalization()
  const selectedBillableMetricRef = useRef<BillableMetricsForCouponsFragment | undefined>()
  const setDisabledRef = useSetDisabledRef()

  const openAddBillableMetricToCouponDialog = ({
    attachedBillableMetricsIds,
    onSubmit,
  }: OpenAddBillableMetricToCouponDialogParams) => {
    selectedBillableMetricRef.current = undefined

    formDialog.open({
      title: translate('text_64352657267c3d916f96274b'),
      description: translate('text_64352657267c3d916f962751'),
      closeOnError: false,
      children: (
        <AddBillableMetricContent
          attachedBillableMetricsIds={attachedBillableMetricsIds}
          onSelect={(billableMetric) => {
            selectedBillableMetricRef.current = billableMetric
            setDisabledRef.current(!billableMetric)
          }}
        />
      ),
      mainAction: (
        <DialogActionButton
          label={translate('text_64352657267c3d916f96276f')}
          setDisabledRef={setDisabledRef}
        />
      ),
      form: {
        id: ADD_BILLABLE_METRIC_FORM_ID,
        submit: () => {
          if (!selectedBillableMetricRef.current) {
            throw new Error('No billable metric selected')
          }
          onSubmit(selectedBillableMetricRef.current)
        },
      },
    })
  }

  return { openAddBillableMetricToCouponDialog }
}
