import { CodeSnippet } from '~/components/CodeSnippet'
import { envGlobalVar } from '~/core/apolloClient'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { snippetBuilder, SnippetVariables } from '~/core/utils/snippetBuilder'
import { CreateAddOnInput } from '~/generated/graphql'

const { apiUrl } = envGlobalVar()

const getSnippets = (addOn?: CreateAddOnInput) => {
  if (!addOn || !addOn.code) return '# Fill the form to generate the code snippet'

  return snippetBuilder({
    title: 'Create a one off invoice with this add-on on a customer',
    method: 'POST',
    url: `${apiUrl}/api/v1/invoices`,
    headers: [
      { Authorization: `Bearer $${SnippetVariables.API_KEY}` },
      {
        'Content-Type': 'application/json',
      },
    ],
    data: {
      invoice: {
        external_customer_id: SnippetVariables.EXTERNAL_CUSTOMER_ID,
        currency: addOn.amountCurrency,
        fees: [
          {
            add_on_code: addOn.code,
            units: 1,
            unit_amount_cents: serializeAmount(addOn.amountCents || 0, addOn.amountCurrency),
            ...(addOn?.description && { description: addOn.description }),
          },
        ],
      },
    },
    footerComment: `To use the snippet, don’t forget to edit your ${SnippetVariables.API_KEY} and ${SnippetVariables.EXTERNAL_CUSTOMER_ID}`,
  })
}

interface AddOnCodeSnippetProps {
  addOn?: CreateAddOnInput
  loading?: boolean
}

export const AddOnCodeSnippet = ({ addOn, loading }: AddOnCodeSnippetProps) => {
  return <CodeSnippet loading={loading} language="bash" code={getSnippets(addOn)} />
}
