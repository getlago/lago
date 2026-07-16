import { useCallback, useEffect, useState } from 'react'

import { envGlobalVar } from '~/core/apolloClient'
import {
  getTranslations,
  Locale,
  TranslateData,
  translateKey,
  Translation,
} from '~/core/translations'

const { appEnv } = envGlobalVar()

// Simple module-level cache for contextual translations
const contextualTranslationCache = new Map<Locale, Translation>()

type UseContextualLocale = (locale: Locale) => {
  translateWithContextualLocal: (key: string, data?: TranslateData, plural?: number) => string
}

export const useContextualLocale: UseContextualLocale = (locale) => {
  const [translations, setTranslations] = useState<Translation | undefined>(() =>
    contextualTranslationCache.get(locale),
  )

  useEffect(() => {
    if (contextualTranslationCache.has(locale)) {
      setTranslations(contextualTranslationCache.get(locale))
      return
    }

    getTranslations(locale).then((loadedTranslations) => {
      contextualTranslationCache.set(locale, loadedTranslations)
      setTranslations(loadedTranslations)
    })
  }, [locale])

  return {
    translateWithContextualLocal: useCallback(
      (key, data, plural = 0) => {
        return translateKey({ translations, locale, appEnv }, key, data, plural)
      },
      [translations, locale],
    ),
  }
}
