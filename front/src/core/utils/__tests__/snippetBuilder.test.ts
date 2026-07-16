import { snippetBuilder } from '~/core/utils/snippetBuilder'

describe('SnippetBuilder', () => {
  it('should work properly', () => {
    const result = snippetBuilder({
      title: 'My title',
      url: `url`,
      method: 'POST',
      headers: [{ Authorization: 'Bearer ' }, { 'Content-Type': 'application/json' }],
      data: {
        snippet: {
          name: 'name',
          code: 'code',
          nested: {
            nestedName: 'nestedName',
            nestedCode: 'nestedCode',
          },
          nestedArray: [
            {
              id: '1',
              name: 'test',
            },
          ],
        },
      },
      footerComment: 'To use the snippet, don’t forget to edit your __YOUR_API_KEY__',
    })

    expect(result).toBe(`# My title
curl --location --request POST "url" \\
  --header "Authorization: Bearer " \\
  --header "Content-Type: application/json" \\
  --data-raw '{
    "snippet": {
      "name": "name",
      "code": "code",
      "nested": {
        "nestedName": "nestedName",
        "nestedCode": "nestedCode"
      },
      "nestedArray": [
        {
          "id": "1",
          "name": "test"
        }
      ]
    }
  }'

# To use the snippet, don’t forget to edit your __YOUR_API_KEY__`)
  })

  it('should work properly with no data', () => {
    const result = snippetBuilder({
      title: 'My title',
      url: `url`,
      method: 'POST',
      headers: [{ Authorization: 'Bearer ' }, { 'Content-Type': 'application/json' }],
      data: {},
    })

    expect(result).toBe(`# My title
curl --location --request POST "url" \\
  --header "Authorization: Bearer " \\
  --header "Content-Type: application/json" \\
  --data-raw '{}'
`)
  })

  it('should work properly with conditional data and undefined values', () => {
    const shouldRender: boolean = false
    const state: string = ''

    const result = snippetBuilder({
      title: 'My title',
      url: `url`,
      method: 'POST',
      headers: [{ Authorization: 'Bearer ' }, { 'Content-Type': 'application/json' }],
      data: {
        snippet: {
          ...(!!state && { state: 'active' }),
          ...(!!state && { state: null }),
          name: undefined,
          title: 'title',
          nested: {
            nestedName: 'nestedName',
            nestedCode: 'nestedCode',
          },
          nestedArray: [
            {
              id: '1',
              name: 'test',
            },
          ],
          ...(shouldRender ? { withFalse: 'true' } : false),
          ...(shouldRender ? { withEmptyObj: 'true' } : {}),
          ...(shouldRender ? { withText: 'true' } : ''),
          ...(shouldRender ? { withUndefined: 'true' } : undefined),
          ...(shouldRender ? { withNull: 'true' } : null),
        },
      },
      footerComment: 'To use the snippet, don’t forget to edit your __YOUR_API_KEY__',
    })

    expect(result).toBe(`# My title
curl --location --request POST "url" \\
  --header "Authorization: Bearer " \\
  --header "Content-Type: application/json" \\
  --data-raw '{
    "snippet": {
      "title": "title",
      "nested": {
        "nestedName": "nestedName",
        "nestedCode": "nestedCode"
      },
      "nestedArray": [
        {
          "id": "1",
          "name": "test"
        }
      ]
    }
  }'

# To use the snippet, don’t forget to edit your __YOUR_API_KEY__`)
  })
})
