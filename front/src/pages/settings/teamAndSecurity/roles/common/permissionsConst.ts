import { PermissionEnum } from '~/generated/graphql'

import { PermissionGroupMapping, PermissionName } from './permissionsTypes'

export const allPermissions = Object.keys(PermissionEnum) as Array<PermissionName>

export const hiddenPermissions: Array<PermissionName> = []

export const permissionGroupMapping: PermissionGroupMapping = {
  addons: ['AddonsCreate', 'AddonsDelete', 'AddonsUpdate', 'AddonsView'],
  aiAgent: ['AiConversationsCreate', 'AiConversationsView'],
  analytics: ['AnalyticsView'],
  auditLogs: ['AuditLogsView'],
  authenticationMethods: ['AuthenticationMethodsView', 'AuthenticationMethodsUpdate'],
  billableMetrics: [
    'BillableMetricsCreate',
    'BillableMetricsDelete',
    'BillableMetricsUpdate',
    'BillableMetricsView',
  ],
  billingEntities: [
    'BillingEntitiesView',
    'BillingEntitiesCreate',
    'BillingEntitiesUpdate',
    'BillingEntitiesDelete',
  ],
  charges: ['ChargesCreate', 'ChargesUpdate', 'ChargesDelete'],
  coupons: [
    'CouponsAttach',
    'CouponsCreate',
    'CouponsDelete',
    'CouponsDetach',
    'CouponsUpdate',
    'CouponsView',
  ],
  creditNotes: [
    'CreditNotesCreate',
    'CreditNotesView',
    'CreditNotesVoid',
    'CreditNotesUpdate',
    'CreditNotesExport',
    'CreditNotesSend',
  ],
  customers: ['CustomersCreate', 'CustomersDelete', 'CustomersUpdate', 'CustomersView'],
  dataApi: ['DataApiView'],
  developers: ['DevelopersKeysManage', 'DevelopersManage'],
  dunningCampaigns: [
    'DunningCampaignsCreate',
    'DunningCampaignsUpdate',
    'DunningCampaignsView',
    'DunningCampaignsDelete',
  ],
  features: ['FeaturesCreate', 'FeaturesDelete', 'FeaturesUpdate', 'FeaturesView'],
  invoiceCustomSections: [
    'InvoiceCustomSectionsCreate',
    'InvoiceCustomSectionsUpdate',
    'InvoiceCustomSectionsDelete',
    'InvoiceCustomSectionsView',
  ],
  invoices: [
    'InvoicesCreate',
    'InvoicesSend',
    'InvoicesUpdate',
    'InvoicesView',
    'InvoicesVoid',
    'InvoicesExport',
  ],
  organization: [
    'OrganizationView',
    'OrganizationUpdate',
    'OrganizationEmailsView',
    'OrganizationEmailsUpdate',
    'OrganizationIntegrationsCreate',
    'OrganizationIntegrationsDelete',
    'OrganizationIntegrationsUpdate',
    'OrganizationIntegrationsView',
    'OrganizationInvoicesView',
    'OrganizationInvoicesUpdate',
    'OrganizationMembersCreate',
    'OrganizationMembersDelete',
    'OrganizationMembersUpdate',
    'OrganizationMembersView',
    'OrganizationTaxesView',
    'OrganizationTaxesUpdate',
  ],
  payments: [
    'PaymentsCreate',
    'PaymentsView',
    'PaymentMethodsCreate',
    'PaymentMethodsDelete',
    'PaymentMethodsUpdate',
    'PaymentMethodsView',
    'PaymentReceiptsView',
    'PaymentReceiptsSend',
  ],
  plans: ['PlansCreate', 'PlansDelete', 'PlansUpdate', 'PlansView'],
  pricingUnits: ['PricingUnitsCreate', 'PricingUnitsUpdate', 'PricingUnitsView'],
  quotes: [
    'QuotesApprove',
    'QuotesClone',
    'QuotesCreate',
    'QuotesUpdate',
    'QuotesView',
    'QuotesVoid',
    'OrderFormsView',
    'OrderFormsSign',
    'OrderFormsVoid',
    'OrdersUpdate',
    'OrdersView',
  ],
  roles: ['RolesCreate', 'RolesDelete', 'RolesUpdate', 'RolesView'],
  securityLogs: ['SecurityLogsView'],
  subscriptions: ['SubscriptionsCreate', 'SubscriptionsUpdate', 'SubscriptionsView'],
  wallets: ['WalletsCreate', 'WalletsTerminate', 'WalletsTopUp', 'WalletsUpdate'],
}

export const groupNameMapping: Record<string, string> = {
  addons: 'text_629728388c4d2300e2d3801a',
  aiAgent: 'text_1767000875575g9rl1iida4n',
  analytics: 'text_6553885df387fd0097fd7384',
  auditLogs: 'text_1766071560701xrf1tn0w5wx',
  authenticationMethods: 'text_664c732c264d7eed1c74fd96',
  billableMetrics: 'text_623b497ad05b960101be3438',
  billingEntities: 'text_1743077296189ms0shds6g53',
  charges: 'text_1768572142436xubwd6sei3b',
  coupons: 'text_637ccf8133d2c9a7d11ce705',
  creditNotes: 'text_637ccf8133d2c9a7d11ce708',
  customerSettings: 'text_1765882497985wd35gnobdvl',
  customers: 'text_624efab67eb2570101d117a5',
  dataApi: 'text_1766071560701ud8peghugtg',
  developers: 'text_6271200984178801ba8bdeac',
  draftInvoices: 'text_17658824979850l2uroad1dz',
  dunningCampaigns: 'text_1728574726495w5aylnynne9',
  features: 'text_1752692673070k7z0mmf0494',
  invoiceCustomSections: 'text_1765882631575jrjzdfbdvn5',
  invoices: 'text_63ac86d797f728a87b2f9f85',
  organization: 'text_173289482048511y9ieyywq5',
  payments: 'text_6672ebb8b1b50be550eccbed',
  plans: 'text_62442e40cea25600b0b6d85a',
  pricingUnits: 'text_17502505476284yyq70yy6mx',
  quotes: 'text_1776154937966msav6jde4hm',
  roles: 'text_1765448879791epmkg4xijkn',
  securityLogs: 'text_17730476805600nudrokzkk5',
  subscriptions: 'text_6250304370f0f700a8fdc28d',
  wallets: 'text_62d175066d2dbf1d50bc937c',
}

export const permissionDescriptionMapping: Partial<Record<PermissionName, string>> = {
  // Addons
  AddonsCreate: 'text_1766047581847fumm5ku57ir',
  AddonsDelete: 'text_17660475818471if48pmb0dl',
  AddonsUpdate: 'text_17660475818475etknl1tlry',
  AddonsView: 'text_1766047581847hb6797c3vuz',

  // AI Conversations
  AiConversationsCreate: 'text_17660475818478cmjmlb6yli',
  AiConversationsView: 'text_17660475818476qea85rok4v',

  // Analytics
  AnalyticsView: 'text_17660475818478stwv9xgjcy',

  // Audit Logs
  AuditLogsView: 'text_1766047581847c14q5h7q7e9',

  // Authentication Methods
  AuthenticationMethodsView: 'text_1766047581848voqfdw1n16u',
  AuthenticationMethodsUpdate: 'text_1766047581848u1p4t9aq8cw',

  // Billable Metrics
  BillableMetricsCreate: 'text_176604758184880rlput3rgm',
  BillableMetricsDelete: 'text_17660475818481f10dsq5yh0',
  BillableMetricsUpdate: 'text_1766047581848ghd2ui7xu89',
  BillableMetricsView: 'text_1766047581848nwzt4s8mzcj',

  // Billing Entities
  BillingEntitiesView: 'text_1766047581848drlfvsw4ztp',
  BillingEntitiesCreate: 'text_1766047581848utclfbiju0p',
  BillingEntitiesUpdate: 'text_1766047581848f4j4bz8lqg8',
  BillingEntitiesDelete: 'text_17660475818481vz8uookjpd',

  // Charges
  ChargesCreate: 'text_1768572142437iellff897qo',
  ChargesUpdate: 'text_1768572142437tyh61d8ed6t',
  ChargesDelete: 'text_1768572142437ch7vfimm1ts',

  // Coupons
  CouponsAttach: 'text_17660475818481lrad2tzefh',
  CouponsCreate: 'text_1766047581848eoo9h3lmrjk',
  CouponsDelete: 'text_1766047581848jubqg1vytbe',
  CouponsDetach: 'text_1766047581848foirk3ohptx',
  CouponsUpdate: 'text_1766047581848w5w4ioj1x0s',
  CouponsView: 'text_17660475818481lx6cod98vs',

  // Credit Notes
  CreditNotesCreate: 'text_1766047581848q86w4sz1ccv',
  CreditNotesExport: 'text_1766047581848cc5gc4hfp2r',
  CreditNotesUpdate: 'text_1766047581848fjq7h53nksy',
  CreditNotesView: 'text_17660475818489lrb93zbafu',
  CreditNotesVoid: 'text_1766047581848azlox6rihlr',
  CreditNotesSend: 'text_1771003155244io0a00y67om',

  // Customers
  CustomersCreate: 'text_17660475818490917oik1suj',
  CustomersDelete: 'text_1766047581849rxymid08aue',
  CustomersUpdate: 'text_1766047581849uf40youqly2',
  CustomersView: 'text_1766047581849vgr87putyw1',

  // Data API
  DataApiView: 'text_1766047581849maew761smvw',

  // Developers
  DevelopersKeysManage: 'text_1766047581849yy0i21nnxj2',
  DevelopersManage: 'text_1766047581849do7xbzegoz9',

  // Dunning Campaigns
  DunningCampaignsCreate: 'text_17660475818496c0nexqgglo',
  DunningCampaignsDelete: 'text_1766047581849v64zabe7m7r',
  DunningCampaignsUpdate: 'text_17660475818499x85cwds9hm',
  DunningCampaignsView: 'text_17660475818497rzmqyxotn0',

  // Features
  FeaturesCreate: 'text_17660475818491b4ih8nmxj8',
  FeaturesDelete: 'text_17660475818496qrp4na70xh',
  FeaturesUpdate: 'text_1766047581849ewfuqgrctbp',
  FeaturesView: 'text_1766047581849yl02q8ddced',

  // Invoice Custom Sections
  InvoiceCustomSectionsCreate: 'text_1766047581849xa20no7528c',
  InvoiceCustomSectionsDelete: 'text_1766047581849mnidqgar7f3',
  InvoiceCustomSectionsUpdate: 'text_1766047581849og4405s05wp',
  InvoiceCustomSectionsView: 'text_17660475818494gap5htg4td',

  // Invoices
  InvoicesCreate: 'text_1766047581849nemod0aclpk',
  InvoicesExport: 'text_1766047581849shrzn6zz5pc',
  InvoicesSend: 'text_1766047581849sruujz7kc7u',
  InvoicesUpdate: 'text_1766047581849kg8h3krio7b',
  InvoicesView: 'text_17660475818496eb8mnaygrc',
  InvoicesVoid: 'text_1766047581850xfdxud1g9ic',

  // Organization
  OrganizationView: 'text_1766047581850c4xikdtb4v6',
  OrganizationUpdate: 'text_1766047581850ru00srfppl3',
  OrganizationEmailsView: 'text_1766047581850x7wxp8lj5pw',
  OrganizationEmailsUpdate: 'text_1766047581850k261kqzm3kx',
  OrganizationIntegrationsCreate: 'text_1766047581850kqjzi8026vl',
  OrganizationIntegrationsDelete: 'text_1766047581850e7vpp52f38b',
  OrganizationIntegrationsUpdate: 'text_1766047581850dwy6zqgknrg',
  OrganizationIntegrationsView: 'text_1766047581850qy1056vrym5',
  OrganizationInvoicesView: 'text_1766047581850dyl15icwf2u',
  OrganizationInvoicesUpdate: 'text_17660475818502tut62phbi4',
  OrganizationMembersCreate: 'text_17660475818509vupfh8b3re',
  OrganizationMembersDelete: 'text_17660475818505yilgjvwl4u',
  OrganizationMembersUpdate: 'text_1766047581850wbdrf26zeuw',
  OrganizationMembersView: 'text_1766047581850v1tbj62gphc',
  OrganizationTaxesView: 'text_1766047581850wufdxn8tnfc',
  OrganizationTaxesUpdate: 'text_17660475818502nin2bywo4x',

  // Order Forms
  OrderFormsView: 'text_178047301390626q8o2l7ob4',
  OrderFormsSign: 'text_1781623709531xo64x5511bd',
  OrderFormsVoid: 'text_1781623709531nm1ezxdq0gb',
  OrdersUpdate: 'text_1782723591984gz2mp067m0n',
  OrdersView: 'text_1782723591984jx3x7kt7rph',

  // Payment Methods
  PaymentMethodsCreate: 'text_1766047581850xfo6ml8ll9w',
  PaymentMethodsDelete: 'text_1766047581850s9h3mkqc749',
  PaymentMethodsUpdate: 'text_1766047581850pd2fl4vp3op',
  PaymentMethodsView: 'text_1766047581850j2zvnyrxs3v',
  PaymentReceiptsSend: 'text_1771003155244j5yyywffre1',
  PaymentReceiptsView: 'text_1771003155244uual9jklecz',

  // Payments
  PaymentsCreate: 'text_1766047581850ukn3u9te9qh',
  PaymentsView: 'text_1766047581850xz434boveds',

  // Plans
  PlansCreate: 'text_17660475818509g7q5akr5ux',
  PlansDelete: 'text_1766047581850kqos81coudo',
  PlansUpdate: 'text_1766047581850war432jrvfz',
  PlansView: 'text_1766047581851nni5mneelo0',

  // Pricing Units
  PricingUnitsCreate: 'text_1766047581851sjxfx26kocx',
  PricingUnitsUpdate: 'text_1766047581851z3d9is40izc',
  PricingUnitsView: 'text_17660476446747j5vtzpcqea',

  // Quotes
  QuotesApprove: 'text_1778232548237lowm64qljfp',
  QuotesClone: 'text_177823254823718y2tah0jcx',
  QuotesCreate: 'text_1778232548237tdgidv9off9',
  QuotesUpdate: 'text_1778232548237f1f1pja8esj',
  QuotesView: 'text_1778232548237p4cirr96hwe',
  QuotesVoid: 'text_177823254823762hkchuyv10',

  // Roles
  RolesCreate: 'text_1766999821840apnk9dhpeud',
  RolesDelete: 'text_17669998218407sg2nrlk1xu',
  RolesUpdate: 'text_1766999821840zqhdgsgwayb',
  RolesView: 'text_1766999821840vh8hwybwpmi',

  // Subscriptions
  SubscriptionsCreate: 'text_1766047644675i164ysmqiog',
  SubscriptionsUpdate: 'text_17660476446752sbul6dha24',
  SubscriptionsView: 'text_176604764467582epdk23rja',

  // Security logs
  SecurityLogsView: 'text_1771594976281yf0uews8jce',

  // Wallets
  WalletsCreate: 'text_1766047644675qckx90hacmh',
  WalletsTerminate: 'text_17660476446757dl68yksj13',
  WalletsTopUp: 'text_17660476446757ovltb3ahdr',
  WalletsUpdate: 'text_1766047644675mhoyd5oe387',
}
