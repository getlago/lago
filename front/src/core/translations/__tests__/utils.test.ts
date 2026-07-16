import { AppEnvEnum } from '~/core/constants/globalTypes'
import { LocaleEnum } from '~/core/translations/types'
import {
  getPluralTranslation,
  replaceDynamicVarInString,
  translateKey,
} from '~/core/translations/utils'

describe('utils', () => {
  describe('translateKey', () => {
    const baseContext = {
      locale: LocaleEnum.en,
      appEnv: AppEnvEnum.development,
    }

    describe('when translations are not loaded yet', () => {
      it('returns an empty string for undefined translations', () => {
        expect(translateKey({ ...baseContext, translations: undefined }, 'any_key')).toEqual('')
      })
    })

    describe('when the key exists', () => {
      it('returns the matching translation', () => {
        expect(
          translateKey({ ...baseContext, translations: { greeting: 'Hello' } }, 'greeting'),
        ).toEqual('Hello')
      })

      it('interpolates dynamic variables', () => {
        expect(
          translateKey(
            { ...baseContext, translations: { greeting: 'Hello {{name}}' } },
            'greeting',
            { name: 'World' },
          ),
        ).toEqual('Hello World')
      })

      it('resolves the plural form', () => {
        expect(
          translateKey(
            { ...baseContext, translations: { items: 'one|many' } },
            'items',
            undefined,
            2,
          ),
        ).toEqual('many')
      })
    })

    describe('when the key is missing', () => {
      it('returns the key itself', () => {
        expect(
          translateKey({ ...baseContext, translations: { greeting: 'Hello' } }, 'missing_key'),
        ).toEqual('missing_key')
      })
    })
  })

  describe('getPluralTranslation', () => {
    describe('when the template has no none', () => {
      it('returns singular for 0', () => {
        expect(getPluralTranslation('singular|plural', 0)).toEqual('singular')
      })
      it('returns singular for 1', () => {
        expect(getPluralTranslation('singular|plural', 1)).toEqual('singular')
      })
      it('returns plural for 2', () => {
        expect(getPluralTranslation('singular|plural', 2)).toEqual('plural')
      })
      it('returns plural for more than 2', () => {
        expect(
          getPluralTranslation('singular|plural', Math.round(Math.random() * 100) + 2),
        ).toEqual('plural')
      })
    })

    describe('when the template has none', () => {
      it('returns none for 0', () => {
        expect(getPluralTranslation('none|singular|plural', 0)).toEqual('none')
      })
      it('returns singular for 1', () => {
        expect(getPluralTranslation('none|singular|plural', 1)).toEqual('singular')
      })
      it('returns plural for 2', () => {
        expect(getPluralTranslation('none|singular|plural', 2)).toEqual('plural')
      })
      it('returns plural for more than 2', () => {
        expect(
          getPluralTranslation('none|singular|plural', Math.round(Math.random() * 100) + 2),
        ).toEqual('plural')
      })
    })
  })

  describe('replaceDynamicVarInString', () => {
    it('replaces the dynamic variable', () => {
      expect(replaceDynamicVarInString('Hello {{name}}', { name: 'World' })).toEqual('Hello World')
    })
    it('replaces the dynamic variable multiple times', () => {
      expect(replaceDynamicVarInString('Hello {{name}}, {{name}}', { name: 'World' })).toEqual(
        'Hello World, World',
      )
    })
    it('replaces the dynamic variabled with multiple words', () => {
      expect(replaceDynamicVarInString('Hello {{name}}', { name: 'World Peace' })).toEqual(
        'Hello World Peace',
      )
    })
    it('replaces the dynamic variable with numbers', () => {
      expect(replaceDynamicVarInString('Hello {{name}}', { name: 123 })).toEqual('Hello 123')
    })
    it('replaces multiple dynamic variable', () => {
      expect(
        replaceDynamicVarInString('Hello {{firstName}} {{lastName}}', {
          firstName: 'John',
          lastName: 'Doe',
        }),
      ).toEqual('Hello John Doe')
    })
  })
})
