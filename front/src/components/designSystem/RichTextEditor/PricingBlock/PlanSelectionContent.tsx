import { useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { ComboboxItem } from '~/components/form'
import { ComboBox } from '~/components/form/ComboBox/ComboBox'
import { usePlansQuery } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { pricingDrawerDefaultValues } from './constants'

const PlanSelectionContent = withForm({
  defaultValues: pricingDrawerDefaultValues,
  render: function PlanSelectionContentRender({ form }) {
    const { translate } = useInternationalization()

    const { data: plansData, loading: plansLoading } = usePlansQuery({
      variables: { limit: 100 },
      fetchPolicy: 'network-only',
      nextFetchPolicy: 'network-only',
    })

    const plans = useMemo(() => plansData?.plans?.collection ?? [], [plansData])

    const comboBoxData = plans.map((plan) => ({
      value: plan.id,
      label: `${plan.name} (${plan.code})`,
      labelNode: (
        <ComboboxItem>
          <Typography variant="body" color="grey700" noWrap>
            {plan.name}
          </Typography>
          <Typography variant="caption" color="grey600" noWrap>
            {plan.code}
          </Typography>
        </ComboboxItem>
      ),
    }))

    return (
      <form.AppField name="planId">
        {(field) => (
          <ComboBox
            data={comboBoxData}
            loading={plansLoading}
            value={field.state.value}
            name={field.name}
            label={translate('text_63d3a658c6d84a5843032145')}
            placeholder={translate('text_63d3a658c6d84a5843032147')}
            onChange={(value) => field.handleChange(value)}
          />
        )}
      </form.AppField>
    )
  },
})

export default PlanSelectionContent
