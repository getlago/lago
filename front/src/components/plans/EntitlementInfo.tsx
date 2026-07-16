import { useMemo } from 'react'

import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Typography } from '~/components/designSystem/Typography'
import { getEntitlementFormattedValue } from '~/components/plans/utils'
import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

type EntitlementPrivilege = {
  code: string
  name?: string | null
  value: string
  valueType: PrivilegeValueTypeEnum
  [key: string]: unknown
}

type EntitlementInfoProps = {
  entitlement: {
    code: string
    name?: string | null
    privileges: Array<EntitlementPrivilege>
  }
}

export const EntitlementInfo = ({ entitlement }: EntitlementInfoProps) => {
  const { translate } = useInternationalization()

  const columns = useMemo(
    () => [
      {
        size: 190,
        title: (
          <Typography variant="captionHl" className="px-4">
            {translate('text_175386422306019wldpp8h5q')}
          </Typography>
        ),
        content: (row: EntitlementPrivilege) => (
          <Typography variant="body" color="grey700" className="px-4">
            {row.name || row.code}
          </Typography>
        ),
      },
      {
        size: 190,
        title: (
          <Typography variant="captionHl" className="px-4">
            {translate('text_63fcc3218d35b9377840f5ab')}
          </Typography>
        ),
        content: (row: EntitlementPrivilege) => (
          <Typography variant="body" color="grey700" className="px-4">
            {getEntitlementFormattedValue(row.value, row.valueType, translate)}
          </Typography>
        ),
      },
    ],
    [translate],
  )

  return (
    <div className="flex flex-col gap-4 overflow-x-auto">
      <Typography variant="captionHl" color="grey700">
        {translate('text_1754570508183nhpg3qqdpt8')}
      </Typography>

      {!entitlement.privileges.length && (
        <Typography variant="body" color="grey700">
          {translate('text_1754570508183hxl33n573yk')}
        </Typography>
      )}

      {!!entitlement.privileges.length && (
        <ChargeTable
          className="w-full"
          name={`feature-entitlement-${entitlement.code}-privilege-table`}
          data={entitlement.privileges}
          columns={columns}
        />
      )}
    </div>
  )
}
