import { type CheckboxGroup, type FieldGroupApi, GroupedCheckboxList } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withFieldGroup } from '~/hooks/forms/useAppform'

type WebhookEventsFormProps = {
  groups: CheckboxGroup[]
  isEditable?: boolean
  isLoading?: boolean
  errors?: Array<string>
}

const defaultProps: WebhookEventsFormProps = {
  groups: [],
  isEditable: true,
  isLoading: false,
  errors: [],
}

type WebhookEventValues = Record<string, boolean>

const WebhookEventsForm = withFieldGroup({
  defaultValues: {},
  props: defaultProps,
  render: function Render({ group, groups, isLoading, errors }) {
    const { translate } = useInternationalization()

    // Cast to FieldGroupApi - the TanStack Form group API is structurally compatible
    // but has more complex generic types that don't align directly
    const typedGroup = group as unknown as FieldGroupApi<WebhookEventValues>

    return (
      <GroupedCheckboxList
        group={typedGroup}
        title={translate('text_1770822522307127vc3bt81b')}
        subtitle={translate('text_1770822522308ndyb2bewmvs')}
        searchPlaceholder={translate('text_1770822522308u2ptsqw79ns')}
        groups={groups}
        isLoading={isLoading}
        errors={errors}
        itemLabelVariant="captionCode"
      />
    )
  },
})

export default WebhookEventsForm
