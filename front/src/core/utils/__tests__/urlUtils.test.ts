import { addValuesToUrlState } from '~/core/utils/urlUtils'

describe('urlUtils', () => {
  describe('addValuesToUrlState', () => {
    describe('stateType: object', () => {
      it('should create state with value if not existing', () => {
        const url = 'http://localhost:3000'
        const mode = 'login'
        const result = addValuesToUrlState({
          url,
          stateType: 'object',
          values: { mode, test: 'value' },
        })

        const expectedOutput = '%7B%22mode%22%3A%22login%22%2C%22test%22%3A%22value%22%7D'

        expect(result).toEqual(`http://localhost:3000/?state=${expectedOutput}`)
        expect(decodeURIComponent(expectedOutput)).toEqual(
          JSON.stringify({
            mode: 'login',
            test: 'value',
          }),
        )
      })

      it('should add mode to url state', () => {
        const url = 'http://localhost:3000?state={}'
        const mode = 'login'
        const result = addValuesToUrlState({
          url,
          stateType: 'object',
          values: { mode, test: 'value' },
        })

        const expectedOutput = '%7B%22mode%22%3A%22login%22%2C%22test%22%3A%22value%22%7D'

        expect(result).toEqual(`http://localhost:3000/?state=${expectedOutput}`)
        expect(decodeURIComponent(expectedOutput)).toEqual(
          JSON.stringify({
            mode: 'login',
            test: 'value',
          }),
        )
      })

      it('should add happen mode to existing state values', () => {
        const url = 'http://localhost:3000?state={"other":"value"}'
        const mode = 'login'
        const result = addValuesToUrlState({
          url,
          stateType: 'object',
          values: { mode, test: 'value' },
        })

        const expectedOutput =
          '%7B%22other%22%3A%22value%22%2C%22mode%22%3A%22login%22%2C%22test%22%3A%22value%22%7D'

        expect(result).toEqual(`http://localhost:3000/?state=${expectedOutput}`)
        expect(decodeURIComponent(expectedOutput)).toEqual(
          JSON.stringify({
            other: 'value',
            mode: 'login',
            test: 'value',
          }),
        )
      })
    })

    describe('stateType: string', () => {
      it('should create state with value if not existing', () => {
        const url = 'http://localhost:3000/?state'
        const mode = 'login'
        const result = addValuesToUrlState({
          url,
          stateType: 'string',
          values: { mode, test: 'value' },
        })

        const expectedOutput =
          '%7B%22state%22%3A%22%7B%7D%22%2C%22mode%22%3A%22login%22%2C%22test%22%3A%22value%22%7D'

        expect(result).toEqual(`http://localhost:3000/?state=${expectedOutput}`)
        expect(decodeURIComponent(expectedOutput)).toEqual(
          JSON.stringify({
            state: '{}',
            mode: 'login',
            test: 'value',
          }),
        )
      })

      it('should add mode to url state', () => {
        const url = 'http://localhost:3000/?state=id'
        const mode = 'login'
        const result = addValuesToUrlState({
          url,
          stateType: 'string',
          values: { mode, test: 'value' },
        })

        const expectedOutput =
          '%7B%22state%22%3A%22id%22%2C%22mode%22%3A%22login%22%2C%22test%22%3A%22value%22%7D'

        expect(result).toEqual(`http://localhost:3000/?state=${expectedOutput}`)
        expect(decodeURIComponent(expectedOutput)).toEqual(
          JSON.stringify({
            state: 'id',
            mode: 'login',
            test: 'value',
          }),
        )
      })
    })
  })
})
