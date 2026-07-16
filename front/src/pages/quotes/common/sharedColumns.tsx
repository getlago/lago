import { TableColumn } from '~/components/designSystem/Table/Table'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

export const useSharedColumns = () => {
  const { translate } = useInternationalization()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()

  return {
    getNumberColumn: <T extends { number: string }>(titleKey: string): TableColumn<T> => ({
      key: 'number' as TableColumn<T>['key'],
      title: translate(titleKey),
      minWidth: 160,
      maxSpace: true,
      content: ({ number }) => (
        <Typography variant="bodyHl" noWrap>
          {number}
        </Typography>
      ),
    }),
    getCustomerColumn: <
      T extends { customer: { displayName?: string | null } },
    >(): TableColumn<T> => ({
      key: 'customer.displayName' as TableColumn<T>['key'],
      title: translate('text_65201c5a175a4b0238abf29a'),
      minWidth: 160,
      maxSpace: true,
      content: ({ customer }) => (
        <Typography color="grey600" noWrap>
          {customer.displayName}
        </Typography>
      ),
    }),
    getCreatedAtColumn: <T extends { createdAt: string }>(
      titleKey: string,
      minWidth = 160,
    ): TableColumn<T> => ({
      key: 'createdAt' as TableColumn<T>['key'],
      title: translate(titleKey),
      minWidth,
      content: ({ createdAt }) => (
        <Typography color="grey600">{intlFormatDateTimeOrgaTZ(createdAt).date}</Typography>
      ),
    }),
  }
}
