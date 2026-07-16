import { BillingEntityEmailSettingsEnum } from '~/generated/graphql'

export const useEmailPreviewTranslationsKey = () => {
  const mapTranslationsKey = (type?: BillingEntityEmailSettingsEnum) => {
    switch (type) {
      case BillingEntityEmailSettingsEnum.InvoiceFinalized:
        return {
          header: 'text_6407684eaf41130074c4b2f0',
          title: 'text_6407684eaf41130074c4b2f3',
          subtitle: 'text_6407684eaf41130074c4b2f4',
          subject: 'text_64188b3d9735d5007d71225c',
          invoice_from: 'text_64188b3d9735d5007d712266',
          amount: 'text_64188b3d9735d5007d712249',
          invoice_number: 'text_64188b3d9735d5007d71226c',
          invoice_number_value: 'text_64188b3d9735d5007d71226e',
          issue_date: 'text_64188b3d9735d5007d712270',
          issue_date_value: 'text_64188b3d9735d5007d712272',
        }
      case BillingEntityEmailSettingsEnum.PaymentReceiptCreated:
        return {
          header: 'text_1741334140002zdl3cl599ib',
          title: 'text_1741334140002zdl3cl599ib',
          subtitle: 'text_1741334140002wx0sbk2bd13',
          subject: 'text_17413343926218dbogzsvk4w',
          invoice_from: 'text_1741334392621wr13yk143fc',
          amount: 'text_17413343926218vamtw2ybko',
          total: 'text_1741334392621yu0957trt4n',
          receipt_number: 'text_17416040051091zpga3ugijs',
          receipt_number_value: 'text_1741604005109q6qlr3qcc1u',
          payment_date: 'text_1741604005109kywirovj4yo',
          payment_date_value: 'text_17416040051098005r277i71',
          amount_paid: 'text_1741604005109aspaz4chd7y',
          amount_paid_value: 'text_1741604005109w5ns73xmam9',
          payment_method: 'text_17440371192353kif37ol194',
          payment_method_value: 'text_1744037119235rz9n0rfhwcp',
        }
      default:
        return {
          header: 'text_1741334140002zdl3cl599ib',
          title: 'text_6408d642d50da800533e43d8',
          subtitle: 'text_6408d64fb486aa006163f043',
          subject: 'text_64188b3d9735d5007d712271',
          invoice_from: 'text_64188b3d9735d5007d71227b',
          amount: 'text_64188b3d9735d5007d71227d',
          total: 'text_64188b3d9735d5007d71227e',
          credit_note_number: 'text_64188b3d9735d5007d71227f',
          credit_note_number_value: 'text_64188b3d9735d5007d712280',
          invoice_number: 'text_64188b3d9735d5007d712281',
          invoice_number_value: 'text_64188b3d9735d5007d712282',
          issue_date: 'text_64188b3d9735d5007d712283',
          issue_date_value: 'text_64188b3d9735d5007d712284',
        }
    }
  }

  return {
    mapTranslationsKey,
  }
}
