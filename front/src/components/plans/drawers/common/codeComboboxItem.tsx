import { Typography } from '~/components/designSystem/Typography'
import { ComboboxItem } from '~/components/form'

// Builds the shared `${name} (${code})` combobox option used by the add-on and
// billable-metric selectors, with a two-line name/code label node. Callers may
// spread the result and add extra keys (e.g. `group` for the grouped metric list).
export const buildCodeComboboxItem = ({
  id,
  name,
  code,
}: {
  id: string
  name: string
  code: string
}) => ({
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
})
