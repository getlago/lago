import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { DocumentLocales, LocaleEnum } from '~/core/translations'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles'

const mapLanguageKey = (language: LocaleEnum) => {
  switch (language) {
    case LocaleEnum.de:
      return 'text_6437d8583c62bc00c393d923'
    case LocaleEnum.es:
      return 'text_6526cbd3aedb8800aed06c3d'
    case LocaleEnum.fr:
      return 'text_640a0b75228ef90063296ea4'
    case LocaleEnum.it:
      return 'text_64e4ce3b2fa8940053c8a583'
    case LocaleEnum.nb:
      return 'text_640a0b75228ef90063296eb5'
    case LocaleEnum['pt-BR']:
      return 'text_66b7d0d955677300665ac8d0'
    case LocaleEnum.sv:
      return 'text_6526cd088700e000714f0025'
    case LocaleEnum['zh-TW']:
      return 'text_64188b3d9735d5007d712241'
    default:
      return 'text_6407684eaf41130074c4b2f7'
  }
}

interface LanguageSettingsButtonProps {
  language: LocaleEnum
  onChange: (language: LocaleEnum) => void
}

export const LanguageSettingsButton: FC<LanguageSettingsButtonProps> = ({ language, onChange }) => {
  const { translate } = useInternationalization()
  const availableLanguages = Object.keys(DocumentLocales) as LocaleEnum[]

  return (
    <Popper
      PopperProps={{ placement: 'bottom-end' }}
      opener={
        <Button variant="quaternary" endIcon="chevron-down">
          {translate(mapLanguageKey(language))}
        </Button>
      }
    >
      {({ closePopper }) => (
        <MenuPopper>
          {availableLanguages.map((locale) => (
            <Button
              key={locale}
              align="left"
              variant={language === locale ? 'secondary' : 'quaternary'}
              onClick={() => {
                onChange(locale)
                closePopper()
              }}
            >
              {translate(mapLanguageKey(locale))}
            </Button>
          ))}
        </MenuPopper>
      )}
    </Popper>
  )
}
