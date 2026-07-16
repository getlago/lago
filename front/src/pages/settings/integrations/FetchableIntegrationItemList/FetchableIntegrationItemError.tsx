import {
  GenericPlaceholder,
  GenericPlaceholderProps,
} from '~/components/designSystem/GenericPlaceholder'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import ErrorImage from '~/public/images/maneki/error.svg'

import { FetchableIntegrationItemErrorProps } from './types'

const FetchableIntegrationItemError = ({ hasSearchTerm }: FetchableIntegrationItemErrorProps) => {
  const { translate } = useInternationalization()

  const getPlaceholderProps = (): Omit<GenericPlaceholderProps, 'image'> => {
    return hasSearchTerm
      ? {
          title: translate('text_623b53fea66c76017eaebb6e'),
          subtitle: translate('text_63bab307a61c62af497e0599'),
        }
      : {
          title: translate('text_629728388c4d2300e2d380d5'),
          subtitle: translate('text_629728388c4d2300e2d380eb'),
          buttonTitle: translate('text_629728388c4d2300e2d38110'),
          buttonVariant: 'primary',
          buttonAction: () => location.reload(),
        }
  }

  return (
    <GenericPlaceholder
      image={<ErrorImage width="136" height="104" />}
      {...getPlaceholderProps()}
    />
  )
}

export default FetchableIntegrationItemError
