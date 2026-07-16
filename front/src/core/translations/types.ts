export type TranslateData = Record<string, string | number | undefined | null>

export type Translations = Record<string, string> | undefined

export interface Translation {
  [key: string]: string
}

export enum LocaleEnum {
  en = 'en',
  fr = 'fr', // French
  nb = 'nb', // Norwegian
  de = 'de', // German
  it = 'it', // Italian
  es = 'es', // Spanish
  sv = 'sv', // Swedish
  'pt-BR' = 'pt-BR', // Brazilian Portuguese
  'zh-TW' = 'zh-TW', // Chinese (Traditional)
}
export type Locale = keyof typeof LocaleEnum
