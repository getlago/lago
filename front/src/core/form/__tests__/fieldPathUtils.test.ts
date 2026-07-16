import { getFieldPath, getFieldValue } from '../fieldPathUtils'

describe('getFieldPath', () => {
  it('should return the field name when basePath is not provided', () => {
    expect(getFieldPath('paymentMethod')).toBe('paymentMethod')
    expect(getFieldPath('invoiceCustomSection')).toBe('invoiceCustomSection')
  })

  it('should return the concatenated path when basePath is provided', () => {
    expect(getFieldPath('paymentMethod', 'recurringTransactionRules.0')).toBe(
      'recurringTransactionRules.0.paymentMethod',
    )
    expect(getFieldPath('invoiceCustomSection', 'recurringTransactionRules.0')).toBe(
      'recurringTransactionRules.0.invoiceCustomSection',
    )
  })

  it('should handle empty string basePath as no basePath', () => {
    expect(getFieldPath('paymentMethod', '')).toBe('paymentMethod')
  })

  it('should handle nested basePath', () => {
    expect(getFieldPath('field', 'parent.child')).toBe('parent.child.field')
  })
})

describe('getFieldValue', () => {
  it('should return the field value when basePath is not provided', () => {
    const object = {
      paymentMethod: { paymentMethodType: 'provider', paymentMethodId: '123' },
      invoiceCustomSection: { invoiceCustomSectionIds: ['1', '2'] },
    }

    expect(getFieldValue('paymentMethod', object)).toEqual({
      paymentMethodType: 'provider',
      paymentMethodId: '123',
    })
    expect(getFieldValue('invoiceCustomSection', object)).toEqual({
      invoiceCustomSectionIds: ['1', '2'],
    })
  })

  it('should return the field value when basePath is provided', () => {
    const object = {
      recurringTransactionRules: [
        {
          paymentMethod: { paymentMethodType: 'manual', paymentMethodId: '456' },
          invoiceCustomSection: { invoiceCustomSectionIds: ['3'] },
        },
      ],
    }

    expect(getFieldValue('paymentMethod', object, 'recurringTransactionRules.0')).toEqual({
      paymentMethodType: 'manual',
      paymentMethodId: '456',
    })
    expect(getFieldValue('invoiceCustomSection', object, 'recurringTransactionRules.0')).toEqual({
      invoiceCustomSectionIds: ['3'],
    })
  })

  it('should return undefined for non-existent field without basePath', () => {
    const object = {
      paymentMethod: { paymentMethodType: 'provider' },
    }

    expect(getFieldValue('nonExistentField', object)).toBeUndefined()
  })

  it('should return undefined for non-existent field with basePath', () => {
    const object = {
      recurringTransactionRules: [
        {
          paymentMethod: { paymentMethodType: 'provider' },
        },
      ],
    }

    expect(getFieldValue('nonExistentField', object, 'recurringTransactionRules.0')).toBeUndefined()
  })

  it('should return undefined for non-existent basePath', () => {
    const object = {
      paymentMethod: { paymentMethodType: 'provider' },
    }

    expect(getFieldValue('paymentMethod', object, 'nonExistent.0')).toBeUndefined()
  })

  it('should handle nested object values', () => {
    const object = {
      nested: {
        deep: {
          value: 'test',
        },
      },
    }

    expect(getFieldValue('deep.value', object, 'nested')).toBe('test')
  })

  it('should handle array values', () => {
    const object = {
      items: [
        { id: '1', name: 'Item 1' },
        { id: '2', name: 'Item 2' },
      ],
    }

    expect(getFieldValue('0.name', object, 'items')).toBe('Item 1')
    expect(getFieldValue('1.name', object, 'items')).toBe('Item 2')
  })

  it('should handle null and undefined values', () => {
    const object = {
      nullValue: null,
      undefinedValue: undefined,
    }

    expect(getFieldValue('nullValue', object)).toBeNull()
    expect(getFieldValue('undefinedValue', object)).toBeUndefined()
  })

  it('should handle primitive values', () => {
    const object = {
      stringValue: 'test',
      numberValue: 42,
      booleanValue: true,
    }

    expect(getFieldValue('stringValue', object)).toBe('test')
    expect(getFieldValue('numberValue', object)).toBe(42)
    expect(getFieldValue('booleanValue', object)).toBe(true)
  })

  it('should work with Formik values object', () => {
    const formikValues = {
      paymentMethod: { paymentMethodType: 'provider', paymentMethodId: '123' },
      recurringTransactionRules: [
        {
          paymentMethod: { paymentMethodType: 'manual', paymentMethodId: '456' },
        },
      ],
    }

    expect(getFieldValue('paymentMethod', formikValues)).toEqual({
      paymentMethodType: 'provider',
      paymentMethodId: '123',
    })
    expect(getFieldValue('paymentMethod', formikValues, 'recurringTransactionRules.0')).toEqual({
      paymentMethodType: 'manual',
      paymentMethodId: '456',
    })
  })

  it('should work with any generic object structure', () => {
    const genericObject = {
      user: {
        profile: {
          name: 'John',
          settings: {
            theme: 'dark',
          },
        },
      },
      items: [{ value: 1 }, { value: 2 }],
    }

    expect(getFieldValue('name', genericObject, 'user.profile')).toBe('John')
    expect(getFieldValue('theme', genericObject, 'user.profile.settings')).toBe('dark')
    expect(getFieldValue('value', genericObject, 'items.0')).toBe(1)
    expect(getFieldValue('value', genericObject, 'items.1')).toBe(2)
  })
})
