import {
  GenericPlaceholder,
  GenericPlaceholderProps,
} from '~/components/designSystem/GenericPlaceholder'
import { useNavigate } from '~/core/router'
import { MappableTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import EmptyImage from '~/public/images/maneki/empty.svg'

import { FetchableIntegrationItemEmptyProps } from './types'

const FetchableIntegrationItemEmpty = ({
  hasSearchTerm,
  type,
  createRoute,
}: FetchableIntegrationItemEmptyProps) => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()

  const placeholderPropsMapPerTypePerHasSearchTerm = {
    true: {
      [MappableTypeEnum.AddOn]: {
        title: translate('text_63bee4e10e2d53912bfe4da5'),
        subtitle: translate('text_63bee4e10e2d53912bfe4da7'),
      },
      [MappableTypeEnum.BillableMetric]: {
        title: translate('text_629728388c4d2300e2d380d5'),
        subtitle: translate('text_63bab307a61c62af497e0599'),
      },
    },
    false: {
      [MappableTypeEnum.AddOn]: {
        title: translate('text_629728388c4d2300e2d380c9'),
        subtitle: translate('text_629728388c4d2300e2d380df'),
        buttonTitle: translate('text_629728388c4d2300e2d3810f'),
        buttonVariant: 'primary',
        buttonAction: () => navigate(createRoute),
      },
      [MappableTypeEnum.BillableMetric]: {
        title: translate('text_623b53fea66c76017eaebb70'),
        subtitle: translate('text_623b53fea66c76017eaebb78'),
        buttonTitle: translate('text_623b53fea66c76017eaebb7c'),
        buttonVariant: 'primary',
        buttonAction: () => navigate(createRoute),
      },
    },
  } as const

  const getPlaceholderProps = (): Omit<GenericPlaceholderProps, 'image'> => {
    return placeholderPropsMapPerTypePerHasSearchTerm[`${hasSearchTerm}`][type]
  }

  return (
    <GenericPlaceholder
      image={<EmptyImage width="136" height="104" />}
      {...getPlaceholderProps()}
    />
  )
}

export default FetchableIntegrationItemEmpty
