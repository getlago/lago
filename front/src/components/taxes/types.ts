import { TaxCreateInput, TaxUpdateInput } from '~/generated/graphql'

export type TaxFormInput = TaxCreateInput | Omit<TaxUpdateInput, 'id'>
