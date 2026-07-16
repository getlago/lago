import { useCallback } from 'react'

import { envGlobalVar, updateIntlLocale, useInternationalizationVar } from '~/core/apolloClient'
import { Locale, TranslateData, translateKey } from '~/core/translations'

const { appEnv } = envGlobalVar()

export type TranslateFunc = (key: string, data?: TranslateData, plural?: number) => string

type UseInternationalization = () => {
  locale: Locale
  translate: TranslateFunc
  updateLocale: (locale: Locale) => void
}

export const useInternationalization: UseInternationalization = () => {
  const { translations, locale } = useInternationalizationVar()

  return {
    locale,
    translate: useCallback(
      (key, data, plural = 0) => {
        return translateKey({ translations, locale, appEnv }, key, data, plural)
      },
      [translations, locale],
    ),
    updateLocale: updateIntlLocale,
  }
}
