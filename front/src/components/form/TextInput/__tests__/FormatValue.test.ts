import { formatValue } from '../TextInput'

describe('Text input formatValue', () => {
  it('should return the initial value if no formatter', () => {
    const undefinedValue = formatValue(undefined)
    const emptyValue = formatValue('')
    const stringValue = formatValue('String test')
    const numberValue = formatValue(346)
    const negativeValue = formatValue(-349)
    const zeroValue = formatValue(0)

    expect(undefinedValue).toBe('')
    expect(emptyValue).toBe('')
    expect(stringValue).toBe('String test')
    expect(numberValue).toBe(346)
    expect(negativeValue).toBe(-349)
    expect(zeroValue).toBe(0)
  })

  it('should return empty string if no value', () => {
    const undefinedValue = formatValue(undefined, 'int')
    const emptyValue = formatValue('', 'int')
    const zeroValue = formatValue(0, 'int')

    expect(undefinedValue).toBe('')
    expect(emptyValue).toBe('')
    expect(zeroValue).toBe(0)
  })

  it('should return an int in case of "int" formatter', () => {
    const negativeValue = formatValue(-12, 'int')
    const value = formatValue(15, 'int')
    const zeroValue = formatValue(0, 'int')
    const negativeDecimalValue = formatValue(-13.459484, 'int')
    const decimalValue = formatValue(11.459484, 'int')
    const stringValue = formatValue('random string', 'int')
    const minus = formatValue('-', 'int')
    const writtingDecimals = formatValue('29.', 'int')

    expect(negativeValue).toBe(-12)
    expect(value).toBe(15)
    expect(zeroValue).toBe(0)
    expect(negativeDecimalValue).toBe(-13)
    expect(decimalValue).toBe(11)
    expect(stringValue).toBe(null)
    expect(minus).toBe('-')
    expect(writtingDecimals).toBe(29)
  })

  it('should return a positive number for "positiveNumber" formatter', () => {
    const negativeValue = formatValue(-12, 'positiveNumber')
    const value = formatValue(15, 'positiveNumber')
    const zeroValue = formatValue(0, 'positiveNumber')
    const negativeDecimalValue = formatValue(-13.459484, 'positiveNumber')
    const decimalValue = formatValue(11.459484, 'positiveNumber')
    const stringValue = formatValue('random string', 'positiveNumber')
    const writtingDecimals = formatValue('-29.', 'positiveNumber')

    expect(negativeValue).toBe('12')
    expect(value).toBe('15')
    expect(zeroValue).toBe('0')
    expect(negativeDecimalValue).toBe('13.459484')
    expect(decimalValue).toBe('11.459484')
    expect(stringValue).toBe(null)
    expect(writtingDecimals).toBe('29.')
  })

  it('should return a number with 2 decimals for "decimal" formatter', () => {
    const negativeValue = formatValue(-12, 'decimal')
    const value = formatValue(15, 'decimal')
    const zeroValue = formatValue(0, 'decimal')
    const negativeDecimalValue = formatValue(-13.459484, 'decimal')
    const minus = formatValue('-', 'decimal')
    const decimalValue = formatValue(11.459484, 'decimal')
    const stringValue = formatValue('random string', 'decimal')
    const writtingDecimals = formatValue('-29.', 'decimal')

    expect(negativeValue).toBe('-12')
    expect(value).toBe('15')
    expect(zeroValue).toBe('0')
    expect(negativeDecimalValue).toBe('-13.45')
    expect(decimalValue).toBe('11.45')
    expect(stringValue).toBe(null)
    expect(minus).toBe('-')
    expect(writtingDecimals).toBe('-29.')
  })

  it('should return a number with 3 decimals for "triDecimal" formatter', () => {
    const negativeValue = formatValue(-12, 'triDecimal')
    const value = formatValue(15, 'triDecimal')
    const zeroValue = formatValue(0, 'triDecimal')
    const negativeDecimalValue = formatValue(-13.459484, 'triDecimal')
    const minus = formatValue('-', 'triDecimal')
    const decimalValue = formatValue(11.459484, 'triDecimal')
    const stringValue = formatValue('random string', 'triDecimal')
    const writtingDecimals = formatValue('-29.', 'triDecimal')

    expect(negativeValue).toBe('-12')
    expect(value).toBe('15')
    expect(zeroValue).toBe('0')
    expect(negativeDecimalValue).toBe('-13.459')
    expect(decimalValue).toBe('11.459')
    expect(stringValue).toBe(null)
    expect(minus).toBe('-')
    expect(writtingDecimals).toBe('-29.')
  })

  it('should return a number with 4 for "quadDecimal" formatter', () => {
    const negativeValue = formatValue(-12, 'quadDecimal')
    const value = formatValue(15, 'quadDecimal')
    const zeroValue = formatValue(0, 'quadDecimal')
    const negativeDecimalValue = formatValue(-13.459484, 'quadDecimal')
    const minus = formatValue('-', 'quadDecimal')
    const decimalValue = formatValue(11.459484, 'quadDecimal')
    const stringValue = formatValue('random string', 'quadDecimal')
    const writtingDecimals = formatValue('-29.', 'quadDecimal')

    expect(negativeValue).toBe('-12')
    expect(value).toBe('15')
    expect(zeroValue).toBe('0')
    expect(negativeDecimalValue).toBe('-13.4594')
    expect(decimalValue).toBe('11.4594')
    expect(stringValue).toBe(null)
    expect(minus).toBe('-')
    expect(writtingDecimals).toBe('-29.')
  })

  it('should return a number with 6 decimals for "sextDecimal" formatter', () => {
    const negativeValue = formatValue(-12, 'sextDecimal')
    const value = formatValue(15, 'sextDecimal')
    const zeroValue = formatValue(0, 'sextDecimal')
    const negativeDecimalValue = formatValue(-13.459484, 'sextDecimal')
    const decimalValue = formatValue(11.459484, 'sextDecimal')
    const shortDecimalValue = formatValue(11.45, 'sextDecimal')
    const veryLongDecimalValue = formatValue(11.134567890123456, 'sextDecimal')
    const stringValue = formatValue('random string', 'sextDecimal')

    expect(negativeValue).toBe('-12')
    expect(value).toBe('15')
    expect(zeroValue).toBe('0')
    expect(negativeDecimalValue).toBe('-13.459484')
    expect(decimalValue).toBe('11.459484')
    expect(shortDecimalValue).toBe('11.45')
    expect(veryLongDecimalValue).toBe('11.134567')
    expect(stringValue).toBe(null)
  })

  it('should return a string with no spaces for "code" formatter', () => {
    const longString = formatValue('I just wanna have fun', 'code')
    const number = formatValue(938884, 'code')

    expect(longString).toBe('I_just_wanna_have_fun')
    expect(number).toBe('938884')
  })

  it('should return a lowercase string for "lowercase" formatter', () => {
    const lowercase = formatValue('May the Force be with you', 'lowercase')
    const uppercase = formatValue('MY PRECIOUS.', 'lowercase')
    const number = formatValue(938884, 'lowercase')

    expect(lowercase).toBe('may the force be with you')
    expect(uppercase).toBe('my precious.')
    expect(number).toBe('938884')
  })

  it('should return a trimmed string for "trim" formatter', () => {
    const trimmed = formatValue('  va  lue  ', 'trim')

    expect(trimmed).toBe('va  lue')
  })

  it('should return a dashed string for "dashSeparator" formatter', () => {
    const trimmed = formatValue(' v alue_-01', 'dashSeparator')

    expect(trimmed).toBe('-v-alue--01')
  })

  it('should return the right value for combined formatters', () => {
    const decimalPositive = formatValue(-13.459484, ['decimal', 'positiveNumber'])
    const intPositive = formatValue(-11.459484, ['int', 'positiveNumber'])
    const specificCode = formatValue(' CUS_1234 ', ['lowercase', 'trim', 'dashSeparator'])

    expect(decimalPositive).toBe('13.45')
    expect(intPositive).toBe(11)
    expect(specificCode).toBe('cus-1234')
  })
})
