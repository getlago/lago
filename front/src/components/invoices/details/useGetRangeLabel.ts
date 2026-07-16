import { useInternationalization } from '~/hooks/core/useInternationalization'

export const useGetRangeLabel = () => {
  const { translate } = useInternationalization()

  const getRangeLabel = (
    index: number,
    totalLength: number,
    fromValue: number,
    toValue: number,
    isFlat: boolean,
  ) => {
    if (totalLength === 1) {
      return translate(isFlat ? 'text_659e67cd63512ef53284314a' : 'text_659e67cd63512ef5328430e6', {
        fromValue,
      })
    }

    if (index === 0) {
      return translate(isFlat ? 'text_659e67cd63512ef53284310e' : 'text_659e67cd63512ef532843070', {
        toValue,
      })
    }

    if (index === totalLength - 1) {
      return translate(isFlat ? 'text_659e67cd63512ef53284314a' : 'text_659e67cd63512ef5328430e6', {
        fromValue,
      })
    }

    return translate(isFlat ? 'text_659e67cd63512ef532843136' : 'text_659e67cd63512ef5328430af', {
      fromValue,
      toValue,
    })
  }

  return { getRangeLabel }
}
