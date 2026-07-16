import { captureMessage } from '@sentry/react'

import { AppEnvEnum } from '~/core/constants/globalTypes'

import { Locale, LocaleEnum, TranslateData, Translation, Translations } from './types'

export const getTranslations: (locale: Locale) => Promise<Record<string, string>> = async (
  locale,
) => {
  let loadedTranslation: Translation

  // Translations are dinamically imported according to the selected locale
  try {
    loadedTranslation = (await import(`../../../translations/${locale}.json`)) as Translation
  } catch {
    loadedTranslation = (await import(`../../../translations/base.json`)) as unknown as Translation
  }

  return loadedTranslation
}

export function replaceDynamicVarInString(template: string, data: TranslateData) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => String(data[key]))
}

export function getPluralTranslation(template: string, plural: number) {
  // Translations are defined on the following base : "none | unique | plural" or "unique | plural"
  const splitted = template.split('|')

  switch (true) {
    case splitted.length < 2:
      return template
    case splitted.length === 2:
      return plural < 2 ? splitted[0] : splitted[1]
    default:
      return splitted[plural] || splitted.slice(-1)[0]
  }
}

export const translateKey: (
  context: {
    translations: Translations
    locale: Locale
    appEnv: AppEnvEnum
  },
  key: string,
  data?: TranslateData,
  plural?: number,
) => string = ({ translations, locale, appEnv }, key, data, plural = 0) => {
  // `translations` is `undefined` until the locale file finishes loading. Use that as
  // the "not ready" sentinel instead of an emptiness check: the object holds thousands
  // of keys and is in dictionary mode, so `Object.keys(translations)` would allocate the
  // full key array on every single translate() call (hot path, called thousands of times
  // per render) just to test for emptiness.
  if (!translations) {
    return ''
  }

  if (!translations[key]) {
    const translationErrorMessage = `Translation '${key}' for locale '${locale}' not found.`

    // We decide to capture the error in production only for non english locale
    if (appEnv === AppEnvEnum.production && locale !== LocaleEnum.en) {
      const customStack = new Error().stack

      captureMessage(translationErrorMessage, {
        level: 'warning',
        extra: {
          customStack,
        },
      })
    } else if ([AppEnvEnum.qa, AppEnvEnum.development].includes(appEnv)) {
      // eslint-disable-next-line no-console
      console.warn(translationErrorMessage)
    }
    return key
  }

  const translation = getPluralTranslation(translations[key], plural)

  return data ? replaceDynamicVarInString(translation, data) : translation
}
