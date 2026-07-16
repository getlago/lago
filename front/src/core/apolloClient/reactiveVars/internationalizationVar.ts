import { makeVar, useReactiveVar } from '@apollo/client'

import { getTranslations, Locale, LocaleEnum } from '~/core/translations'
import { getItemFromLS, setItemFromLS } from '~/core/utils/localStorage'

const LOCALE_LS_KEY = 'locale'

interface InternationalizationVar {
  locale: Locale
  translations?: Record<string, string>
}

const internationalizationVar = makeVar<InternationalizationVar>({
  locale: getItemFromLS(LOCALE_LS_KEY) ?? LocaleEnum.en,
  // `undefined` (not `{}`) is the "translations not loaded yet" sentinel so `translateKey`
  // can detect it in O(1) without enumerating the multi-thousand-key translations object.
  translations: undefined,
})

export const initializeTranslations = async () => {
  const { locale } = internationalizationVar()
  const translations = await getTranslations(locale)

  internationalizationVar({
    locale,
    translations,
  })
}

export const updateIntlLocale = async (locale: Locale) => {
  setItemFromLS(LOCALE_LS_KEY, locale)
  const translations = await getTranslations(locale)

  internationalizationVar({
    locale,
    translations,
  })
}

export const useInternationalizationVar = () => useReactiveVar(internationalizationVar)
