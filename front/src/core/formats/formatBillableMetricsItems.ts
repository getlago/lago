import { AggregationTypeEnum, RoundingFunctionEnum } from '~/generated/graphql'

export const formatAggregationType = (
  aggregationType: AggregationTypeEnum,
): { label: string; helperText: string } | undefined => {
  switch (aggregationType) {
    case AggregationTypeEnum.UniqueCountAgg:
      return {
        label: 'text_62694d9181be8d00a33f20f0',
        helperText: 'text_62694d9181be8d00a33f20f6',
      }
    case AggregationTypeEnum.LatestAgg:
      return {
        label: 'text_64f8823d75521b6faaee8549',
        helperText: 'text_64f8823d75521b6faaee854b',
      }
    case AggregationTypeEnum.MaxAgg:
      return {
        label: 'text_62694d9181be8d00a33f20f8',
        helperText: 'text_62694d9181be8d00a33f20f2',
      }
    case AggregationTypeEnum.SumAgg:
      return {
        label: 'text_62694d9181be8d00a33f2100',
        helperText: 'text_62694d9181be8d00a33f20ec',
      }
    case AggregationTypeEnum.CountAgg:
      return {
        label: 'text_623c4a8c599213014cacc9de',
        helperText: 'text_6241cc759211e600ea57f4f1',
      }
    case AggregationTypeEnum.CustomAgg:
      return {
        label: 'text_663dea5702b60301d8d06504',
        helperText: 'text_663dea5702b60301d8d0650c',
      }
    case AggregationTypeEnum.WeightedSumAgg:
      return {
        label: 'text_650062226a33c46e82050486',
        helperText: 'text_650062226a33c46e82050488',
      }
    default:
      return undefined
  }
}

export const formatRoundingFunction = (
  roundingFunction: RoundingFunctionEnum,
): { label: string; helperText: string } | undefined => {
  switch (roundingFunction) {
    case RoundingFunctionEnum.Ceil:
      return {
        label: 'text_17305546426481bes2lelpqf',
        helperText: 'text_1730554642648grbu07mq6u3',
      }
    case RoundingFunctionEnum.Floor:
      return {
        label: 'text_1730554642648f6pn2krp9sh',
        helperText: 'text_173055464264830liis0ojbc',
      }
    case RoundingFunctionEnum.Round:
      return {
        label: 'text_1730554642648p1mngqwys8n',
        helperText: 'text_1730554642648qe9wjveh3fv',
      }
    default:
      return undefined
  }
}
