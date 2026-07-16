import {
  METADATA_KEY_MAX_LENGTH,
  METADATA_VALUE_MAX_LENGTH_DEFAULT,
  metadataSchema,
  zodMetadataSchema,
} from '~/formValidation/metadataSchema'

describe('metadataSchema', () => {
  describe('metadataSchema()', () => {
    describe('invalid', () => {
      it('has no key', () => {
        const values = [
          {
            value: 'value',
          },
        ]
        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has no value', () => {
        const values = [
          {
            key: 'key',
          },
        ]
        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has key too long with default setting', () => {
        const values = [
          {
            key: new Array(METADATA_KEY_MAX_LENGTH + 2).join('a'),
            value: 'value',
          },
        ]

        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has value too long with default size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(METADATA_VALUE_MAX_LENGTH_DEFAULT + 2).join('a'),
          },
        ]

        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
      it('has value too long with custom size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(4).join('a'),
          },
        ]

        const schema = metadataSchema({ valueMaxLength: 2 })
        const result = schema.isValidSync(values)

        expect(result).toBeFalsy()
      })
    })
    describe('valid', () => {
      it('has valid key and value', () => {
        const values = [
          {
            key: 'key',
            value: 'value',
          },
        ]
        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has key long enough with default setting', () => {
        const values = [
          {
            key: new Array(METADATA_KEY_MAX_LENGTH - 1).join('a'),
            value: 'value',
          },
        ]

        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has value long enough with default size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(METADATA_VALUE_MAX_LENGTH_DEFAULT + 1).join('a'),
          },
        ]

        const schema = metadataSchema()
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
      it('has value long enough with custom size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(3).join('a'),
          },
        ]

        const schema = metadataSchema({ valueMaxLength: 2 })
        const result = schema.isValidSync(values)

        expect(result).toBeTruthy()
      })
    })
  })

  describe('zodMetadataSchema()', () => {
    describe('invalid', () => {
      it('has no key', () => {
        const values = [
          {
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has empty key', () => {
        const values = [
          {
            key: '',
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has no value', () => {
        const values = [
          {
            key: 'key',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has empty value', () => {
        const values = [
          {
            key: 'key',
            value: '',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has key too long with default setting', () => {
        const values = [
          {
            key: new Array(METADATA_KEY_MAX_LENGTH + 2).join('a'),
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has value too long with default size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(METADATA_VALUE_MAX_LENGTH_DEFAULT + 2).join('a'),
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has value too long with custom size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(4).join('a'),
          },
        ]
        const schema = zodMetadataSchema(2)
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has duplicate keys', () => {
        const values = [
          {
            key: 'duplicateKey',
            value: 'value1',
          },
          {
            key: 'duplicateKey',
            value: 'value2',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('has multiple duplicate keys', () => {
        const values = [
          {
            key: 'key1',
            value: 'value1',
          },
          {
            key: 'key2',
            value: 'value2',
          },
          {
            key: 'key1',
            value: 'value3',
          },
          {
            key: 'key2',
            value: 'value4',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
      })

      it('returns correct error message for key too long', () => {
        const values = [
          {
            key: new Array(METADATA_KEY_MAX_LENGTH + 2).join('a'),
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
        if (!result.success) {
          expect(result.error.issues.some((issue) => issue.message === 'maxLength')).toBeTruthy()
        }
      })

      it('returns correct error message for value too long', () => {
        const values = [
          {
            key: 'key',
            value: new Array(METADATA_VALUE_MAX_LENGTH_DEFAULT + 2).join('a'),
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
        if (!result.success) {
          expect(result.error.issues.some((issue) => issue.message === 'maxLength')).toBeTruthy()
        }
      })

      it('returns correct error message for duplicate keys', () => {
        const values = [
          {
            key: 'duplicateKey',
            value: 'value1',
          },
          {
            key: 'duplicateKey',
            value: 'value2',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
        if (!result.success) {
          expect(result.error.issues.some((issue) => issue.message === 'uniqueness')).toBeTruthy()
        }
      })

      it('returns exactly one error per duplicate key when same key appears 3+ times', () => {
        const values = [
          { key: 'sameKey', value: 'value1' },
          { key: 'sameKey', value: 'value2' },
          { key: 'sameKey', value: 'value3' },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeFalsy()
        if (!result.success) {
          const uniquenessIssues = result.error.issues.filter(
            (issue) => issue.message === 'uniqueness',
          )

          // Should have exactly 3 errors (one per item), not more
          expect(uniquenessIssues).toHaveLength(3)

          // Each index should appear exactly once
          const paths = uniquenessIssues.map((issue) => issue.path[0])

          expect(paths.filter((p) => p === 0)).toHaveLength(1)
          expect(paths.filter((p) => p === 1)).toHaveLength(1)
          expect(paths.filter((p) => p === 2)).toHaveLength(1)
        }
      })
    })

    describe('valid', () => {
      it('has valid key and value', () => {
        const values = [
          {
            key: 'key',
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has key at maximum length with default setting', () => {
        const values = [
          {
            key: new Array(METADATA_KEY_MAX_LENGTH + 1).join('a'),
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has value at maximum length with default size', () => {
        const values = [
          {
            key: 'key',
            value: new Array(METADATA_VALUE_MAX_LENGTH_DEFAULT + 1).join('a'),
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has value at maximum length with custom size', () => {
        const values = [
          {
            key: 'key',
            value: 'ab',
          },
        ]
        const schema = zodMetadataSchema(2)
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has multiple valid entries with unique keys', () => {
        const values = [
          {
            key: 'key1',
            value: 'value1',
          },
          {
            key: 'key2',
            value: 'value2',
          },
          {
            key: 'key3',
            value: 'value3',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has valid entry with optional fields', () => {
        const values = [
          {
            key: 'key',
            value: 'value',
            displayInInvoice: true,
            id: 'some-id',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('has valid entry without optional fields', () => {
        const values = [
          {
            key: 'key',
            value: 'value',
          },
        ]
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })

      it('handles empty array', () => {
        const values: Array<unknown> = []
        const schema = zodMetadataSchema()
        const result = schema.safeParse(values)

        expect(result.success).toBeTruthy()
      })
    })
  })
})
