import { CodeSnippet } from '~/components/CodeSnippet'
import { envGlobalVar } from '~/core/apolloClient'
import { snippetBuilder, SnippetVariables } from '~/core/utils/snippetBuilder'
import { AggregationTypeEnum, CreateBillableMetricInput } from '~/generated/graphql'

const { apiUrl } = envGlobalVar()

const getSnippets = (billableMetric?: CreateBillableMetricInput) => {
  if (!billableMetric) return '# Fill the form to generate the code snippet'

  const { aggregationType, code, fieldName, filters } = billableMetric
  const firstFilter = filters?.[0]
  const canDisplayFilterProperty = !!firstFilter && !!firstFilter?.key && !!firstFilter?.values?.[0]

  const snippet = snippetBuilder({
    title: 'Create a new event',
    url: `${apiUrl}/api/v1/events`,
    method: 'POST',
    headers: [
      { Authorization: `Bearer ${SnippetVariables.API_KEY}` },
      { 'Content-Type': 'application/json' },
    ],
    data: {
      event: {
        transaction_id: SnippetVariables.UNIQUE_ID,
        external_subscription_id: SnippetVariables.EXTERNAL_SUBSCRIPTION_ID,
        code: code || SnippetVariables.MUST_BE_DEFINED,
        ...((!!fieldName || !!filters?.length) && {
          properties: {
            ...(!!aggregationType && aggregationType !== AggregationTypeEnum.CountAgg
              ? {
                  [fieldName || '__PROPERTY_TO_AGGREGATE__']: fieldName
                    ? `__${fieldName.toUpperCase()}_VALUE__`
                    : '__DEFINE_A_PROPERTY_TO_AGGREGATE__',
                }
              : {}),
            ...(canDisplayFilterProperty
              ? {
                  [firstFilter?.key || '__DEFINE_A_KEY__']:
                    firstFilter?.values?.[0] || '__DEFINE_A_VALUE__',
                }
              : {}),
          },
        }),
      },
    },
    footerComment: `To use the snippet, don’t forget to edit your ${SnippetVariables.API_KEY}, ${SnippetVariables.UNIQUE_ID} and ${SnippetVariables.EXTERNAL_SUBSCRIPTION_ID}`,
  })

  return snippet
}

interface BillableMetricCodeSnippetProps {
  loading?: boolean
  billableMetric?: CreateBillableMetricInput
}

export const BillableMetricCodeSnippet = ({
  billableMetric,
  loading,
}: BillableMetricCodeSnippetProps) => {
  return <CodeSnippet loading={loading} language="bash" code={getSnippets(billableMetric)} />
}
