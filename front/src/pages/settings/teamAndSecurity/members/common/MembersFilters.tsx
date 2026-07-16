import { Icon } from 'lago-design-system'
import { useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { TextInput } from '~/components/form/TextInput/TextInput'
import { MEMBERS_PAGE_ROLE_FILTER_KEY } from '~/core/constants/roles'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useRoleDisplayInformation } from '~/hooks/useRoleDisplayInformation'
import { useRolesList } from '~/hooks/useRolesList'
import { MenuPopper } from '~/styles'

export type MembersFiltersProps = {
  searchQuery: string
  setSearchQuery: (query: string) => void
  type: 'members' | 'invitations'
}

const MembersFilters = ({ searchQuery, setSearchQuery, type }: MembersFiltersProps) => {
  const { translate } = useInternationalization()
  const { roles } = useRolesList()
  const [searchParams, setSearchParams] = useSearchParams()
  const { getDisplayName } = useRoleDisplayInformation()

  const selectedRole = useMemo(() => {
    return searchParams.get(MEMBERS_PAGE_ROLE_FILTER_KEY)
  }, [searchParams])

  const getSearchPlaceholder = () => {
    if (type === 'members') {
      return translate('text_1767713872664devzn1r2wql')
    }

    return translate('text_1767713872664lwivpxg5xlb')
  }

  const handleRoleFilterChange = (newRole: string | null) => {
    const newSearchParams = new URLSearchParams(searchParams)

    if (newRole) {
      newSearchParams.set(MEMBERS_PAGE_ROLE_FILTER_KEY, newRole)
    } else {
      newSearchParams.delete(MEMBERS_PAGE_ROLE_FILTER_KEY)
    }

    setSearchParams(newSearchParams)
  }

  const getFilterRoleDisplayName = () => {
    if (!selectedRole) {
      return translate('text_1767710145806r6ewupk6dr8')
    }

    return getDisplayName({ name: selectedRole })
  }

  return (
    <div className="flex h-16 items-center justify-between gap-3 shadow-b">
      <Popper
        PopperProps={{ placement: 'bottom-start' }}
        opener={
          <Button variant="secondary" endIcon="chevron-down">
            {getFilterRoleDisplayName()}
          </Button>
        }
      >
        {({ closePopper }) => (
          <MenuPopper>
            <Button
              variant="quaternary"
              align="left"
              onClick={() => {
                handleRoleFilterChange(null)
                closePopper()
              }}
            >
              {translate('text_1767710145806r6ewupk6dr8')}
            </Button>
            {roles.map((role) => (
              <Button
                variant="quaternary"
                align="left"
                key={role.name}
                onClick={() => {
                  handleRoleFilterChange(role.name)
                  closePopper()
                }}
              >
                {getDisplayName({ name: role.name })}
              </Button>
            ))}
          </MenuPopper>
        )}
      </Popper>
      <TextInput
        cleanable
        placeholder={getSearchPlaceholder()}
        value={searchQuery}
        onChange={(value) => {
          setSearchQuery(value)
        }}
        InputProps={{
          startAdornment: <Icon className="ml-4" name="magnifying-glass" />,
        }}
      />
    </div>
  )
}

export default MembersFilters
