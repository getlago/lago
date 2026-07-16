export interface MentionVariableDef {
  /** MUST equal the backend snake_case key in quoteVersion.mentionVariables. */
  id: string
  /** i18n translation key for the @-dropdown label. */
  labelKey: string
}

export const QUOTE_MENTION_VARIABLES: MentionVariableDef[] = [
  { id: 'customer_name', labelKey: 'text_17824815094139q1xxugt3u2' },
  { id: 'customer_email', labelKey: 'text_1782481509413m756ic70533' },
  { id: 'organization_name', labelKey: 'text_1782481509413fxcamxyayvd' },
  { id: 'organization_logo', labelKey: 'text_1782481509413ru9er6prs5z' },
  { id: 'billing_entity_name', labelKey: 'text_1782481509413jz09a6cha9o' },
  { id: 'billing_entity_legal_name', labelKey: 'text_17824815094137ngfbp39shm' },
  { id: 'billing_entity_address', labelKey: 'text_1782481509413hwhue53hm4w' },
  { id: 'billing_entity_tax_id', labelKey: 'text_17824815094135nxd94eavhr' },
  { id: 'billing_entity_email', labelKey: 'text_1782481509413ktltfto21hj' },
  { id: 'quote_number', labelKey: 'text_1782481509413n8saddc0v3k' },
  { id: 'quote_date', labelKey: 'text_17824815094133dn7osufza0' },
  { id: 'quote_version', labelKey: 'text_1782481509413xyjflsl0nyl' },
  { id: 'quote_currency', labelKey: 'text_1782481509413kl4e2532e9e' },
  { id: 'commercial_terms_term_duration', labelKey: 'text_1782481509414pdptl0o3jmb' },
  { id: 'commercial_terms_start_date', labelKey: 'text_1782481509414nxr0nibo8wj' },
  { id: 'commercial_terms_payment_terms', labelKey: 'text_1782481509414fozc0xn274l' },
]
