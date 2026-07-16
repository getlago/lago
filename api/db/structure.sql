SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.membership_roles DROP CONSTRAINT IF EXISTS membership_role_membership_fk;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_ff75b29299;
ALTER TABLE IF EXISTS ONLY public.presentation_breakdowns DROP CONSTRAINT IF EXISTS fk_rails_ff548a9f4c;
ALTER TABLE IF EXISTS ONLY public.fixed_charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_fea16bf2e7;
ALTER TABLE IF EXISTS ONLY public.orders DROP CONSTRAINT IF EXISTS fk_rails_fe8af6535c;
ALTER TABLE IF EXISTS ONLY public.dunning_campaign_thresholds DROP CONSTRAINT IF EXISTS fk_rails_fd84cdb7c6;
ALTER TABLE IF EXISTS ONLY public.subscription_activation_rules DROP CONSTRAINT IF EXISTS fk_rails_fd60209637;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_fd399a23d3;
ALTER TABLE IF EXISTS ONLY public.wallet_targets DROP CONSTRAINT IF EXISTS fk_rails_fbd2b9fccb;
ALTER TABLE IF EXISTS ONLY public.fees_taxes DROP CONSTRAINT IF EXISTS fk_rails_f98413d404;
ALTER TABLE IF EXISTS ONLY public.order_forms DROP CONSTRAINT IF EXISTS fk_rails_f94f882198;
ALTER TABLE IF EXISTS ONLY public.billing_entities DROP CONSTRAINT IF EXISTS fk_rails_f66617edcb;
ALTER TABLE IF EXISTS ONLY public.payment_receipts DROP CONSTRAINT IF EXISTS fk_rails_f53ff93138;
ALTER TABLE IF EXISTS ONLY public.quantified_events DROP CONSTRAINT IF EXISTS fk_rails_f510acb495;
ALTER TABLE IF EXISTS ONLY public.invoice_subscriptions DROP CONSTRAINT IF EXISTS fk_rails_f435d13904;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_f375d320ad;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_f32b205d44;
ALTER TABLE IF EXISTS ONLY public.enriched_store_subscription_migrations DROP CONSTRAINT IF EXISTS fk_rails_f232478e56;
ALTER TABLE IF EXISTS ONLY public.payment_requests DROP CONSTRAINT IF EXISTS fk_rails_f228550fda;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alert_thresholds DROP CONSTRAINT IF EXISTS fk_rails_f18cd04d51;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_eeb6a32be1;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_triggered_alerts DROP CONSTRAINT IF EXISTS fk_rails_ee2b6f04d9;
ALTER TABLE IF EXISTS ONLY public.invoices_payment_requests DROP CONSTRAINT IF EXISTS fk_rails_ed387e0992;
ALTER TABLE IF EXISTS ONLY public.payment_provider_customers DROP CONSTRAINT IF EXISTS fk_rails_ecb466254b;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_eaca9421be;
ALTER TABLE IF EXISTS ONLY public.integration_customers DROP CONSTRAINT IF EXISTS fk_rails_ea80151038;
ALTER TABLE IF EXISTS ONLY public.fixed_charges DROP CONSTRAINT IF EXISTS fk_rails_e95f72749e;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules DROP CONSTRAINT IF EXISTS fk_rails_e8bac9c5bb;
ALTER TABLE IF EXISTS ONLY public.plans_taxes DROP CONSTRAINT IF EXISTS fk_rails_e88403f4b9;
ALTER TABLE IF EXISTS ONLY public.customers_taxes DROP CONSTRAINT IF EXISTS fk_rails_e86903e081;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS fk_rails_e744efbe51;
ALTER TABLE IF EXISTS ONLY public.charge_filters DROP CONSTRAINT IF EXISTS fk_rails_e711e8089e;
ALTER TABLE IF EXISTS ONLY public.user_devices DROP CONSTRAINT IF EXISTS fk_rails_e700a96826;
ALTER TABLE IF EXISTS ONLY public.integration_mappings DROP CONSTRAINT IF EXISTS fk_rails_e4a58fbcac;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_triggered_alerts DROP CONSTRAINT IF EXISTS fk_rails_e3cf54daac;
ALTER TABLE IF EXISTS ONLY public.integration_collection_mappings DROP CONSTRAINT IF EXISTS fk_rails_e148d17c1f;
ALTER TABLE IF EXISTS ONLY public.customer_metadata DROP CONSTRAINT IF EXISTS fk_rails_dfac602b2c;
ALTER TABLE IF EXISTS ONLY public.credit_note_items DROP CONSTRAINT IF EXISTS fk_rails_dea748e529;
ALTER TABLE IF EXISTS ONLY public.quotes DROP CONSTRAINT IF EXISTS fk_rails_de7694c307;
ALTER TABLE IF EXISTS ONLY public.coupon_targets DROP CONSTRAINT IF EXISTS fk_rails_de6b3c3138;
ALTER TABLE IF EXISTS ONLY public.invites DROP CONSTRAINT IF EXISTS fk_rails_dd342449a6;
ALTER TABLE IF EXISTS ONLY public.enriched_store_subscription_migrations DROP CONSTRAINT IF EXISTS fk_rails_dc444f5f29;
ALTER TABLE IF EXISTS ONLY public.customers_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_db9140d0fd;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_d9ffb8b4a1;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alerts DROP CONSTRAINT IF EXISTS fk_rails_d9ea200904;
ALTER TABLE IF EXISTS ONLY public.integration_resources DROP CONSTRAINT IF EXISTS fk_rails_d9448a540b;
ALTER TABLE IF EXISTS ONLY public.wallets DROP CONSTRAINT IF EXISTS fk_rails_d9342a8ca7;
ALTER TABLE IF EXISTS ONLY public.subscription_fixed_charge_units_overrides DROP CONSTRAINT IF EXISTS fk_rails_d72a9877be;
ALTER TABLE IF EXISTS ONLY public.entitlement_privileges DROP CONSTRAINT IF EXISTS fk_rails_d648e28d9f;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlements DROP CONSTRAINT IF EXISTS fk_rails_d53f825a88;
ALTER TABLE IF EXISTS ONLY public.idempotency_records DROP CONSTRAINT IF EXISTS fk_rails_d4f02c82b2;
ALTER TABLE IF EXISTS ONLY public.wallet_transaction_consumptions DROP CONSTRAINT IF EXISTS fk_rails_d4abfdb375;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS fk_rails_d384ec1ebf;
ALTER TABLE IF EXISTS ONLY public.quote_versions DROP CONSTRAINT IF EXISTS fk_rails_d2d917b73a;
ALTER TABLE IF EXISTS ONLY public.item_metadata DROP CONSTRAINT IF EXISTS fk_rails_d0b1714507;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_d07bc24ce3;
ALTER TABLE IF EXISTS ONLY public.integration_customers DROP CONSTRAINT IF EXISTS fk_rails_ce2c63d69f;
ALTER TABLE IF EXISTS ONLY public.subscription_fixed_charge_units_overrides DROP CONSTRAINT IF EXISTS fk_rails_cdaf36dc89;
ALTER TABLE IF EXISTS ONLY public.pricing_units DROP CONSTRAINT IF EXISTS fk_rails_cd99351ee3;
ALTER TABLE IF EXISTS ONLY public.integration_mappings DROP CONSTRAINT IF EXISTS fk_rails_cc318ad1ff;
ALTER TABLE IF EXISTS ONLY public.plans DROP CONSTRAINT IF EXISTS fk_rails_cbf700aeb8;
ALTER TABLE IF EXISTS ONLY public.usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_caeb5a3949;
ALTER TABLE IF EXISTS ONLY public.entitlement_subscription_feature_removals DROP CONSTRAINT IF EXISTS fk_rails_c9183c59d9;
ALTER TABLE IF EXISTS ONLY public.payment_methods DROP CONSTRAINT IF EXISTS fk_rails_c8606f586b;
ALTER TABLE IF EXISTS ONLY public.subscriptions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_c82f03a405;
ALTER TABLE IF EXISTS ONLY public.invites DROP CONSTRAINT IF EXISTS fk_rails_c71f4b2026;
ALTER TABLE IF EXISTS ONLY public.customers_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_c64033bcb0;
ALTER TABLE IF EXISTS ONLY public.payment_methods DROP CONSTRAINT IF EXISTS fk_rails_c60c12efbd;
ALTER TABLE IF EXISTS ONLY public.pricing_unit_usages DROP CONSTRAINT IF EXISTS fk_rails_c545103d57;
ALTER TABLE IF EXISTS ONLY public.active_storage_attachments DROP CONSTRAINT IF EXISTS fk_rails_c3b3935057;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_c29bf4ff0f;
ALTER TABLE IF EXISTS ONLY public.enriched_store_migrations DROP CONSTRAINT IF EXISTS fk_rails_c04bd1a196;
ALTER TABLE IF EXISTS ONLY public.customers DROP CONSTRAINT IF EXISTS fk_rails_bff25bb1bb;
ALTER TABLE IF EXISTS ONLY public.charge_filter_values DROP CONSTRAINT IF EXISTS fk_rails_bf661ef73d;
ALTER TABLE IF EXISTS ONLY public.dunning_campaign_thresholds DROP CONSTRAINT IF EXISTS fk_rails_bf1f386f75;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_subscription_activities DROP CONSTRAINT IF EXISTS fk_rails_bda048a8d9;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_bcb5aecd6c;
ALTER TABLE IF EXISTS ONLY public.plans_taxes DROP CONSTRAINT IF EXISTS fk_rails_bacde7a063;
ALTER TABLE IF EXISTS ONLY public.applied_coupons DROP CONSTRAINT IF EXISTS fk_rails_bacb46d2a3;
ALTER TABLE IF EXISTS ONLY public.lifetime_usages DROP CONSTRAINT IF EXISTS fk_rails_ba128983c2;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_b974dac270;
ALTER TABLE IF EXISTS ONLY public.presentation_breakdowns DROP CONSTRAINT IF EXISTS fk_rails_b8f3cabc8e;
ALTER TABLE IF EXISTS ONLY public.subscription_activation_rules DROP CONSTRAINT IF EXISTS fk_rails_b749d2045d;
ALTER TABLE IF EXISTS ONLY public.orders DROP CONSTRAINT IF EXISTS fk_rails_b687c6e23a;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlements DROP CONSTRAINT IF EXISTS fk_rails_b61aa73940;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_b50dc82c1e;
ALTER TABLE IF EXISTS ONLY public.entitlement_subscription_feature_removals DROP CONSTRAINT IF EXISTS fk_rails_b3864df641;
ALTER TABLE IF EXISTS ONLY public.billing_entities_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_b283a89721;
ALTER TABLE IF EXISTS ONLY public.daily_usages DROP CONSTRAINT IF EXISTS fk_rails_b07fc711f7;
ALTER TABLE IF EXISTS ONLY public.pricing_unit_usages DROP CONSTRAINT IF EXISTS fk_rails_aea6422e6a;
ALTER TABLE IF EXISTS ONLY public.charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_ac146c9541;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_subscription_activities DROP CONSTRAINT IF EXISTS fk_rails_ab16de0b32;
ALTER TABLE IF EXISTS ONLY public.commitments_taxes DROP CONSTRAINT IF EXISTS fk_rails_aaa12f7d3e;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlement_values DROP CONSTRAINT IF EXISTS fk_rails_aa34dd5db6;
ALTER TABLE IF EXISTS ONLY public.fixed_charges DROP CONSTRAINT IF EXISTS fk_rails_aa04ceacf6;
ALTER TABLE IF EXISTS ONLY public.integration_items DROP CONSTRAINT IF EXISTS fk_rails_a9dc2ea536;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_a7f20c73bb;
ALTER TABLE IF EXISTS ONLY public.charges DROP CONSTRAINT IF EXISTS fk_rails_a710519346;
ALTER TABLE IF EXISTS ONLY public.group_properties DROP CONSTRAINT IF EXISTS fk_rails_a2d2cb3819;
ALTER TABLE IF EXISTS ONLY public.quotes DROP CONSTRAINT IF EXISTS fk_rails_a1ab65f1f7;
ALTER TABLE IF EXISTS ONLY public.credit_note_items DROP CONSTRAINT IF EXISTS fk_rails_9f22076477;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_9ea6759859;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_9e3f99b7a2;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alerts DROP CONSTRAINT IF EXISTS fk_rails_9d8812945e;
ALTER TABLE IF EXISTS ONLY public.applied_add_ons DROP CONSTRAINT IF EXISTS fk_rails_9c8e276cc0;
ALTER TABLE IF EXISTS ONLY public.plans_taxes DROP CONSTRAINT IF EXISTS fk_rails_9c704027e2;
ALTER TABLE IF EXISTS ONLY public.applied_usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_9c08b43701;
ALTER TABLE IF EXISTS ONLY public.active_storage_variant_records DROP CONSTRAINT IF EXISTS fk_rails_993965df05;
ALTER TABLE IF EXISTS ONLY public.memberships DROP CONSTRAINT IF EXISTS fk_rails_99326fb65d;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_98980b326b;
ALTER TABLE IF EXISTS ONLY public.fixed_charge_events DROP CONSTRAINT IF EXISTS fk_rails_9881e28151;
ALTER TABLE IF EXISTS ONLY public.pending_vies_checks DROP CONSTRAINT IF EXISTS fk_rails_96fc54cd9a;
ALTER TABLE IF EXISTS ONLY public.entitlement_subscription_feature_removals DROP CONSTRAINT IF EXISTS fk_rails_95df3194c5;
ALTER TABLE IF EXISTS ONLY public.customers DROP CONSTRAINT IF EXISTS fk_rails_94cc21031f;
ALTER TABLE IF EXISTS ONLY public.data_export_parts DROP CONSTRAINT IF EXISTS fk_rails_9298b8fdad;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_91802dc891;
ALTER TABLE IF EXISTS ONLY public.invoice_subscriptions DROP CONSTRAINT IF EXISTS fk_rails_90d93bd016;
ALTER TABLE IF EXISTS ONLY public.data_export_parts DROP CONSTRAINT IF EXISTS fk_rails_909197908c;
ALTER TABLE IF EXISTS ONLY public.fixed_charge_events DROP CONSTRAINT IF EXISTS fk_rails_90302b3ca3;
ALTER TABLE IF EXISTS ONLY public.commitments_taxes DROP CONSTRAINT IF EXISTS fk_rails_8fa6f0d920;
ALTER TABLE IF EXISTS ONLY public.applied_pricing_units DROP CONSTRAINT IF EXISTS fk_rails_8e0c3d0c5b;
ALTER TABLE IF EXISTS ONLY public.usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_8df9bf2b6c;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alerts DROP CONSTRAINT IF EXISTS fk_rails_8c18828b53;
ALTER TABLE IF EXISTS ONLY public.fixed_charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_8c09ee2428;
ALTER TABLE IF EXISTS ONLY public.invoice_metadata DROP CONSTRAINT IF EXISTS fk_rails_8bb5b094c4;
ALTER TABLE IF EXISTS ONLY public.add_ons_taxes DROP CONSTRAINT IF EXISTS fk_rails_89e1020aca;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlement_values DROP CONSTRAINT IF EXISTS fk_rails_8887954ec7;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_885dc100ef;
ALTER TABLE IF EXISTS ONLY public.invoice_subscriptions DROP CONSTRAINT IF EXISTS fk_rails_88349fc20a;
ALTER TABLE IF EXISTS ONLY public.wallets_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_87bc3bd4cb;
ALTER TABLE IF EXISTS ONLY public.payment_provider_customers DROP CONSTRAINT IF EXISTS fk_rails_86676be631;
ALTER TABLE IF EXISTS ONLY public.wallet_transaction_consumptions DROP CONSTRAINT IF EXISTS fk_rails_85b9e72931;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS fk_rails_84f4587409;
ALTER TABLE IF EXISTS ONLY public.payment_methods DROP CONSTRAINT IF EXISTS fk_rails_84a67e8b40;
ALTER TABLE IF EXISTS ONLY public.wallet_targets DROP CONSTRAINT IF EXISTS fk_rails_81eedc32c0;
ALTER TABLE IF EXISTS ONLY public.add_ons DROP CONSTRAINT IF EXISTS fk_rails_81e3b6abba;
ALTER TABLE IF EXISTS ONLY public.entitlement_features DROP CONSTRAINT IF EXISTS fk_rails_81d8b323cf;
ALTER TABLE IF EXISTS ONLY public.charges DROP CONSTRAINT IF EXISTS fk_rails_7eb0484711;
ALTER TABLE IF EXISTS ONLY public.billable_metrics DROP CONSTRAINT IF EXISTS fk_rails_7e8a2f26e5;
ALTER TABLE IF EXISTS ONLY public.charge_filter_values DROP CONSTRAINT IF EXISTS fk_rails_7da558cadc;
ALTER TABLE IF EXISTS ONLY public.wallet_targets DROP CONSTRAINT IF EXISTS fk_rails_7d0e61668f;
ALTER TABLE IF EXISTS ONLY public.subscriptions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_7c63dd13f0;
ALTER TABLE IF EXISTS ONLY public.invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_7c0e340dbd;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_7b324610ad;
ALTER TABLE IF EXISTS ONLY public.api_keys DROP CONSTRAINT IF EXISTS fk_rails_7aab96f30e;
ALTER TABLE IF EXISTS ONLY public.billable_metric_filters DROP CONSTRAINT IF EXISTS fk_rails_7a0704ce72;
ALTER TABLE IF EXISTS ONLY public.applied_add_ons DROP CONSTRAINT IF EXISTS fk_rails_7995206484;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_78f6642ddf;
ALTER TABLE IF EXISTS ONLY public.groups DROP CONSTRAINT IF EXISTS fk_rails_7886e1bc34;
ALTER TABLE IF EXISTS ONLY public.credit_notes_taxes DROP CONSTRAINT IF EXISTS fk_rails_77f2d4440d;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS fk_rails_778360c382;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_775eb0ecd8;
ALTER TABLE IF EXISTS ONLY public.quote_owners DROP CONSTRAINT IF EXISTS fk_rails_7734750af9;
ALTER TABLE IF EXISTS ONLY public.commitments DROP CONSTRAINT IF EXISTS fk_rails_76ceb88c74;
ALTER TABLE IF EXISTS ONLY public.integrations DROP CONSTRAINT IF EXISTS fk_rails_755d734f25;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS fk_rails_75577c354e;
ALTER TABLE IF EXISTS ONLY public.fixed_charge_events DROP CONSTRAINT IF EXISTS fk_rails_752665cc51;
ALTER TABLE IF EXISTS ONLY public.fees_taxes DROP CONSTRAINT IF EXISTS fk_rails_745b4ca7dd;
ALTER TABLE IF EXISTS ONLY public.data_exports DROP CONSTRAINT IF EXISTS fk_rails_73d83e23b6;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alert_thresholds DROP CONSTRAINT IF EXISTS fk_rails_710f37148d;
ALTER TABLE IF EXISTS ONLY public.subscriptions_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_6eb8abe6cb;
ALTER TABLE IF EXISTS ONLY public.pending_vies_checks DROP CONSTRAINT IF EXISTS fk_rails_6e238f3bfc;
ALTER TABLE IF EXISTS ONLY public.invoices_taxes DROP CONSTRAINT IF EXISTS fk_rails_6e148ccbb1;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_6d465e6b10;
ALTER TABLE IF EXISTS ONLY public.dunning_campaigns DROP CONSTRAINT IF EXISTS fk_rails_6c720a8ccd;
ALTER TABLE IF EXISTS ONLY public.billing_entities_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_699cd1384f;
ALTER TABLE IF EXISTS ONLY public.customers_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_68754484c0;
ALTER TABLE IF EXISTS ONLY public.integration_resources DROP CONSTRAINT IF EXISTS fk_rails_67d4eb3c92;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS fk_rails_66eb6b32c1;
ALTER TABLE IF EXISTS ONLY public.fixed_charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_665ae33492;
ALTER TABLE IF EXISTS ONLY public.billing_entities_taxes DROP CONSTRAINT IF EXISTS fk_rails_651eadaaa4;
ALTER TABLE IF EXISTS ONLY public.integration_collection_mappings DROP CONSTRAINT IF EXISTS fk_rails_650fccfc41;
ALTER TABLE IF EXISTS ONLY public.membership_roles DROP CONSTRAINT IF EXISTS fk_rails_65053e240e;
ALTER TABLE IF EXISTS ONLY public.memberships DROP CONSTRAINT IF EXISTS fk_rails_64267aab58;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS fk_rails_63d3df128b;
ALTER TABLE IF EXISTS ONLY public.pricing_unit_usages DROP CONSTRAINT IF EXISTS fk_rails_63ca8e33c5;
ALTER TABLE IF EXISTS ONLY public.applied_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_63ac282e70;
ALTER TABLE IF EXISTS ONLY public.invoice_metadata DROP CONSTRAINT IF EXISTS fk_rails_63683837a2;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS fk_rails_62d18ea517;
ALTER TABLE IF EXISTS ONLY public.order_forms DROP CONSTRAINT IF EXISTS fk_rails_6298debfc7;
ALTER TABLE IF EXISTS ONLY public.credit_notes_taxes DROP CONSTRAINT IF EXISTS fk_rails_626209b8d2;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_6023b3f2dd;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules DROP CONSTRAINT IF EXISTS fk_rails_5efea6fe31;
ALTER TABLE IF EXISTS ONLY public.fixed_charges DROP CONSTRAINT IF EXISTS fk_rails_5e06da3c18;
ALTER TABLE IF EXISTS ONLY public.credit_notes DROP CONSTRAINT IF EXISTS fk_rails_5cb67dee79;
ALTER TABLE IF EXISTS ONLY public.credit_note_items DROP CONSTRAINT IF EXISTS fk_rails_5cb2f24c3d;
ALTER TABLE IF EXISTS ONLY public.payment_receipts DROP CONSTRAINT IF EXISTS fk_rails_5c2e0b6d34;
ALTER TABLE IF EXISTS ONLY public.error_details DROP CONSTRAINT IF EXISTS fk_rails_5c21eece29;
ALTER TABLE IF EXISTS ONLY public.quotes DROP CONSTRAINT IF EXISTS fk_rails_5bb40a7bae;
ALTER TABLE IF EXISTS ONLY public.add_ons_taxes DROP CONSTRAINT IF EXISTS fk_rails_5ade8984b1;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS fk_rails_5a4b906a16;
ALTER TABLE IF EXISTS ONLY public.data_exports DROP CONSTRAINT IF EXISTS fk_rails_5a43da571b;
ALTER TABLE IF EXISTS ONLY public.customers DROP CONSTRAINT IF EXISTS fk_rails_58234c715e;
ALTER TABLE IF EXISTS ONLY public.charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_56b7167125;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS fk_rails_56b3626631;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS fk_rails_5628a713de;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlement_values DROP CONSTRAINT IF EXISTS fk_rails_533b639bac;
ALTER TABLE IF EXISTS ONLY public.applied_usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_52b72c9b0e;
ALTER TABLE IF EXISTS ONLY public.password_resets DROP CONSTRAINT IF EXISTS fk_rails_526379cd99;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules DROP CONSTRAINT IF EXISTS fk_rails_52370612ae;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS fk_rails_521b5240ed;
ALTER TABLE IF EXISTS ONLY public.commitments DROP CONSTRAINT IF EXISTS fk_rails_51ac39a0c6;
ALTER TABLE IF EXISTS ONLY public.billable_metric_filters DROP CONSTRAINT IF EXISTS fk_rails_51077e7c0e;
ALTER TABLE IF EXISTS ONLY public.payment_provider_customers DROP CONSTRAINT IF EXISTS fk_rails_50d46d3679;
ALTER TABLE IF EXISTS ONLY public.wallets DROP CONSTRAINT IF EXISTS fk_rails_4ff087c52e;
ALTER TABLE IF EXISTS ONLY public.order_forms DROP CONSTRAINT IF EXISTS fk_rails_4ed54bfec0;
ALTER TABLE IF EXISTS ONLY public.billing_entities DROP CONSTRAINT IF EXISTS fk_rails_4aa58496c3;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_49fcc221b0;
ALTER TABLE IF EXISTS ONLY public.charges DROP CONSTRAINT IF EXISTS fk_rails_4934f27a06;
ALTER TABLE IF EXISTS ONLY public.webhooks DROP CONSTRAINT IF EXISTS fk_rails_49212d501e;
ALTER TABLE IF EXISTS ONLY public.integration_items DROP CONSTRAINT IF EXISTS fk_rails_47d8081062;
ALTER TABLE IF EXISTS ONLY public.quote_owners DROP CONSTRAINT IF EXISTS fk_rails_45230f8485;
ALTER TABLE IF EXISTS ONLY public.credit_notes DROP CONSTRAINT IF EXISTS fk_rails_4117574b51;
ALTER TABLE IF EXISTS ONLY public.credit_notes DROP CONSTRAINT IF EXISTS fk_rails_41088c7d45;
ALTER TABLE IF EXISTS ONLY public.charges_taxes DROP CONSTRAINT IF EXISTS fk_rails_3ff27d7624;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS fk_rails_3f7be5debc;
ALTER TABLE IF EXISTS ONLY public.invoices_payment_requests DROP CONSTRAINT IF EXISTS fk_rails_3ec3563cf3;
ALTER TABLE IF EXISTS ONLY public.entitlement_privileges DROP CONSTRAINT IF EXISTS fk_rails_3e4df02771;
ALTER TABLE IF EXISTS ONLY public.orders DROP CONSTRAINT IF EXISTS fk_rails_3dad120da9;
ALTER TABLE IF EXISTS ONLY public.integration_collection_mappings DROP CONSTRAINT IF EXISTS fk_rails_3d568ff9de;
ALTER TABLE IF EXISTS ONLY public.charges DROP CONSTRAINT IF EXISTS fk_rails_3cfe1d68d7;
ALTER TABLE IF EXISTS ONLY public.daily_usages DROP CONSTRAINT IF EXISTS fk_rails_3c7c3920c0;
ALTER TABLE IF EXISTS ONLY public.wallet_transaction_consumptions DROP CONSTRAINT IF EXISTS fk_rails_3c786cd3e3;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS fk_rails_3b7dad8e9c;
ALTER TABLE IF EXISTS ONLY public.group_properties DROP CONSTRAINT IF EXISTS fk_rails_3acf9e789c;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS fk_rails_3ab959bfc4;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_rails_3a303bf667;
ALTER TABLE IF EXISTS ONLY public.quantified_events DROP CONSTRAINT IF EXISTS fk_rails_3926855f12;
ALTER TABLE IF EXISTS ONLY public.inbound_webhooks DROP CONSTRAINT IF EXISTS fk_rails_36cda06530;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS fk_rails_364213cc3e;
ALTER TABLE IF EXISTS ONLY public.charge_filter_values DROP CONSTRAINT IF EXISTS fk_rails_3640b4a66a;
ALTER TABLE IF EXISTS ONLY public.groups DROP CONSTRAINT IF EXISTS fk_rails_34b5ee1894;
ALTER TABLE IF EXISTS ONLY public.wallets_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_34b4e489e6;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_34ab152115;
ALTER TABLE IF EXISTS ONLY public.lifetime_usages DROP CONSTRAINT IF EXISTS fk_rails_348acbd245;
ALTER TABLE IF EXISTS ONLY public.customers_taxes DROP CONSTRAINT IF EXISTS fk_rails_33d169382f;
ALTER TABLE IF EXISTS ONLY public.payment_requests DROP CONSTRAINT IF EXISTS fk_rails_32600e5a72;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS fk_rails_310fcb3585;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_rails_309d3a4412;
ALTER TABLE IF EXISTS ONLY public.wallets_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_3092f5f2e0;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS fk_rails_2ffeff5323;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS fk_rails_2fd7ee65e6;
ALTER TABLE IF EXISTS ONLY public.payment_requests DROP CONSTRAINT IF EXISTS fk_rails_2fb2147151;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_2ea4db3a4c;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS fk_rails_2dc6171f57;
ALTER TABLE IF EXISTS ONLY public.ai_conversations DROP CONSTRAINT IF EXISTS fk_rails_2c06a74f41;
ALTER TABLE IF EXISTS ONLY public.wallets DROP CONSTRAINT IF EXISTS fk_rails_2b35eef34b;
ALTER TABLE IF EXISTS ONLY public.usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_2908dd8de5;
ALTER TABLE IF EXISTS ONLY public.wallets DROP CONSTRAINT IF EXISTS fk_rails_28077d4aa2;
ALTER TABLE IF EXISTS ONLY public.charge_filters DROP CONSTRAINT IF EXISTS fk_rails_27b55b8574;
ALTER TABLE IF EXISTS ONLY public.payment_providers DROP CONSTRAINT IF EXISTS fk_rails_26be2f764d;
ALTER TABLE IF EXISTS ONLY public.billing_entities_taxes DROP CONSTRAINT IF EXISTS fk_rails_268c288aaa;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_257af22645;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS fk_rails_2561c00887;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS fk_rails_2539663124;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS fk_rails_25267b0e17;
ALTER TABLE IF EXISTS ONLY public.credit_notes_taxes DROP CONSTRAINT IF EXISTS fk_rails_25232a0ec3;
ALTER TABLE IF EXISTS ONLY public.invoices_payment_requests DROP CONSTRAINT IF EXISTS fk_rails_2496c105ed;
ALTER TABLE IF EXISTS ONLY public.taxes DROP CONSTRAINT IF EXISTS fk_rails_23975f5a47;
ALTER TABLE IF EXISTS ONLY public.applied_pricing_units DROP CONSTRAINT IF EXISTS fk_rails_22bb2c0770;
ALTER TABLE IF EXISTS ONLY public.invoices_taxes DROP CONSTRAINT IF EXISTS fk_rails_22af6c6d28;
ALTER TABLE IF EXISTS ONLY public.commitments_taxes DROP CONSTRAINT IF EXISTS fk_rails_2259c88f26;
ALTER TABLE IF EXISTS ONLY public.cached_aggregations DROP CONSTRAINT IF EXISTS fk_rails_21eb389927;
ALTER TABLE IF EXISTS ONLY public.webhook_endpoints DROP CONSTRAINT IF EXISTS fk_rails_21808fa528;
ALTER TABLE IF EXISTS ONLY public.plans DROP CONSTRAINT IF EXISTS fk_rails_216ac8a975;
ALTER TABLE IF EXISTS ONLY public.customers_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_20f157fa49;
ALTER TABLE IF EXISTS ONLY public.webhooks DROP CONSTRAINT IF EXISTS fk_rails_20cc0de4c7;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS fk_rails_1db0057d9b;
ALTER TABLE IF EXISTS ONLY public.applied_usage_thresholds DROP CONSTRAINT IF EXISTS fk_rails_1d112bf8a0;
ALTER TABLE IF EXISTS ONLY public.billing_entities_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_19c47827ba;
ALTER TABLE IF EXISTS ONLY public.customer_metadata DROP CONSTRAINT IF EXISTS fk_rails_195153290d;
ALTER TABLE IF EXISTS ONLY public.coupon_targets DROP CONSTRAINT IF EXISTS fk_rails_189f2a3949;
ALTER TABLE IF EXISTS ONLY public.quote_owners DROP CONSTRAINT IF EXISTS fk_rails_1811b32fcd;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlements DROP CONSTRAINT IF EXISTS fk_rails_173327f0dc;
ALTER TABLE IF EXISTS ONLY public.invoice_subscriptions DROP CONSTRAINT IF EXISTS fk_rails_150139409e;
ALTER TABLE IF EXISTS ONLY public.coupon_targets DROP CONSTRAINT IF EXISTS fk_rails_1454058c96;
ALTER TABLE IF EXISTS ONLY public.invoices_taxes DROP CONSTRAINT IF EXISTS fk_rails_142809fee1;
ALTER TABLE IF EXISTS ONLY public.daily_usages DROP CONSTRAINT IF EXISTS fk_rails_12d29bc654;
ALTER TABLE IF EXISTS ONLY public.entitlement_subscription_feature_removals DROP CONSTRAINT IF EXISTS fk_rails_123667657c;
ALTER TABLE IF EXISTS ONLY public.quote_versions DROP CONSTRAINT IF EXISTS fk_rails_10ee148d0d;
ALTER TABLE IF EXISTS ONLY public.applied_invoice_custom_sections DROP CONSTRAINT IF EXISTS fk_rails_10428ecad2;
ALTER TABLE IF EXISTS ONLY public.fees_taxes DROP CONSTRAINT IF EXISTS fk_rails_103e187859;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_triggered_alerts DROP CONSTRAINT IF EXISTS fk_rails_0f807322b1;
ALTER TABLE IF EXISTS ONLY public.integration_mappings DROP CONSTRAINT IF EXISTS fk_rails_0f762162b0;
ALTER TABLE IF EXISTS ONLY public.integration_customers DROP CONSTRAINT IF EXISTS fk_rails_0e464363cb;
ALTER TABLE IF EXISTS ONLY public.ai_conversations DROP CONSTRAINT IF EXISTS fk_rails_0da056ac92;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_rails_0d349e632f;
ALTER TABLE IF EXISTS ONLY public.customers_taxes DROP CONSTRAINT IF EXISTS fk_rails_0d2be3d72c;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlements DROP CONSTRAINT IF EXISTS fk_rails_0c9773c34d;
ALTER TABLE IF EXISTS ONLY public.coupon_targets DROP CONSTRAINT IF EXISTS fk_rails_0bb6dcc01f;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_triggered_alerts DROP CONSTRAINT IF EXISTS fk_rails_0baa7bd751;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_0934890b24;
ALTER TABLE IF EXISTS ONLY public.add_ons_taxes DROP CONSTRAINT IF EXISTS fk_rails_08dfe87131;
ALTER TABLE IF EXISTS ONLY public.enriched_store_subscription_migrations DROP CONSTRAINT IF EXISTS fk_rails_08d9dce6d1;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fk_rails_085d1cc97b;
ALTER TABLE IF EXISTS ONLY public.billing_entities_taxes DROP CONSTRAINT IF EXISTS fk_rails_07b21049f2;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_rails_06b7046ec3;
ALTER TABLE IF EXISTS ONLY public.subscription_fixed_charge_units_overrides DROP CONSTRAINT IF EXISTS fk_rails_0480ef4ad3;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS fk_rails_04388258ff;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS fk_rails_01a4c0c7db;
ALTER TABLE IF EXISTS ONLY public.pending_vies_checks DROP CONSTRAINT IF EXISTS fk_rails_019e2289e5;
ALTER TABLE IF EXISTS ONLY public.payment_methods DROP CONSTRAINT IF EXISTS fk_rails_00e7a45b0b;
DROP TRIGGER IF EXISTS ensure_consistency ON public.roles;
DROP TRIGGER IF EXISTS before_payment_receipt_insert ON public.payment_receipts;
CREATE OR REPLACE VIEW public.flat_filters AS
SELECT
    NULL::uuid AS organization_id,
    NULL::character varying AS billable_metric_code,
    NULL::uuid AS plan_id,
    NULL::uuid AS charge_id,
    NULL::timestamp(6) without time zone AS charge_updated_at,
    NULL::uuid AS charge_filter_id,
    NULL::timestamp(6) without time zone AS charge_filter_updated_at,
    NULL::jsonb AS filters,
    NULL::jsonb AS pricing_group_keys,
    NULL::boolean AS pay_in_advance,
    NULL::boolean AS accepts_target_wallet;
CREATE OR REPLACE VIEW public.billable_metrics_grouped_charges AS
SELECT
    NULL::uuid AS organization_id,
    NULL::character varying AS code,
    NULL::integer AS aggregation_type,
    NULL::character varying AS field_name,
    NULL::uuid AS plan_id,
    NULL::uuid AS charge_id,
    NULL::boolean AS pay_in_advance,
    NULL::jsonb AS grouped_by,
    NULL::uuid AS charge_filter_id,
    NULL::json AS filters,
    NULL::jsonb AS filters_grouped_by;
DROP INDEX IF EXISTS public.unique_default_payment_method_per_customer;
DROP INDEX IF EXISTS public.index_wt_invoice_custom_sections_unique;
DROP INDEX IF EXISTS public.index_webhooks_on_webhook_endpoint_id;
DROP INDEX IF EXISTS public.index_webhooks_on_updated_at_for_cleanup;
DROP INDEX IF EXISTS public.index_webhooks_on_organization_id;
DROP INDEX IF EXISTS public.index_webhooks_on_object_type_and_object_id_and_webhook_type;
DROP INDEX IF EXISTS public.index_webhooks_on_endpoint_status_and_timestamps;
DROP INDEX IF EXISTS public.index_webhooks_on_endpoint_and_timestamps;
DROP INDEX IF EXISTS public.index_webhooks_for_query;
DROP INDEX IF EXISTS public.index_webhook_endpoints_on_webhook_url_and_organization_id;
DROP INDEX IF EXISTS public.index_webhook_endpoints_on_organization_id;
DROP INDEX IF EXISTS public.index_wallets_on_ready_to_be_refreshed;
DROP INDEX IF EXISTS public.index_wallets_on_payment_method_id;
DROP INDEX IF EXISTS public.index_wallets_on_organization_id_and_customer_id;
DROP INDEX IF EXISTS public.index_wallets_on_organization_id;
DROP INDEX IF EXISTS public.index_wallets_on_customer_id;
DROP INDEX IF EXISTS public.index_wallets_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_wallets_invoice_custom_sections_unique;
DROP INDEX IF EXISTS public.index_wallets_invoice_custom_sections_on_wallet_id;
DROP INDEX IF EXISTS public.index_wallets_invoice_custom_sections_on_organization_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_wallet_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_voided_invoice_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_payment_method_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_organization_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_invoice_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_credit_note_id;
DROP INDEX IF EXISTS public.index_wallet_transactions_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_wallet_transaction_consumptions_on_organization_id;
DROP INDEX IF EXISTS public.index_wallet_targets_on_wallet_id;
DROP INDEX IF EXISTS public.index_wallet_targets_on_organization_id;
DROP INDEX IF EXISTS public.index_wallet_targets_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_versions_on_item_type_and_item_id;
DROP INDEX IF EXISTS public.index_user_devices_on_user_id_and_fingerprint;
DROP INDEX IF EXISTS public.index_usage_thresholds_on_subscription_id;
DROP INDEX IF EXISTS public.index_usage_thresholds_on_plan_id;
DROP INDEX IF EXISTS public.index_usage_thresholds_on_organization_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_triggered_alerts_on_wallet_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_triggered_alerts_on_subscription_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_triggered_alerts_on_organization_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_alerts_on_wallet_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_alerts_on_subscription_external_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_alerts_on_organization_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_alerts_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_usage_monitoring_alert_thresholds_on_organization_id;
DROP INDEX IF EXISTS public.index_unique_transaction_id;
DROP INDEX IF EXISTS public.index_unique_terminating_invoice_subscription;
DROP INDEX IF EXISTS public.index_unique_starting_invoice_subscription;
DROP INDEX IF EXISTS public.index_unique_quotes_on_organization_sequential_id;
DROP INDEX IF EXISTS public.index_unique_quotes_on_organization_number;
DROP INDEX IF EXISTS public.index_unique_quote_versions_on_share_token;
DROP INDEX IF EXISTS public.index_unique_quote_versions_on_quote_sequential_id;
DROP INDEX IF EXISTS public.index_unique_quote_versions_on_quote_active_status;
DROP INDEX IF EXISTS public.index_unique_quote_owners_on_quote_user;
DROP INDEX IF EXISTS public.index_unique_orders_on_organization_sequential_id;
DROP INDEX IF EXISTS public.index_unique_orders_on_organization_number;
DROP INDEX IF EXISTS public.index_unique_order_forms_on_organization_sequential_id;
DROP INDEX IF EXISTS public.index_unique_order_forms_on_organization_number;
DROP INDEX IF EXISTS public.index_unique_applied_to_organization_per_organization;
DROP INDEX IF EXISTS public.index_uniq_wallet_code_per_customer;
DROP INDEX IF EXISTS public.index_uniq_invoice_subscriptions_on_fixed_charges_boundaries;
DROP INDEX IF EXISTS public.index_uniq_invoice_subscriptions_on_charges_from_to_datetime;
DROP INDEX IF EXISTS public.index_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_status;
DROP INDEX IF EXISTS public.index_subscriptions_on_started_at_and_ending_at;
DROP INDEX IF EXISTS public.index_subscriptions_on_started_at;
DROP INDEX IF EXISTS public.index_subscriptions_on_previous_subscription_id_and_status;
DROP INDEX IF EXISTS public.index_subscriptions_on_plan_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_payment_method_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_organization_id_name_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_subscriptions_on_organization_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_last_received_event_on_null;
DROP INDEX IF EXISTS public.index_subscriptions_on_last_received_event_on;
DROP INDEX IF EXISTS public.index_subscriptions_on_external_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_ending_at_active;
DROP INDEX IF EXISTS public.index_subscriptions_on_customer_id;
DROP INDEX IF EXISTS public.index_subscriptions_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_subscriptions_invoice_custom_sections_unique;
DROP INDEX IF EXISTS public.index_subscriptions_invoice_custom_sections_on_subscription_id;
DROP INDEX IF EXISTS public.index_subscriptions_invoice_custom_sections_on_organization_id;
DROP INDEX IF EXISTS public.index_subscription_fixed_charge_units_overrides_on_deleted_at;
DROP INDEX IF EXISTS public.index_subscription_activation_rules_on_organization_id;
DROP INDEX IF EXISTS public.index_sub_fc_units_overrides_on_sub_id_and_fc_id;
DROP INDEX IF EXISTS public.index_search_quantified_events;
DROP INDEX IF EXISTS public.index_rtr_invoice_custom_sections_unique;
DROP INDEX IF EXISTS public.index_roles_on_organization_id;
DROP INDEX IF EXISTS public.index_roles_by_unique_admin;
DROP INDEX IF EXISTS public.index_roles_by_code_per_organization;
DROP INDEX IF EXISTS public.index_refunds_on_refundable;
DROP INDEX IF EXISTS public.index_refunds_on_payment_provider_id;
DROP INDEX IF EXISTS public.index_refunds_on_payment_provider_customer_id;
DROP INDEX IF EXISTS public.index_refunds_on_payment_id;
DROP INDEX IF EXISTS public.index_refunds_on_organization_id;
DROP INDEX IF EXISTS public.index_refunds_on_credit_note_id;
DROP INDEX IF EXISTS public.index_recurring_transaction_rules_on_wallet_id;
DROP INDEX IF EXISTS public.index_recurring_transaction_rules_on_started_at;
DROP INDEX IF EXISTS public.index_recurring_transaction_rules_on_payment_method_id;
DROP INDEX IF EXISTS public.index_recurring_transaction_rules_on_organization_id;
DROP INDEX IF EXISTS public.index_recurring_transaction_rules_on_expiration_at;
DROP INDEX IF EXISTS public.index_quotes_on_subscription_id;
DROP INDEX IF EXISTS public.index_quotes_on_customer_id;
DROP INDEX IF EXISTS public.index_quote_versions_on_quote_id;
DROP INDEX IF EXISTS public.index_quote_versions_on_organization_id;
DROP INDEX IF EXISTS public.index_quote_owners_on_user_id;
DROP INDEX IF EXISTS public.index_quote_owners_on_organization_id;
DROP INDEX IF EXISTS public.index_quantified_events_on_organization_id;
DROP INDEX IF EXISTS public.index_quantified_events_on_group_id;
DROP INDEX IF EXISTS public.index_quantified_events_on_external_id;
DROP INDEX IF EXISTS public.index_quantified_events_on_deleted_at;
DROP INDEX IF EXISTS public.index_quantified_events_on_charge_filter_id;
DROP INDEX IF EXISTS public.index_quantified_events_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_pricing_units_on_organization_id;
DROP INDEX IF EXISTS public.index_pricing_units_on_code_and_organization_id;
DROP INDEX IF EXISTS public.index_pricing_unit_usages_on_pricing_unit_id;
DROP INDEX IF EXISTS public.index_pricing_unit_usages_on_organization_id;
DROP INDEX IF EXISTS public.index_pricing_unit_usages_on_fee_id;
DROP INDEX IF EXISTS public.index_presentation_breakdowns_on_organization_id;
DROP INDEX IF EXISTS public.index_presentation_breakdowns_on_fee_id;
DROP INDEX IF EXISTS public.index_plans_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_plans_taxes_on_plan_id_and_tax_id;
DROP INDEX IF EXISTS public.index_plans_taxes_on_plan_id;
DROP INDEX IF EXISTS public.index_plans_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_plans_on_parent_id;
DROP INDEX IF EXISTS public.index_plans_on_organization_id_name_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_plans_on_organization_id_code_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_plans_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_plans_on_organization_id;
DROP INDEX IF EXISTS public.index_plans_on_deleted_at;
DROP INDEX IF EXISTS public.index_plans_on_created_at;
DROP INDEX IF EXISTS public.index_plans_on_bill_fixed_charges_monthly;
DROP INDEX IF EXISTS public.index_pending_vies_checks_on_organization_id;
DROP INDEX IF EXISTS public.index_pending_vies_checks_on_customer_id;
DROP INDEX IF EXISTS public.index_pending_vies_checks_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_pending_active_subscriptions_on_plan_id_and_status;
DROP INDEX IF EXISTS public.index_payments_on_provider_payment_id_and_payment_provider_id;
DROP INDEX IF EXISTS public.index_payments_on_payment_type;
DROP INDEX IF EXISTS public.index_payments_on_payment_provider_id;
DROP INDEX IF EXISTS public.index_payments_on_payment_provider_customer_id;
DROP INDEX IF EXISTS public.index_payments_on_payment_method_id;
DROP INDEX IF EXISTS public.index_payments_on_payable_type_and_payable_id;
DROP INDEX IF EXISTS public.index_payments_on_payable_id_and_payable_type_and_error_code;
DROP INDEX IF EXISTS public.index_payments_on_payable_id_and_payable_type;
DROP INDEX IF EXISTS public.index_payments_on_organization_id_reference_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_payments_on_organization_id;
DROP INDEX IF EXISTS public.index_payments_on_invoice_id;
DROP INDEX IF EXISTS public.index_payments_on_customer_id;
DROP INDEX IF EXISTS public.index_payments_by_cursor;
DROP INDEX IF EXISTS public.index_payment_requests_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_requests_on_dunning_campaign_id;
DROP INDEX IF EXISTS public.index_payment_requests_on_customer_id;
DROP INDEX IF EXISTS public.index_payment_receipts_on_payment_id;
DROP INDEX IF EXISTS public.index_payment_receipts_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_receipts_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_payment_providers_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_providers_on_code_and_organization_id;
DROP INDEX IF EXISTS public.index_payment_provider_customers_on_provider_customer_id;
DROP INDEX IF EXISTS public.index_payment_provider_customers_on_payment_provider_id;
DROP INDEX IF EXISTS public.index_payment_provider_customers_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_provider_customers_on_customer_id_and_type;
DROP INDEX IF EXISTS public.index_payment_methods_on_provider_method_type;
DROP INDEX IF EXISTS public.index_payment_methods_on_provider_customer_and_provider_method;
DROP INDEX IF EXISTS public.index_payment_methods_on_payment_provider_id;
DROP INDEX IF EXISTS public.index_payment_methods_on_payment_provider_customer_id;
DROP INDEX IF EXISTS public.index_payment_methods_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_methods_on_customer_id;
DROP INDEX IF EXISTS public.index_payment_intents_on_organization_id;
DROP INDEX IF EXISTS public.index_payment_intents_on_invoice_id_and_status;
DROP INDEX IF EXISTS public.index_payment_intents_on_invoice_id;
DROP INDEX IF EXISTS public.index_password_resets_on_user_id;
DROP INDEX IF EXISTS public.index_password_resets_on_token;
DROP INDEX IF EXISTS public.index_organizations_on_slug;
DROP INDEX IF EXISTS public.index_organizations_on_hmac_key;
DROP INDEX IF EXISTS public.index_organizations_on_api_key;
DROP INDEX IF EXISTS public.index_orders_on_organization_id_and_status;
DROP INDEX IF EXISTS public.index_orders_on_organization_id_and_created_at;
DROP INDEX IF EXISTS public.index_orders_on_order_form_id;
DROP INDEX IF EXISTS public.index_orders_on_customer_id;
DROP INDEX IF EXISTS public.index_order_forms_on_quote_version_id;
DROP INDEX IF EXISTS public.index_order_forms_on_organization_id_and_status;
DROP INDEX IF EXISTS public.index_order_forms_on_organization_id_and_expires_at;
DROP INDEX IF EXISTS public.index_order_forms_on_organization_id_and_created_at;
DROP INDEX IF EXISTS public.index_order_forms_on_customer_id;
DROP INDEX IF EXISTS public.index_memberships_on_user_id_and_organization_id;
DROP INDEX IF EXISTS public.index_memberships_on_user_id;
DROP INDEX IF EXISTS public.index_memberships_on_organization_id;
DROP INDEX IF EXISTS public.index_memberships_by_id_and_organization;
DROP INDEX IF EXISTS public.index_membership_roles_uniqueness;
DROP INDEX IF EXISTS public.index_membership_roles_on_role_id;
DROP INDEX IF EXISTS public.index_membership_roles_by_membership_and_organization;
DROP INDEX IF EXISTS public.index_lifetime_usages_on_subscription_id;
DROP INDEX IF EXISTS public.index_lifetime_usages_on_recalculate_invoiced_usage;
DROP INDEX IF EXISTS public.index_lifetime_usages_on_recalculate_current_usage;
DROP INDEX IF EXISTS public.index_lifetime_usages_on_organization_id;
DROP INDEX IF EXISTS public.index_item_metadata_on_value;
DROP INDEX IF EXISTS public.index_item_metadata_on_owner_type_and_owner_id;
DROP INDEX IF EXISTS public.index_item_metadata_on_organization_id;
DROP INDEX IF EXISTS public.index_invoices_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_invoices_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_invoices_taxes_on_invoice_id_and_tax_id;
DROP INDEX IF EXISTS public.index_invoices_taxes_on_invoice_id;
DROP INDEX IF EXISTS public.index_invoices_payment_requests_on_payment_request_id;
DROP INDEX IF EXISTS public.index_invoices_payment_requests_on_organization_id;
DROP INDEX IF EXISTS public.index_invoices_payment_requests_on_invoice_id;
DROP INDEX IF EXISTS public.index_invoices_on_voided_invoice_id;
DROP INDEX IF EXISTS public.index_invoices_on_ready_to_be_refreshed;
DROP INDEX IF EXISTS public.index_invoices_on_payment_method_id;
DROP INDEX IF EXISTS public.index_invoices_on_payment_due_date;
DROP INDEX IF EXISTS public.index_invoices_on_organization_id_number_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_invoices_on_organization_id_and_customer_id;
DROP INDEX IF EXISTS public.index_invoices_on_number;
DROP INDEX IF EXISTS public.index_invoices_on_customer_billing_entity_sequential;
DROP INDEX IF EXISTS public.index_invoices_by_cursor;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_on_subscription_id;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_on_regenerated_invoice_id;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_on_organization_id;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_on_invoice_id_and_subscription_id;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_on_invoice_id;
DROP INDEX IF EXISTS public.index_invoice_subscriptions_boundaries;
DROP INDEX IF EXISTS public.index_invoice_settlements_on_target_invoice_id;
DROP INDEX IF EXISTS public.index_invoice_settlements_on_source_payment_id;
DROP INDEX IF EXISTS public.index_invoice_settlements_on_source_credit_note_id;
DROP INDEX IF EXISTS public.index_invoice_settlements_on_organization_id;
DROP INDEX IF EXISTS public.index_invoice_settlements_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_invoice_metadata_on_organization_id;
DROP INDEX IF EXISTS public.index_invoice_metadata_on_invoice_id_and_key;
DROP INDEX IF EXISTS public.index_invoice_metadata_on_invoice_id;
DROP INDEX IF EXISTS public.index_invoice_custom_sections_on_section_type;
DROP INDEX IF EXISTS public.index_invoice_custom_sections_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_invoice_custom_sections_on_organization_id;
DROP INDEX IF EXISTS public.index_invites_on_token;
DROP INDEX IF EXISTS public.index_invites_on_organization_id;
DROP INDEX IF EXISTS public.index_invites_on_membership_id;
DROP INDEX IF EXISTS public.index_integrations_on_organization_id;
DROP INDEX IF EXISTS public.index_integrations_on_code_and_organization_id;
DROP INDEX IF EXISTS public.index_integration_resources_on_syncable;
DROP INDEX IF EXISTS public.index_integration_resources_on_organization_id;
DROP INDEX IF EXISTS public.index_integration_resources_on_integration_id;
DROP INDEX IF EXISTS public.index_integration_mappings_unique_billing_entity_id_is_null;
DROP INDEX IF EXISTS public.index_integration_mappings_unique_billing_entity_id_is_not_null;
DROP INDEX IF EXISTS public.index_integration_mappings_on_organization_id;
DROP INDEX IF EXISTS public.index_integration_mappings_on_mappable;
DROP INDEX IF EXISTS public.index_integration_mappings_on_integration_id;
DROP INDEX IF EXISTS public.index_integration_items_on_organization_id;
DROP INDEX IF EXISTS public.index_integration_items_on_integration_id;
DROP INDEX IF EXISTS public.index_integration_customers_on_organization_id;
DROP INDEX IF EXISTS public.index_integration_customers_on_integration_id;
DROP INDEX IF EXISTS public.index_integration_customers_on_external_customer_id;
DROP INDEX IF EXISTS public.index_integration_customers_on_customer_id_and_type;
DROP INDEX IF EXISTS public.index_integration_customers_on_customer_id;
DROP INDEX IF EXISTS public.index_integration_collection_mappings_on_organization_id;
DROP INDEX IF EXISTS public.index_integration_collection_mappings_on_integration_id;
DROP INDEX IF EXISTS public.index_integration_collection_mappings_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_int_items_on_external_id_and_int_id_and_type;
DROP INDEX IF EXISTS public.index_int_collection_mappings_unique_billing_entity_is_null;
DROP INDEX IF EXISTS public.index_int_collection_mappings_unique_billing_entity_is_not_null;
DROP INDEX IF EXISTS public.index_inbound_webhooks_on_status_and_processing_at;
DROP INDEX IF EXISTS public.index_inbound_webhooks_on_status_and_created_at;
DROP INDEX IF EXISTS public.index_inbound_webhooks_on_organization_id;
DROP INDEX IF EXISTS public.index_idempotency_records_on_resource_type_and_resource_id;
DROP INDEX IF EXISTS public.index_idempotency_records_on_organization_id;
DROP INDEX IF EXISTS public.index_idempotency_records_on_idempotency_key;
DROP INDEX IF EXISTS public.index_groups_on_parent_group_id;
DROP INDEX IF EXISTS public.index_groups_on_deleted_at;
DROP INDEX IF EXISTS public.index_groups_on_billable_metric_id_and_parent_group_id;
DROP INDEX IF EXISTS public.index_groups_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_group_properties_on_group_id;
DROP INDEX IF EXISTS public.index_group_properties_on_deleted_at;
DROP INDEX IF EXISTS public.index_group_properties_on_charge_id_and_group_id;
DROP INDEX IF EXISTS public.index_group_properties_on_charge_id;
DROP INDEX IF EXISTS public.index_fixed_charges_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_fixed_charges_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_fixed_charges_taxes_on_fixed_charge_id_and_tax_id;
DROP INDEX IF EXISTS public.index_fixed_charges_taxes_on_fixed_charge_id;
DROP INDEX IF EXISTS public.index_fixed_charges_on_plan_id_and_code;
DROP INDEX IF EXISTS public.index_fixed_charges_on_plan_id;
DROP INDEX IF EXISTS public.index_fixed_charges_on_parent_id;
DROP INDEX IF EXISTS public.index_fixed_charges_on_organization_id;
DROP INDEX IF EXISTS public.index_fixed_charges_on_deleted_at;
DROP INDEX IF EXISTS public.index_fixed_charges_on_add_on_id;
DROP INDEX IF EXISTS public.index_fixed_charge_events_on_subscription_id;
DROP INDEX IF EXISTS public.index_fixed_charge_events_on_organization_id;
DROP INDEX IF EXISTS public.index_fixed_charge_events_on_fixed_charge_id;
DROP INDEX IF EXISTS public.index_fixed_charge_events_on_deleted_at;
DROP INDEX IF EXISTS public.index_fees_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_fees_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_fees_taxes_on_fee_id_and_tax_id;
DROP INDEX IF EXISTS public.index_fees_taxes_on_fee_id;
DROP INDEX IF EXISTS public.index_fees_on_true_up_parent_fee_id;
DROP INDEX IF EXISTS public.index_fees_on_subscription_id;
DROP INDEX IF EXISTS public.index_fees_on_pay_in_advance_event_transaction_id;
DROP INDEX IF EXISTS public.index_fees_on_original_fee_id;
DROP INDEX IF EXISTS public.index_fees_on_organization_id_and_created_at_and_id;
DROP INDEX IF EXISTS public.index_fees_on_organization_id;
DROP INDEX IF EXISTS public.index_fees_on_invoiceable;
DROP INDEX IF EXISTS public.index_fees_on_invoice_id;
DROP INDEX IF EXISTS public.index_fees_on_group_id;
DROP INDEX IF EXISTS public.index_fees_on_fixed_charge_id;
DROP INDEX IF EXISTS public.index_fees_on_deleted_at;
DROP INDEX IF EXISTS public.index_fees_on_charge_id_and_invoice_id;
DROP INDEX IF EXISTS public.index_fees_on_charge_id;
DROP INDEX IF EXISTS public.index_fees_on_charge_filter_id;
DROP INDEX IF EXISTS public.index_fees_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_fees_on_applied_add_on_id;
DROP INDEX IF EXISTS public.index_fees_on_add_on_id;
DROP INDEX IF EXISTS public.index_events_on_organization_id_and_transaction_id;
DROP INDEX IF EXISTS public.index_events_on_organization_id_and_timestamp;
DROP INDEX IF EXISTS public.index_events_on_organization_id_and_created_at;
DROP INDEX IF EXISTS public.index_events_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_events_on_organization_id;
DROP INDEX IF EXISTS public.index_events_on_created_at;
DROP INDEX IF EXISTS public.index_error_details_on_owner;
DROP INDEX IF EXISTS public.index_error_details_on_organization_id;
DROP INDEX IF EXISTS public.index_error_details_on_error_code;
DROP INDEX IF EXISTS public.index_error_details_on_deleted_at;
DROP INDEX IF EXISTS public.index_entitlement_subscription_feature_removals_on_deleted_at;
DROP INDEX IF EXISTS public.index_entitlement_privileges_on_organization_id;
DROP INDEX IF EXISTS public.index_entitlement_privileges_on_entitlement_feature_id;
DROP INDEX IF EXISTS public.index_entitlement_features_on_organization_id;
DROP INDEX IF EXISTS public.index_entitlement_entitlements_on_subscription_id;
DROP INDEX IF EXISTS public.index_entitlement_entitlements_on_plan_id;
DROP INDEX IF EXISTS public.index_entitlement_entitlements_on_organization_id;
DROP INDEX IF EXISTS public.index_entitlement_entitlements_on_entitlement_feature_id;
DROP INDEX IF EXISTS public.index_entitlement_entitlement_values_on_organization_id;
DROP INDEX IF EXISTS public.index_enriched_store_migrations_on_organization_id;
DROP INDEX IF EXISTS public.index_dunning_campaigns_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_dunning_campaigns_on_organization_id;
DROP INDEX IF EXISTS public.index_dunning_campaigns_on_deleted_at;
DROP INDEX IF EXISTS public.index_dunning_campaign_thresholds_on_organization_id;
DROP INDEX IF EXISTS public.index_dunning_campaign_thresholds_on_dunning_campaign_id;
DROP INDEX IF EXISTS public.index_dunning_campaign_thresholds_on_deleted_at;
DROP INDEX IF EXISTS public.index_data_exports_on_organization_id;
DROP INDEX IF EXISTS public.index_data_exports_on_membership_id;
DROP INDEX IF EXISTS public.index_data_export_parts_on_organization_id;
DROP INDEX IF EXISTS public.index_data_export_parts_on_data_export_id;
DROP INDEX IF EXISTS public.index_daily_usages_on_usage_date;
DROP INDEX IF EXISTS public.index_daily_usages_on_subscription_id_and_usage_date;
DROP INDEX IF EXISTS public.index_daily_usages_on_subscription_id;
DROP INDEX IF EXISTS public.index_daily_usages_on_organization_id;
DROP INDEX IF EXISTS public.index_daily_usages_on_customer_id;
DROP INDEX IF EXISTS public.index_customers_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_customers_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_customers_taxes_on_customer_id_and_tax_id;
DROP INDEX IF EXISTS public.index_customers_taxes_on_customer_id;
DROP INDEX IF EXISTS public.index_customers_on_sequential_id;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_name_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_legal_name_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_lastname_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_kept;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_firstname_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_external_id_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_organization_id_email_gin_trgm_ops;
DROP INDEX IF EXISTS public.index_customers_on_org_id_and_sequential_id_unique;
DROP INDEX IF EXISTS public.index_customers_on_external_id_and_organization_id;
DROP INDEX IF EXISTS public.index_customers_on_external_id;
DROP INDEX IF EXISTS public.index_customers_on_deleted_at;
DROP INDEX IF EXISTS public.index_customers_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_customers_on_awaiting_wallet_refresh;
DROP INDEX IF EXISTS public.index_customers_on_applied_dunning_campaign_id;
DROP INDEX IF EXISTS public.index_customers_on_account_type;
DROP INDEX IF EXISTS public.index_customers_invoice_custom_sections_on_organization_id;
DROP INDEX IF EXISTS public.index_customers_invoice_custom_sections_on_customer_id;
DROP INDEX IF EXISTS public.index_customers_invoice_custom_sections_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_customers_by_cursor;
DROP INDEX IF EXISTS public.index_customer_metadata_on_organization_id;
DROP INDEX IF EXISTS public.index_customer_metadata_on_customer_id_and_key;
DROP INDEX IF EXISTS public.index_customer_metadata_on_customer_id;
DROP INDEX IF EXISTS public.index_credits_on_progressive_billing_invoice_id;
DROP INDEX IF EXISTS public.index_credits_on_organization_id;
DROP INDEX IF EXISTS public.index_credits_on_invoice_id;
DROP INDEX IF EXISTS public.index_credits_on_credit_note_id;
DROP INDEX IF EXISTS public.index_credits_on_applied_coupon_id;
DROP INDEX IF EXISTS public.index_credit_notes_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_credit_notes_taxes_on_tax_code;
DROP INDEX IF EXISTS public.index_credit_notes_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_credit_notes_taxes_on_credit_note_id_and_tax_code;
DROP INDEX IF EXISTS public.index_credit_notes_taxes_on_credit_note_id;
DROP INDEX IF EXISTS public.index_credit_notes_on_organization_id;
DROP INDEX IF EXISTS public.index_credit_notes_on_invoice_id_and_sequential_id;
DROP INDEX IF EXISTS public.index_credit_notes_on_invoice_id;
DROP INDEX IF EXISTS public.index_credit_notes_on_customer_id;
DROP INDEX IF EXISTS public.index_credit_note_items_on_organization_id;
DROP INDEX IF EXISTS public.index_credit_note_items_on_fee_id;
DROP INDEX IF EXISTS public.index_credit_note_items_on_credit_note_id;
DROP INDEX IF EXISTS public.index_coupons_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_coupons_on_organization_id;
DROP INDEX IF EXISTS public.index_coupons_on_deleted_at;
DROP INDEX IF EXISTS public.index_coupon_targets_on_plan_id;
DROP INDEX IF EXISTS public.index_coupon_targets_on_organization_id;
DROP INDEX IF EXISTS public.index_coupon_targets_on_deleted_at;
DROP INDEX IF EXISTS public.index_coupon_targets_on_coupon_id;
DROP INDEX IF EXISTS public.index_coupon_targets_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_commitments_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_commitments_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_commitments_taxes_on_commitment_id_and_tax_id;
DROP INDEX IF EXISTS public.index_commitments_taxes_on_commitment_id;
DROP INDEX IF EXISTS public.index_commitments_on_plan_id;
DROP INDEX IF EXISTS public.index_commitments_on_organization_id;
DROP INDEX IF EXISTS public.index_commitments_on_commitment_type_and_plan_id;
DROP INDEX IF EXISTS public.index_charges_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_charges_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_charges_taxes_on_charge_id_and_tax_id;
DROP INDEX IF EXISTS public.index_charges_taxes_on_charge_id;
DROP INDEX IF EXISTS public.index_charges_pay_in_advance;
DROP INDEX IF EXISTS public.index_charges_on_plan_id_and_code;
DROP INDEX IF EXISTS public.index_charges_on_plan_id_and_billable_metric_id_and_prorated;
DROP INDEX IF EXISTS public.index_charges_on_plan_id;
DROP INDEX IF EXISTS public.index_charges_on_parent_id;
DROP INDEX IF EXISTS public.index_charges_on_organization_id;
DROP INDEX IF EXISTS public.index_charges_on_deleted_at;
DROP INDEX IF EXISTS public.index_charges_on_billable_metric_id_all;
DROP INDEX IF EXISTS public.index_charges_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_charges_on_accepts_target_wallet;
DROP INDEX IF EXISTS public.index_charge_filters_on_organization_id;
DROP INDEX IF EXISTS public.index_charge_filters_on_deleted_at;
DROP INDEX IF EXISTS public.index_charge_filters_on_charge_id;
DROP INDEX IF EXISTS public.index_charge_filter_values_on_organization_id;
DROP INDEX IF EXISTS public.index_charge_filter_values_on_deleted_at;
DROP INDEX IF EXISTS public.index_charge_filter_values_on_charge_filter_id;
DROP INDEX IF EXISTS public.index_charge_filter_values_on_billable_metric_filter_id;
DROP INDEX IF EXISTS public.index_cached_aggregations_on_external_subscription_id;
DROP INDEX IF EXISTS public.index_cached_aggregations_on_event_transaction_id;
DROP INDEX IF EXISTS public.index_cached_aggregations_on_charge_id;
DROP INDEX IF EXISTS public.index_billing_entities_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_billing_entities_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_billing_entities_taxes_on_billing_entity_id_and_tax_id;
DROP INDEX IF EXISTS public.index_billing_entities_taxes_on_billing_entity_id;
DROP INDEX IF EXISTS public.index_billing_entities_on_organization_id;
DROP INDEX IF EXISTS public.index_billing_entities_on_code_and_organization_id;
DROP INDEX IF EXISTS public.index_billing_entities_on_applied_dunning_campaign_id;
DROP INDEX IF EXISTS public.index_billable_metrics_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_billable_metrics_on_organization_id;
DROP INDEX IF EXISTS public.index_billable_metrics_on_org_id_and_code_and_expr;
DROP INDEX IF EXISTS public.index_billable_metrics_on_deleted_at;
DROP INDEX IF EXISTS public.index_billable_metric_filters_on_organization_id;
DROP INDEX IF EXISTS public.index_billable_metric_filters_on_deleted_at;
DROP INDEX IF EXISTS public.index_billable_metric_filters_on_billable_metric_id;
DROP INDEX IF EXISTS public.index_applied_usage_thresholds_on_usage_threshold_id;
DROP INDEX IF EXISTS public.index_applied_usage_thresholds_on_organization_id;
DROP INDEX IF EXISTS public.index_applied_usage_thresholds_on_invoice_id;
DROP INDEX IF EXISTS public.index_applied_pricing_units_on_pricing_unitable;
DROP INDEX IF EXISTS public.index_applied_pricing_units_on_pricing_unit_id;
DROP INDEX IF EXISTS public.index_applied_pricing_units_on_organization_id;
DROP INDEX IF EXISTS public.index_applied_invoice_custom_sections_on_organization_id;
DROP INDEX IF EXISTS public.index_applied_invoice_custom_sections_on_invoice_id;
DROP INDEX IF EXISTS public.index_applied_coupons_on_organization_id;
DROP INDEX IF EXISTS public.index_applied_coupons_on_customer_id;
DROP INDEX IF EXISTS public.index_applied_coupons_on_coupon_id;
DROP INDEX IF EXISTS public.index_applied_add_ons_on_customer_id;
DROP INDEX IF EXISTS public.index_applied_add_ons_on_add_on_id_and_customer_id;
DROP INDEX IF EXISTS public.index_applied_add_ons_on_add_on_id;
DROP INDEX IF EXISTS public.index_api_keys_on_value;
DROP INDEX IF EXISTS public.index_api_keys_on_organization_id;
DROP INDEX IF EXISTS public.index_ai_conversations_on_organization_id;
DROP INDEX IF EXISTS public.index_ai_conversations_on_membership_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_subscription_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_organization_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_invoice_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_group_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_fee_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_charge_id;
DROP INDEX IF EXISTS public.index_adjusted_fees_on_charge_filter_id;
DROP INDEX IF EXISTS public.index_add_ons_taxes_on_tax_id;
DROP INDEX IF EXISTS public.index_add_ons_taxes_on_organization_id;
DROP INDEX IF EXISTS public.index_add_ons_taxes_on_add_on_id_and_tax_id;
DROP INDEX IF EXISTS public.index_add_ons_taxes_on_add_on_id;
DROP INDEX IF EXISTS public.index_add_ons_on_organization_id_and_code;
DROP INDEX IF EXISTS public.index_add_ons_on_organization_id;
DROP INDEX IF EXISTS public.index_add_ons_on_deleted_at;
DROP INDEX IF EXISTS public.index_active_storage_variant_records_uniqueness;
DROP INDEX IF EXISTS public.index_active_storage_blobs_on_key;
DROP INDEX IF EXISTS public.index_active_storage_attachments_uniqueness;
DROP INDEX IF EXISTS public.index_active_storage_attachments_on_blob_id;
DROP INDEX IF EXISTS public.index_active_metric_filters;
DROP INDEX IF EXISTS public.index_active_charge_filters;
DROP INDEX IF EXISTS public.index_active_charge_filter_values;
DROP INDEX IF EXISTS public.index_activation_rules_pending_with_expiry;
DROP INDEX IF EXISTS public.idx_wallet_tx_consumptions_inbound_outbound;
DROP INDEX IF EXISTS public.idx_wallet_transactions_available_inbound;
DROP INDEX IF EXISTS public.idx_usage_thresholds_subscription_recurring;
DROP INDEX IF EXISTS public.idx_usage_thresholds_plan_recurring;
DROP INDEX IF EXISTS public.idx_usage_thresholds_on_amount_subscription_recurring;
DROP INDEX IF EXISTS public.idx_usage_thresholds_on_amount_plan_recurring;
DROP INDEX IF EXISTS public.idx_unique_tax_code_per_organization;
DROP INDEX IF EXISTS public.idx_unique_privilege_removal_per_subscription;
DROP INDEX IF EXISTS public.idx_unique_feature_removal_per_subscription;
DROP INDEX IF EXISTS public.idx_unique_feature_per_subscription;
DROP INDEX IF EXISTS public.idx_unique_feature_per_plan;
DROP INDEX IF EXISTS public.idx_subscription_unique;
DROP INDEX IF EXISTS public.idx_privileges_code_unique_per_feature;
DROP INDEX IF EXISTS public.idx_pay_in_advance_duplication_guard_charge_filter;
DROP INDEX IF EXISTS public.idx_pay_in_advance_duplication_guard_charge;
DROP INDEX IF EXISTS public.idx_on_wallet_transaction_id_ac2826109e;
DROP INDEX IF EXISTS public.idx_on_usage_threshold_id_invoice_id_cb82cdf163;
DROP INDEX IF EXISTS public.idx_on_usage_monitoring_alert_id_recurring_756a2a370d;
DROP INDEX IF EXISTS public.idx_on_usage_monitoring_alert_id_78eb24d06c;
DROP INDEX IF EXISTS public.idx_on_usage_monitoring_alert_id_4290c95dec;
DROP INDEX IF EXISTS public.idx_on_subscription_id_type_8feb7b9623;
DROP INDEX IF EXISTS public.idx_on_subscription_id_bd763c5aa3;
DROP INDEX IF EXISTS public.idx_on_subscription_id_b41afd08e0;
DROP INDEX IF EXISTS public.idx_on_subscription_id_295edd8bb3;
DROP INDEX IF EXISTS public.idx_on_recurring_transaction_rule_id_fba3d39cca;
DROP INDEX IF EXISTS public.idx_on_plan_id_billable_metric_id_pay_in_advance_4a205974cb;
DROP INDEX IF EXISTS public.idx_on_outbound_wallet_transaction_id_cf6ff733c6;
DROP INDEX IF EXISTS public.idx_on_organization_id_subscription_at_created_at_id;
DROP INDEX IF EXISTS public.idx_on_organization_id_provider_payment_id_gin_trgm_2bcf073c0b;
DROP INDEX IF EXISTS public.idx_on_organization_id_organization_sequential_id_2387146f54;
DROP INDEX IF EXISTS public.idx_on_organization_id_external_subscription_id_df3a30d96d;
DROP INDEX IF EXISTS public.idx_on_organization_id_external_id_gin_trgm_ops_fb8058a497;
DROP INDEX IF EXISTS public.idx_on_organization_id_e742f77454;
DROP INDEX IF EXISTS public.idx_on_organization_id_e73219f079;
DROP INDEX IF EXISTS public.idx_on_organization_id_deleted_at_225e3f789d;
DROP INDEX IF EXISTS public.idx_on_organization_id_ccdf05cbfe;
DROP INDEX IF EXISTS public.idx_on_organization_id_83703a45f4;
DROP INDEX IF EXISTS public.idx_on_organization_id_7020c3c43a;
DROP INDEX IF EXISTS public.idx_on_organization_id_376a587b04;
DROP INDEX IF EXISTS public.idx_on_organization_id_2be2ef98ea;
DROP INDEX IF EXISTS public.idx_on_invoice_id_payment_request_id_aa550779a4;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_d8b9068730;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_ccb39e9622;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_b381df5bb5;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_aca4661c33;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_5f37496c8c;
DROP INDEX IF EXISTS public.idx_on_invoice_custom_section_id_50c2a2e7c0;
DROP INDEX IF EXISTS public.idx_on_inbound_wallet_transaction_id_e54d00758d;
DROP INDEX IF EXISTS public.idx_on_fixed_charge_id_06503ae1a5;
DROP INDEX IF EXISTS public.idx_on_entitlement_privilege_id_entitlement_entitle_9d0542eb1a;
DROP INDEX IF EXISTS public.idx_on_entitlement_privilege_id_9946ccf514;
DROP INDEX IF EXISTS public.idx_on_entitlement_privilege_id_6a228dc433;
DROP INDEX IF EXISTS public.idx_on_entitlement_feature_id_821ae72311;
DROP INDEX IF EXISTS public.idx_on_entitlement_entitlement_id_48c0b3356a;
DROP INDEX IF EXISTS public.idx_on_enriched_store_migration_id_e409c5dc43;
DROP INDEX IF EXISTS public.idx_on_dunning_campaign_id_currency_fbf233b2ae;
DROP INDEX IF EXISTS public.idx_on_billing_entity_id_invoice_custom_section_id_bd78c547d3;
DROP INDEX IF EXISTS public.idx_on_billing_entity_id_customer_id_invoice_custom_e7aada65cb;
DROP INDEX IF EXISTS public.idx_on_billing_entity_id_billing_entity_sequential__bd26b2e655;
DROP INDEX IF EXISTS public.idx_on_billing_entity_id_724373e5ae;
DROP INDEX IF EXISTS public.idx_invoices_organization_id_status;
DROP INDEX IF EXISTS public.idx_invoice_subscriptions_on_subscription_with_timestamps;
DROP INDEX IF EXISTS public.idx_features_code_unique_per_organization;
DROP INDEX IF EXISTS public.idx_events_for_distinct_codes;
DROP INDEX IF EXISTS public.idx_events_billing_lookup;
DROP INDEX IF EXISTS public.idx_enriched_store_sub_migrations_on_migration_and_subscription;
DROP INDEX IF EXISTS public.idx_enqueued_per_organization;
DROP INDEX IF EXISTS public.idx_cached_aggregation_filtered_lookup;
DROP INDEX IF EXISTS public.idx_billable_metrics_id_agg_type;
DROP INDEX IF EXISTS public.idx_alerts_unique_per_type_per_wallet;
DROP INDEX IF EXISTS public.idx_alerts_unique_per_type_per_subscription_with_bm;
DROP INDEX IF EXISTS public.idx_alerts_unique_per_type_per_subscription;
DROP INDEX IF EXISTS public.idx_alerts_code_unique_per_subscription;
DROP INDEX IF EXISTS public.idx_aggregation_lookup;
DROP INDEX IF EXISTS public.idx_billing_on_enriched_events;
DROP INDEX IF EXISTS public.idx_lookup_on_enriched_events;
DROP INDEX IF EXISTS public.idx_unique_on_enriched_events;
DROP INDEX IF EXISTS public.index_enriched_events_on_event_id;
ALTER TABLE IF EXISTS ONLY public.webhooks DROP CONSTRAINT IF EXISTS webhooks_pkey;
ALTER TABLE IF EXISTS ONLY public.webhook_endpoints DROP CONSTRAINT IF EXISTS webhook_endpoints_pkey;
ALTER TABLE IF EXISTS ONLY public.wallets DROP CONSTRAINT IF EXISTS wallets_pkey;
ALTER TABLE IF EXISTS ONLY public.wallets_invoice_custom_sections DROP CONSTRAINT IF EXISTS wallets_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_pkey;
ALTER TABLE IF EXISTS ONLY public.wallet_transactions_invoice_custom_sections DROP CONSTRAINT IF EXISTS wallet_transactions_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.wallet_transaction_consumptions DROP CONSTRAINT IF EXISTS wallet_transaction_consumptions_pkey;
ALTER TABLE IF EXISTS ONLY public.wallet_targets DROP CONSTRAINT IF EXISTS wallet_targets_pkey;
ALTER TABLE IF EXISTS ONLY public.versions DROP CONSTRAINT IF EXISTS versions_pkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.user_devices DROP CONSTRAINT IF EXISTS user_devices_pkey;
ALTER TABLE IF EXISTS ONLY public.usage_thresholds DROP CONSTRAINT IF EXISTS usage_thresholds_pkey;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_triggered_alerts DROP CONSTRAINT IF EXISTS usage_monitoring_triggered_alerts_pkey;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_subscription_activities DROP CONSTRAINT IF EXISTS usage_monitoring_subscription_activities_pkey;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alerts DROP CONSTRAINT IF EXISTS usage_monitoring_alerts_pkey;
ALTER TABLE IF EXISTS ONLY public.usage_monitoring_alert_thresholds DROP CONSTRAINT IF EXISTS usage_monitoring_alert_thresholds_pkey;
ALTER TABLE IF EXISTS ONLY public.taxes DROP CONSTRAINT IF EXISTS taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_pkey;
ALTER TABLE IF EXISTS ONLY public.subscriptions_invoice_custom_sections DROP CONSTRAINT IF EXISTS subscriptions_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.subscription_fixed_charge_units_overrides DROP CONSTRAINT IF EXISTS subscription_fixed_charge_units_overrides_pkey;
ALTER TABLE IF EXISTS ONLY public.subscription_activation_rules DROP CONSTRAINT IF EXISTS subscription_activation_rules_pkey;
ALTER TABLE IF EXISTS ONLY public.schema_migrations DROP CONSTRAINT IF EXISTS schema_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.roles DROP CONSTRAINT IF EXISTS roles_pkey;
ALTER TABLE IF EXISTS ONLY public.refunds DROP CONSTRAINT IF EXISTS refunds_pkey;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules DROP CONSTRAINT IF EXISTS recurring_transaction_rules_pkey;
ALTER TABLE IF EXISTS ONLY public.recurring_transaction_rules_invoice_custom_sections DROP CONSTRAINT IF EXISTS recurring_transaction_rules_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.quotes DROP CONSTRAINT IF EXISTS quotes_pkey;
ALTER TABLE IF EXISTS ONLY public.quote_versions DROP CONSTRAINT IF EXISTS quote_versions_pkey;
ALTER TABLE IF EXISTS ONLY public.quote_owners DROP CONSTRAINT IF EXISTS quote_owners_pkey;
ALTER TABLE IF EXISTS ONLY public.quantified_events DROP CONSTRAINT IF EXISTS quantified_events_pkey;
ALTER TABLE IF EXISTS ONLY public.pricing_units DROP CONSTRAINT IF EXISTS pricing_units_pkey;
ALTER TABLE IF EXISTS ONLY public.pricing_unit_usages DROP CONSTRAINT IF EXISTS pricing_unit_usages_pkey;
ALTER TABLE IF EXISTS ONLY public.presentation_breakdowns DROP CONSTRAINT IF EXISTS presentation_breakdowns_pkey;
ALTER TABLE IF EXISTS ONLY public.plans_taxes DROP CONSTRAINT IF EXISTS plans_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.plans DROP CONSTRAINT IF EXISTS plans_pkey;
ALTER TABLE IF EXISTS ONLY public.pending_vies_checks DROP CONSTRAINT IF EXISTS pending_vies_checks_pkey;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS payments_pkey;
ALTER TABLE IF EXISTS public.payments DROP CONSTRAINT IF EXISTS payments_customer_id_null;
ALTER TABLE IF EXISTS ONLY public.payment_requests DROP CONSTRAINT IF EXISTS payment_requests_pkey;
ALTER TABLE IF EXISTS ONLY public.payment_receipts DROP CONSTRAINT IF EXISTS payment_receipts_pkey;
ALTER TABLE IF EXISTS ONLY public.payment_providers DROP CONSTRAINT IF EXISTS payment_providers_pkey;
ALTER TABLE IF EXISTS ONLY public.payment_provider_customers DROP CONSTRAINT IF EXISTS payment_provider_customers_pkey;
ALTER TABLE IF EXISTS ONLY public.payment_methods DROP CONSTRAINT IF EXISTS payment_methods_pkey;
ALTER TABLE IF EXISTS ONLY public.payment_intents DROP CONSTRAINT IF EXISTS payment_intents_pkey;
ALTER TABLE IF EXISTS ONLY public.password_resets DROP CONSTRAINT IF EXISTS password_resets_pkey;
ALTER TABLE IF EXISTS ONLY public.organizations DROP CONSTRAINT IF EXISTS organizations_pkey;
ALTER TABLE IF EXISTS ONLY public.orders DROP CONSTRAINT IF EXISTS orders_pkey;
ALTER TABLE IF EXISTS ONLY public.order_forms DROP CONSTRAINT IF EXISTS order_forms_pkey;
ALTER TABLE IF EXISTS ONLY public.memberships DROP CONSTRAINT IF EXISTS memberships_pkey;
ALTER TABLE IF EXISTS ONLY public.membership_roles DROP CONSTRAINT IF EXISTS membership_roles_pkey;
ALTER TABLE IF EXISTS ONLY public.lifetime_usages DROP CONSTRAINT IF EXISTS lifetime_usages_pkey;
ALTER TABLE IF EXISTS ONLY public.item_metadata DROP CONSTRAINT IF EXISTS item_metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.invoices_taxes DROP CONSTRAINT IF EXISTS invoices_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS invoices_pkey;
ALTER TABLE IF EXISTS ONLY public.invoices_payment_requests DROP CONSTRAINT IF EXISTS invoices_payment_requests_pkey;
ALTER TABLE IF EXISTS ONLY public.invoice_subscriptions DROP CONSTRAINT IF EXISTS invoice_subscriptions_pkey;
ALTER TABLE IF EXISTS ONLY public.invoice_settlements DROP CONSTRAINT IF EXISTS invoice_settlements_pkey;
ALTER TABLE IF EXISTS ONLY public.invoice_metadata DROP CONSTRAINT IF EXISTS invoice_metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.invoice_custom_sections DROP CONSTRAINT IF EXISTS invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.invites DROP CONSTRAINT IF EXISTS invites_pkey;
ALTER TABLE IF EXISTS ONLY public.integrations DROP CONSTRAINT IF EXISTS integrations_pkey;
ALTER TABLE IF EXISTS ONLY public.integration_resources DROP CONSTRAINT IF EXISTS integration_resources_pkey;
ALTER TABLE IF EXISTS ONLY public.integration_mappings DROP CONSTRAINT IF EXISTS integration_mappings_pkey;
ALTER TABLE IF EXISTS ONLY public.integration_items DROP CONSTRAINT IF EXISTS integration_items_pkey;
ALTER TABLE IF EXISTS ONLY public.integration_customers DROP CONSTRAINT IF EXISTS integration_customers_pkey;
ALTER TABLE IF EXISTS ONLY public.integration_collection_mappings DROP CONSTRAINT IF EXISTS integration_collection_mappings_pkey;
ALTER TABLE IF EXISTS ONLY public.inbound_webhooks DROP CONSTRAINT IF EXISTS inbound_webhooks_pkey;
ALTER TABLE IF EXISTS ONLY public.idempotency_records DROP CONSTRAINT IF EXISTS idempotency_records_pkey;
ALTER TABLE IF EXISTS ONLY public.groups DROP CONSTRAINT IF EXISTS groups_pkey;
ALTER TABLE IF EXISTS ONLY public.group_properties DROP CONSTRAINT IF EXISTS group_properties_pkey;
ALTER TABLE IF EXISTS ONLY public.fixed_charges_taxes DROP CONSTRAINT IF EXISTS fixed_charges_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.fixed_charges DROP CONSTRAINT IF EXISTS fixed_charges_pkey;
ALTER TABLE IF EXISTS ONLY public.fixed_charge_events DROP CONSTRAINT IF EXISTS fixed_charge_events_pkey;
ALTER TABLE IF EXISTS ONLY public.fees_taxes DROP CONSTRAINT IF EXISTS fees_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.fees DROP CONSTRAINT IF EXISTS fees_pkey;
ALTER TABLE IF EXISTS ONLY public.events DROP CONSTRAINT IF EXISTS events_pkey;
ALTER TABLE IF EXISTS ONLY public.error_details DROP CONSTRAINT IF EXISTS error_details_pkey;
ALTER TABLE IF EXISTS ONLY public.entitlement_subscription_feature_removals DROP CONSTRAINT IF EXISTS entitlement_subscription_feature_removals_pkey;
ALTER TABLE IF EXISTS ONLY public.entitlement_privileges DROP CONSTRAINT IF EXISTS entitlement_privileges_pkey;
ALTER TABLE IF EXISTS ONLY public.entitlement_features DROP CONSTRAINT IF EXISTS entitlement_features_pkey;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlements DROP CONSTRAINT IF EXISTS entitlement_entitlements_pkey;
ALTER TABLE IF EXISTS ONLY public.entitlement_entitlement_values DROP CONSTRAINT IF EXISTS entitlement_entitlement_values_pkey;
ALTER TABLE IF EXISTS ONLY public.enriched_store_subscription_migrations DROP CONSTRAINT IF EXISTS enriched_store_subscription_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.enriched_store_migrations DROP CONSTRAINT IF EXISTS enriched_store_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.dunning_campaigns DROP CONSTRAINT IF EXISTS dunning_campaigns_pkey;
ALTER TABLE IF EXISTS ONLY public.dunning_campaign_thresholds DROP CONSTRAINT IF EXISTS dunning_campaign_thresholds_pkey;
ALTER TABLE IF EXISTS ONLY public.data_exports DROP CONSTRAINT IF EXISTS data_exports_pkey;
ALTER TABLE IF EXISTS ONLY public.data_export_parts DROP CONSTRAINT IF EXISTS data_export_parts_pkey;
ALTER TABLE IF EXISTS ONLY public.daily_usages DROP CONSTRAINT IF EXISTS daily_usages_pkey;
ALTER TABLE IF EXISTS ONLY public.customers_taxes DROP CONSTRAINT IF EXISTS customers_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.customers DROP CONSTRAINT IF EXISTS customers_pkey;
ALTER TABLE IF EXISTS ONLY public.customers_invoice_custom_sections DROP CONSTRAINT IF EXISTS customers_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.customer_metadata DROP CONSTRAINT IF EXISTS customer_metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.credits DROP CONSTRAINT IF EXISTS credits_pkey;
ALTER TABLE IF EXISTS ONLY public.credit_notes_taxes DROP CONSTRAINT IF EXISTS credit_notes_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.credit_notes DROP CONSTRAINT IF EXISTS credit_notes_pkey;
ALTER TABLE IF EXISTS ONLY public.credit_note_items DROP CONSTRAINT IF EXISTS credit_note_items_pkey;
ALTER TABLE IF EXISTS ONLY public.coupons DROP CONSTRAINT IF EXISTS coupons_pkey;
ALTER TABLE IF EXISTS ONLY public.coupon_targets DROP CONSTRAINT IF EXISTS coupon_targets_pkey;
ALTER TABLE IF EXISTS ONLY public.commitments_taxes DROP CONSTRAINT IF EXISTS commitments_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.commitments DROP CONSTRAINT IF EXISTS commitments_pkey;
ALTER TABLE IF EXISTS ONLY public.charges_taxes DROP CONSTRAINT IF EXISTS charges_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.charges DROP CONSTRAINT IF EXISTS charges_pkey;
ALTER TABLE IF EXISTS ONLY public.charge_filters DROP CONSTRAINT IF EXISTS charge_filters_pkey;
ALTER TABLE IF EXISTS ONLY public.charge_filter_values DROP CONSTRAINT IF EXISTS charge_filter_values_pkey;
ALTER TABLE IF EXISTS ONLY public.cached_aggregations DROP CONSTRAINT IF EXISTS cached_aggregations_pkey;
ALTER TABLE IF EXISTS ONLY public.billing_entities_taxes DROP CONSTRAINT IF EXISTS billing_entities_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.billing_entities DROP CONSTRAINT IF EXISTS billing_entities_pkey;
ALTER TABLE IF EXISTS ONLY public.billing_entities_invoice_custom_sections DROP CONSTRAINT IF EXISTS billing_entities_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.billable_metrics DROP CONSTRAINT IF EXISTS billable_metrics_pkey;
ALTER TABLE IF EXISTS ONLY public.billable_metric_filters DROP CONSTRAINT IF EXISTS billable_metric_filters_pkey;
ALTER TABLE IF EXISTS ONLY public.ar_internal_metadata DROP CONSTRAINT IF EXISTS ar_internal_metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.applied_usage_thresholds DROP CONSTRAINT IF EXISTS applied_usage_thresholds_pkey;
ALTER TABLE IF EXISTS ONLY public.applied_pricing_units DROP CONSTRAINT IF EXISTS applied_pricing_units_pkey;
ALTER TABLE IF EXISTS ONLY public.applied_invoice_custom_sections DROP CONSTRAINT IF EXISTS applied_invoice_custom_sections_pkey;
ALTER TABLE IF EXISTS ONLY public.applied_coupons DROP CONSTRAINT IF EXISTS applied_coupons_pkey;
ALTER TABLE IF EXISTS ONLY public.applied_add_ons DROP CONSTRAINT IF EXISTS applied_add_ons_pkey;
ALTER TABLE IF EXISTS ONLY public.api_keys DROP CONSTRAINT IF EXISTS api_keys_pkey;
ALTER TABLE IF EXISTS ONLY public.ai_conversations DROP CONSTRAINT IF EXISTS ai_conversations_pkey;
ALTER TABLE IF EXISTS ONLY public.adjusted_fees DROP CONSTRAINT IF EXISTS adjusted_fees_pkey;
ALTER TABLE IF EXISTS ONLY public.add_ons_taxes DROP CONSTRAINT IF EXISTS add_ons_taxes_pkey;
ALTER TABLE IF EXISTS ONLY public.add_ons DROP CONSTRAINT IF EXISTS add_ons_pkey;
ALTER TABLE IF EXISTS ONLY public.active_storage_variant_records DROP CONSTRAINT IF EXISTS active_storage_variant_records_pkey;
ALTER TABLE IF EXISTS ONLY public.active_storage_blobs DROP CONSTRAINT IF EXISTS active_storage_blobs_pkey;
ALTER TABLE IF EXISTS ONLY public.active_storage_attachments DROP CONSTRAINT IF EXISTS active_storage_attachments_pkey;
ALTER TABLE IF EXISTS public.versions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.usage_monitoring_subscription_activities ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.quote_owners ALTER COLUMN id DROP DEFAULT;
DROP TABLE IF EXISTS public.webhooks;
DROP TABLE IF EXISTS public.webhook_endpoints;
DROP TABLE IF EXISTS public.wallets_invoice_custom_sections;
DROP TABLE IF EXISTS public.wallet_transactions_invoice_custom_sections;
DROP TABLE IF EXISTS public.wallet_targets;
DROP SEQUENCE IF EXISTS public.versions_id_seq;
DROP TABLE IF EXISTS public.versions;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.user_devices;
DROP SEQUENCE IF EXISTS public.usage_monitoring_subscription_activities_id_seq;
DROP TABLE IF EXISTS public.usage_monitoring_subscription_activities;
DROP TABLE IF EXISTS public.usage_monitoring_alerts;
DROP TABLE IF EXISTS public.subscriptions_invoice_custom_sections;
DROP TABLE IF EXISTS public.subscription_fixed_charge_units_overrides;
DROP TABLE IF EXISTS public.subscription_activation_rules;
DROP TABLE IF EXISTS public.schema_migrations;
DROP TABLE IF EXISTS public.roles;
DROP TABLE IF EXISTS public.refunds;
DROP TABLE IF EXISTS public.recurring_transaction_rules_invoice_custom_sections;
DROP TABLE IF EXISTS public.recurring_transaction_rules;
DROP TABLE IF EXISTS public.quotes;
DROP TABLE IF EXISTS public.quote_versions;
DROP SEQUENCE IF EXISTS public.quote_owners_id_seq;
DROP TABLE IF EXISTS public.quote_owners;
DROP TABLE IF EXISTS public.quantified_events;
DROP TABLE IF EXISTS public.pricing_units;
DROP TABLE IF EXISTS public.pricing_unit_usages;
DROP TABLE IF EXISTS public.presentation_breakdowns;
DROP TABLE IF EXISTS public.pending_vies_checks;
DROP TABLE IF EXISTS public.payment_receipts;
DROP TABLE IF EXISTS public.payment_providers;
DROP TABLE IF EXISTS public.payment_methods;
DROP TABLE IF EXISTS public.payment_intents;
DROP TABLE IF EXISTS public.password_resets;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.order_forms;
DROP TABLE IF EXISTS public.memberships;
DROP TABLE IF EXISTS public.membership_roles;
DROP TABLE IF EXISTS public.lifetime_usages;
DROP MATERIALIZED VIEW IF EXISTS public.last_hour_events_mv;
DROP TABLE IF EXISTS public.invoice_custom_sections;
DROP TABLE IF EXISTS public.invites;
DROP TABLE IF EXISTS public.integrations;
DROP TABLE IF EXISTS public.integration_resources;
DROP TABLE IF EXISTS public.integration_mappings;
DROP TABLE IF EXISTS public.integration_items;
DROP TABLE IF EXISTS public.integration_collection_mappings;
DROP TABLE IF EXISTS public.inbound_webhooks;
DROP TABLE IF EXISTS public.idempotency_records;
DROP TABLE IF EXISTS public.groups;
DROP TABLE IF EXISTS public.group_properties;
DROP VIEW IF EXISTS public.flat_filters;
DROP TABLE IF EXISTS public.fixed_charges_taxes;
DROP TABLE IF EXISTS public.fixed_charges;
DROP TABLE IF EXISTS public.fixed_charge_events;
DROP VIEW IF EXISTS public.exports_wallets;
DROP TABLE IF EXISTS public.wallets;
DROP VIEW IF EXISTS public.exports_wallet_transactions;
DROP TABLE IF EXISTS public.wallet_transactions;
DROP VIEW IF EXISTS public.exports_wallet_transaction_consumptions;
DROP TABLE IF EXISTS public.wallet_transaction_consumptions;
DROP VIEW IF EXISTS public.exports_usage_thresholds;
DROP TABLE IF EXISTS public.usage_thresholds;
DROP VIEW IF EXISTS public.exports_usage_monitoring_triggered_alerts;
DROP TABLE IF EXISTS public.usage_monitoring_triggered_alerts;
DROP VIEW IF EXISTS public.exports_usage_monitoring_alert_thresholds;
DROP TABLE IF EXISTS public.usage_monitoring_alert_thresholds;
DROP VIEW IF EXISTS public.exports_taxes;
DROP TABLE IF EXISTS public.taxes;
DROP VIEW IF EXISTS public.exports_subscriptions;
DROP VIEW IF EXISTS public.exports_plans;
DROP TABLE IF EXISTS public.plans_taxes;
DROP VIEW IF EXISTS public.exports_payments;
DROP VIEW IF EXISTS public.exports_payment_requests;
DROP TABLE IF EXISTS public.payments;
DROP TABLE IF EXISTS public.payment_requests;
DROP TABLE IF EXISTS public.invoices_payment_requests;
DROP VIEW IF EXISTS public.exports_item_metadata;
DROP VIEW IF EXISTS public.exports_invoices_taxes;
DROP TABLE IF EXISTS public.invoices_taxes;
DROP VIEW IF EXISTS public.exports_invoices;
DROP TABLE IF EXISTS public.invoices;
DROP TABLE IF EXISTS public.invoice_metadata;
DROP VIEW IF EXISTS public.exports_invoice_subscriptions;
DROP TABLE IF EXISTS public.invoice_subscriptions;
DROP VIEW IF EXISTS public.exports_invoice_settlements;
DROP TABLE IF EXISTS public.invoice_settlements;
DROP VIEW IF EXISTS public.exports_integration_customers;
DROP TABLE IF EXISTS public.integration_customers;
DROP VIEW IF EXISTS public.exports_fees_taxes;
DROP TABLE IF EXISTS public.fees_taxes;
DROP VIEW IF EXISTS public.exports_fees;
DROP TABLE IF EXISTS public.subscriptions;
DROP TABLE IF EXISTS public.plans;
DROP TABLE IF EXISTS public.fees;
DROP VIEW IF EXISTS public.exports_entitlement_features;
DROP VIEW IF EXISTS public.exports_entitlement_entitlements;
DROP VIEW IF EXISTS public.exports_entitlement_entitlement_values;
DROP VIEW IF EXISTS public.exports_daily_usages;
DROP VIEW IF EXISTS public.exports_customers;
DROP TABLE IF EXISTS public.payment_provider_customers;
DROP TABLE IF EXISTS public.organizations;
DROP VIEW IF EXISTS public.exports_credit_notes_taxes;
DROP VIEW IF EXISTS public.exports_credit_notes;
DROP TABLE IF EXISTS public.item_metadata;
DROP VIEW IF EXISTS public.exports_coupons;
DROP VIEW IF EXISTS public.exports_charges;
DROP VIEW IF EXISTS public.exports_billing_entities;
DROP VIEW IF EXISTS public.exports_billable_metrics;
DROP VIEW IF EXISTS public.exports_applied_coupons;
DROP TABLE IF EXISTS public.events;
DROP TABLE IF EXISTS public.error_details;
DROP TABLE IF EXISTS public.entitlement_subscription_feature_removals;
DROP TABLE IF EXISTS public.entitlement_privileges;
DROP TABLE IF EXISTS public.entitlement_features;
DROP TABLE IF EXISTS public.entitlement_entitlements;
DROP TABLE IF EXISTS public.entitlement_entitlement_values;
DROP TABLE IF EXISTS public.enriched_store_subscription_migrations;
DROP TABLE IF EXISTS public.enriched_store_migrations;
DROP TABLE IF EXISTS public.enriched_events_default;
DROP TABLE IF EXISTS public.enriched_events;
DROP TABLE IF EXISTS public.dunning_campaigns;
DROP TABLE IF EXISTS public.dunning_campaign_thresholds;
DROP TABLE IF EXISTS public.data_exports;
DROP TABLE IF EXISTS public.data_export_parts;
DROP TABLE IF EXISTS public.daily_usages;
DROP TABLE IF EXISTS public.customers_taxes;
DROP TABLE IF EXISTS public.customers_invoice_custom_sections;
DROP TABLE IF EXISTS public.customers;
DROP TABLE IF EXISTS public.customer_metadata;
DROP TABLE IF EXISTS public.credits;
DROP TABLE IF EXISTS public.credit_notes_taxes;
DROP TABLE IF EXISTS public.credit_notes;
DROP TABLE IF EXISTS public.credit_note_items;
DROP TABLE IF EXISTS public.coupons;
DROP TABLE IF EXISTS public.coupon_targets;
DROP TABLE IF EXISTS public.commitments_taxes;
DROP TABLE IF EXISTS public.commitments;
DROP TABLE IF EXISTS public.charges_taxes;
DROP TABLE IF EXISTS public.charges;
DROP TABLE IF EXISTS public.charge_filters;
DROP TABLE IF EXISTS public.charge_filter_values;
DROP TABLE IF EXISTS public.cached_aggregations;
DROP TABLE IF EXISTS public.billing_entities_taxes;
DROP TABLE IF EXISTS public.billing_entities_invoice_custom_sections;
DROP TABLE IF EXISTS public.billing_entities;
DROP VIEW IF EXISTS public.billable_metrics_grouped_charges;
DROP TABLE IF EXISTS public.billable_metrics;
DROP TABLE IF EXISTS public.billable_metric_filters;
DROP TABLE IF EXISTS public.ar_internal_metadata;
DROP TABLE IF EXISTS public.applied_usage_thresholds;
DROP TABLE IF EXISTS public.applied_pricing_units;
DROP TABLE IF EXISTS public.applied_invoice_custom_sections;
DROP TABLE IF EXISTS public.applied_coupons;
DROP TABLE IF EXISTS public.applied_add_ons;
DROP TABLE IF EXISTS public.api_keys;
DROP TABLE IF EXISTS public.ai_conversations;
DROP TABLE IF EXISTS public.adjusted_fees;
DROP TABLE IF EXISTS public.add_ons_taxes;
DROP TABLE IF EXISTS public.add_ons;
DROP TABLE IF EXISTS public.active_storage_variant_records;
DROP TABLE IF EXISTS public.active_storage_blobs;
DROP TABLE IF EXISTS public.active_storage_attachments;
DROP TABLE IF EXISTS partman.template_public_enriched_events;
DROP FUNCTION IF EXISTS public.set_payment_receipt_number();
DROP FUNCTION IF EXISTS public.ensure_role_consistency();
DROP TYPE IF EXISTS public.usage_monitoring_alert_types;
DROP TYPE IF EXISTS public.usage_monitoring_alert_direction;
DROP TYPE IF EXISTS public.tax_status;
DROP TYPE IF EXISTS public.subscription_on_termination_invoice;
DROP TYPE IF EXISTS public.subscription_on_termination_credit_note;
DROP TYPE IF EXISTS public.subscription_invoicing_reason;
DROP TYPE IF EXISTS public.subscription_invoice_issuing_date_anchors;
DROP TYPE IF EXISTS public.subscription_invoice_issuing_date_adjustments;
DROP TYPE IF EXISTS public.subscription_cancellation_reasons;
DROP TYPE IF EXISTS public.subscription_cancelation_reasons;
DROP TYPE IF EXISTS public.subscription_activation_rule_types;
DROP TYPE IF EXISTS public.subscription_activation_rule_statuses;
DROP TYPE IF EXISTS public.quote_void_reason;
DROP TYPE IF EXISTS public.quote_status;
DROP TYPE IF EXISTS public.quote_order_type;
DROP TYPE IF EXISTS public.payment_type;
DROP TYPE IF EXISTS public.payment_payable_payment_status;
DROP TYPE IF EXISTS public.payment_method_types;
DROP TYPE IF EXISTS public.order_status;
DROP TYPE IF EXISTS public.order_form_void_reason;
DROP TYPE IF EXISTS public.order_form_status;
DROP TYPE IF EXISTS public.order_execution_mode;
DROP TYPE IF EXISTS public.invoice_settlement_settlement_type;
DROP TYPE IF EXISTS public.invoice_custom_section_type;
DROP TYPE IF EXISTS public.inbound_webhook_status;
DROP TYPE IF EXISTS public.fixed_charge_charge_model;
DROP TYPE IF EXISTS public.entity_document_numbering;
DROP TYPE IF EXISTS public.entitlement_privilege_value_types;
DROP TYPE IF EXISTS public.enriched_store_sub_migration_status;
DROP TYPE IF EXISTS public.enriched_store_migration_status;
DROP TYPE IF EXISTS public.customer_type;
DROP TYPE IF EXISTS public.customer_account_type;
DROP TYPE IF EXISTS public.billable_metric_weighted_interval;
DROP TYPE IF EXISTS public.billable_metric_rounding_function;
DROP EXTENSION IF EXISTS unaccent;
DROP EXTENSION IF EXISTS pgcrypto;
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_partman;
DROP EXTENSION IF EXISTS btree_gin;
DROP SCHEMA IF EXISTS partman;
--
-- Name: partman; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA partman;


--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: pg_partman; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_partman WITH SCHEMA partman;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: billable_metric_rounding_function; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.billable_metric_rounding_function AS ENUM (
    'round',
    'floor',
    'ceil'
);


--
-- Name: billable_metric_weighted_interval; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.billable_metric_weighted_interval AS ENUM (
    'seconds'
);


--
-- Name: customer_account_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_account_type AS ENUM (
    'customer',
    'partner'
);


--
-- Name: customer_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_type AS ENUM (
    'company',
    'individual'
);


--
-- Name: enriched_store_migration_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.enriched_store_migration_status AS ENUM (
    'pending',
    'checking',
    'processing',
    'enabling',
    'completed',
    'failed'
);


--
-- Name: enriched_store_sub_migration_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.enriched_store_sub_migration_status AS ENUM (
    'pending',
    'comparing',
    'reprocessing',
    'waiting_for_enrichment',
    'deduplicating',
    'dedup_paused',
    'validating',
    'completed',
    'failed'
);


--
-- Name: entitlement_privilege_value_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entitlement_privilege_value_types AS ENUM (
    'integer',
    'string',
    'boolean',
    'select'
);


--
-- Name: entity_document_numbering; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_document_numbering AS ENUM (
    'per_customer',
    'per_billing_entity'
);


--
-- Name: fixed_charge_charge_model; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fixed_charge_charge_model AS ENUM (
    'standard',
    'graduated',
    'volume'
);


--
-- Name: inbound_webhook_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.inbound_webhook_status AS ENUM (
    'pending',
    'processing',
    'succeeded',
    'failed'
);


--
-- Name: invoice_custom_section_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.invoice_custom_section_type AS ENUM (
    'manual',
    'system_generated'
);


--
-- Name: invoice_settlement_settlement_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.invoice_settlement_settlement_type AS ENUM (
    'payment',
    'credit_note'
);


--
-- Name: order_execution_mode; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_execution_mode AS ENUM (
    'execute_in_lago',
    'order_only'
);


--
-- Name: order_form_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_form_status AS ENUM (
    'generated',
    'signed',
    'expired',
    'voided'
);


--
-- Name: order_form_void_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_form_void_reason AS ENUM (
    'manual',
    'expired',
    'invalid'
);


--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'created',
    'executed'
);


--
-- Name: payment_method_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method_types AS ENUM (
    'provider',
    'manual'
);


--
-- Name: payment_payable_payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_payable_payment_status AS ENUM (
    'pending',
    'processing',
    'succeeded',
    'failed'
);


--
-- Name: payment_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_type AS ENUM (
    'provider',
    'manual'
);


--
-- Name: quote_order_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quote_order_type AS ENUM (
    'subscription_creation',
    'subscription_amendment',
    'one_off'
);


--
-- Name: quote_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quote_status AS ENUM (
    'draft',
    'approved',
    'voided'
);


--
-- Name: quote_void_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quote_void_reason AS ENUM (
    'manual',
    'superseded',
    'cascade_of_expired',
    'cascade_of_voided'
);


--
-- Name: subscription_activation_rule_statuses; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_activation_rule_statuses AS ENUM (
    'inactive',
    'pending',
    'satisfied',
    'declined',
    'failed',
    'expired',
    'not_applicable'
);


--
-- Name: subscription_activation_rule_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_activation_rule_types AS ENUM (
    'payment'
);


--
-- Name: subscription_cancelation_reasons; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_cancelation_reasons AS ENUM (
    'payment_failed',
    'timeout'
);


--
-- Name: subscription_cancellation_reasons; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_cancellation_reasons AS ENUM (
    'payment_failed',
    'timeout'
);


--
-- Name: subscription_invoice_issuing_date_adjustments; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_invoice_issuing_date_adjustments AS ENUM (
    'keep_anchor',
    'align_with_finalization_date'
);


--
-- Name: subscription_invoice_issuing_date_anchors; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_invoice_issuing_date_anchors AS ENUM (
    'current_period_end',
    'next_period_start'
);


--
-- Name: subscription_invoicing_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_invoicing_reason AS ENUM (
    'subscription_starting',
    'subscription_periodic',
    'subscription_terminating',
    'in_advance_charge',
    'in_advance_charge_periodic',
    'progressive_billing'
);


--
-- Name: subscription_on_termination_credit_note; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_on_termination_credit_note AS ENUM (
    'credit',
    'skip',
    'refund',
    'offset'
);


--
-- Name: subscription_on_termination_invoice; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.subscription_on_termination_invoice AS ENUM (
    'generate',
    'skip'
);


--
-- Name: tax_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tax_status AS ENUM (
    'pending',
    'succeeded',
    'failed'
);


--
-- Name: usage_monitoring_alert_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.usage_monitoring_alert_direction AS ENUM (
    'increasing',
    'decreasing'
);


--
-- Name: usage_monitoring_alert_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.usage_monitoring_alert_types AS ENUM (
    'current_usage_amount',
    'billable_metric_current_usage_amount',
    'billable_metric_current_usage_units',
    'lifetime_usage_amount',
    'wallet_balance_amount',
    'wallet_credits_balance',
    'wallet_ongoing_balance_amount',
    'wallet_credits_ongoing_balance',
    'billable_metric_lifetime_usage_units'
);


--
-- Name: ensure_role_consistency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_role_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF OLD.organization_id IS NULL THEN RAISE EXCEPTION 'Predefined role cannot be modified'; ELSIF OLD.organization_id IS DISTINCT FROM NEW.organization_id THEN RAISE EXCEPTION 'Custom role cannot be moved to another organization'; ELSIF OLD.code IS DISTINCT FROM NEW.code THEN RAISE EXCEPTION 'The code of the role cannot be changed'; ELSIF NEW.permissions != OLD.permissions THEN NEW.permissions := ARRAY(SELECT DISTINCT unnest(NEW.permissions) ORDER BY 1); END IF; RETURN NEW; END; $$;


--
-- Name: set_payment_receipt_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_payment_receipt_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
            cust_id uuid;
            next_payment_receipt integer;
            document_number_prefix character varying;
        BEGIN
          IF NEW.number IS NULL THEN
            SELECT i.customer_id INTO cust_id
            FROM invoices i
            INNER JOIN payments p ON (p.payable_id = i.id AND p.payable_type = 'Invoice')
            WHERE p.id = NEW.payment_id;

            IF cust_id IS NULL THEN
              SELECT pr.customer_id INTO cust_id
              FROM payment_requests pr
              LEFT JOIN payments p ON (p.payable_id = pr.id AND p.payable_type = 'PaymentRequest')
              WHERE p.id = NEW.payment_id;
            END IF;

            SELECT c.slug INTO document_number_prefix
            FROM customers c
            WHERE c.id = cust_id;

            -- Atomically increment the customer's payment receipt counter and get the new value
            UPDATE customers
            SET payment_receipt_counter = payment_receipt_counter + 1
            WHERE id = cust_id
            RETURNING payment_receipt_counter INTO next_payment_receipt;

            -- Construct the payment receipt number using the customer id and the new counter value
            NEW.number := document_number_prefix || '-RCPT-' || LPAD(next_payment_receipt::text, GREATEST(6, LENGTH(next_payment_receipt::text)), '0');
          END IF;
          RETURN NEW;
        END;
        $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: template_public_enriched_events; Type: TABLE; Schema: partman; Owner: -
--

CREATE TABLE partman.template_public_enriched_events (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    event_id uuid NOT NULL,
    transaction_id character varying NOT NULL,
    external_subscription_id character varying NOT NULL,
    code character varying NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    subscription_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    charge_id uuid NOT NULL,
    charge_filter_id uuid,
    properties jsonb NOT NULL,
    grouped_by jsonb NOT NULL,
    value character varying,
    decimal_value numeric(40,15) NOT NULL,
    enriched_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    record_id uuid
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: add_ons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.add_ons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description character varying,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    invoice_display_name character varying
);


--
-- Name: add_ons_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.add_ons_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    add_on_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: adjusted_fees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adjusted_fees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fee_id uuid,
    invoice_id uuid NOT NULL,
    subscription_id uuid,
    charge_id uuid,
    invoice_display_name character varying,
    fee_type integer,
    adjusted_units boolean DEFAULT false NOT NULL,
    adjusted_amount boolean DEFAULT false NOT NULL,
    units numeric DEFAULT 0.0 NOT NULL,
    unit_amount_cents bigint DEFAULT 0 NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    group_id uuid,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    charge_filter_id uuid,
    unit_precise_amount_cents numeric(40,15) DEFAULT 0.0 NOT NULL,
    organization_id uuid NOT NULL,
    fixed_charge_id uuid
);


--
-- Name: ai_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    name character varying NOT NULL,
    mistral_conversation_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    value character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone,
    last_used_at timestamp(6) without time zone,
    name character varying,
    permissions jsonb NOT NULL
);


--
-- Name: applied_add_ons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_add_ons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    add_on_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: applied_coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    coupon_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    amount_cents bigint,
    amount_currency character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    terminated_at timestamp without time zone,
    percentage_rate numeric(10,5),
    frequency integer DEFAULT 0 NOT NULL,
    frequency_duration integer,
    frequency_duration_remaining integer,
    organization_id uuid NOT NULL
);


--
-- Name: applied_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    display_name character varying,
    details character varying,
    invoice_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: applied_pricing_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_pricing_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pricing_unit_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    pricing_unitable_type character varying NOT NULL,
    pricing_unitable_id uuid NOT NULL,
    conversion_rate numeric(40,15) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: applied_usage_thresholds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_usage_thresholds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usage_threshold_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    lifetime_usage_amount_cents bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: billable_metric_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billable_metric_filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    billable_metric_id uuid NOT NULL,
    key character varying NOT NULL,
    "values" character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    organization_id uuid NOT NULL
);


--
-- Name: billable_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billable_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description character varying,
    properties jsonb DEFAULT '{}'::jsonb,
    aggregation_type integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    field_name character varying,
    deleted_at timestamp(6) without time zone,
    recurring boolean DEFAULT false NOT NULL,
    weighted_interval public.billable_metric_weighted_interval,
    custom_aggregator text,
    expression character varying,
    rounding_function public.billable_metric_rounding_function,
    rounding_precision integer
);


--
-- Name: billable_metrics_grouped_charges; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.billable_metrics_grouped_charges AS
SELECT
    NULL::uuid AS organization_id,
    NULL::character varying AS code,
    NULL::integer AS aggregation_type,
    NULL::character varying AS field_name,
    NULL::uuid AS plan_id,
    NULL::uuid AS charge_id,
    NULL::boolean AS pay_in_advance,
    NULL::jsonb AS grouped_by,
    NULL::uuid AS charge_filter_id,
    NULL::json AS filters,
    NULL::jsonb AS filters_grouped_by;


--
-- Name: billing_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_entities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    address_line1 character varying,
    address_line2 character varying,
    city character varying,
    country character varying,
    zipcode character varying,
    state character varying,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    default_currency character varying DEFAULT 'USD'::character varying NOT NULL,
    document_locale character varying DEFAULT 'en'::character varying NOT NULL,
    document_number_prefix character varying,
    document_numbering public.entity_document_numbering DEFAULT 'per_customer'::public.entity_document_numbering NOT NULL,
    finalize_zero_amount_invoice boolean DEFAULT true NOT NULL,
    invoice_footer text,
    invoice_grace_period integer DEFAULT 0 NOT NULL,
    net_payment_term integer DEFAULT 0 NOT NULL,
    email character varying,
    email_settings character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    eu_tax_management boolean DEFAULT false,
    legal_name character varying,
    legal_number character varying,
    logo character varying,
    name character varying NOT NULL,
    code character varying NOT NULL,
    tax_identification_number character varying,
    vat_rate double precision DEFAULT 0.0 NOT NULL,
    archived_at timestamp(6) without time zone,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    applied_dunning_campaign_id uuid,
    einvoicing boolean DEFAULT false NOT NULL,
    subscription_invoice_issuing_date_anchor public.subscription_invoice_issuing_date_anchors DEFAULT 'next_period_start'::public.subscription_invoice_issuing_date_anchors NOT NULL,
    subscription_invoice_issuing_date_adjustment public.subscription_invoice_issuing_date_adjustments DEFAULT 'align_with_finalization_date'::public.subscription_invoice_issuing_date_adjustments NOT NULL,
    phone character varying
);


--
-- Name: billing_entities_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_entities_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: billing_entities_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_entities_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    billing_entity_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: cached_aggregations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cached_aggregations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    external_subscription_id character varying NOT NULL,
    charge_id uuid NOT NULL,
    group_id uuid,
    current_aggregation numeric,
    max_aggregation numeric,
    max_aggregation_with_proration numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    charge_filter_id uuid,
    current_amount numeric,
    event_transaction_id character varying,
    presentation_breakdowns jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: charge_filter_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_filter_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    charge_filter_id uuid NOT NULL,
    billable_metric_filter_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    "values" character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: charge_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    charge_id uuid NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    invoice_display_name character varying,
    organization_id uuid NOT NULL
);


--
-- Name: charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    billable_metric_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    plan_id uuid,
    amount_currency character varying,
    charge_model integer DEFAULT 0 NOT NULL,
    properties jsonb DEFAULT '"{}"'::jsonb NOT NULL,
    deleted_at timestamp(6) without time zone,
    pay_in_advance boolean DEFAULT false NOT NULL,
    min_amount_cents bigint DEFAULT 0 NOT NULL,
    invoiceable boolean DEFAULT true NOT NULL,
    prorated boolean DEFAULT false NOT NULL,
    invoice_display_name character varying,
    regroup_paid_fees integer,
    parent_id uuid,
    organization_id uuid NOT NULL,
    code character varying NOT NULL,
    accepts_target_wallet boolean DEFAULT false NOT NULL
);


--
-- Name: charges_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    charge_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: commitments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commitments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    commitment_type integer NOT NULL,
    amount_cents bigint NOT NULL,
    invoice_display_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: commitments_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commitments_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    commitment_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: coupon_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupon_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    coupon_id uuid NOT NULL,
    plan_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    billable_metric_id uuid,
    organization_id uuid NOT NULL
);


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    terminated_at timestamp(6) without time zone,
    amount_cents bigint,
    amount_currency character varying,
    expiration integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    coupon_type integer DEFAULT 0 NOT NULL,
    percentage_rate numeric(10,5),
    frequency integer DEFAULT 0 NOT NULL,
    frequency_duration integer,
    expiration_at timestamp(6) without time zone,
    reusable boolean DEFAULT true NOT NULL,
    limited_plans boolean DEFAULT false NOT NULL,
    deleted_at timestamp(6) without time zone,
    limited_billable_metrics boolean DEFAULT false NOT NULL,
    description text
);


--
-- Name: credit_note_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_note_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_note_id uuid NOT NULL,
    fee_id uuid,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    precise_amount_cents numeric(30,5) NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: credit_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    sequential_id integer NOT NULL,
    number character varying NOT NULL,
    credit_amount_cents bigint DEFAULT 0 NOT NULL,
    credit_amount_currency character varying NOT NULL,
    credit_status integer,
    balance_amount_cents bigint DEFAULT 0 NOT NULL,
    balance_amount_currency character varying DEFAULT '0'::character varying NOT NULL,
    reason integer NOT NULL,
    file character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    total_amount_cents bigint DEFAULT 0 NOT NULL,
    total_amount_currency character varying NOT NULL,
    refund_amount_cents bigint DEFAULT 0 NOT NULL,
    refund_amount_currency character varying,
    refund_status integer,
    voided_at timestamp(6) without time zone,
    description text,
    taxes_amount_cents bigint DEFAULT 0 NOT NULL,
    refunded_at timestamp(6) without time zone,
    issuing_date date NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    coupons_adjustment_amount_cents bigint DEFAULT 0 NOT NULL,
    precise_coupons_adjustment_amount_cents numeric(30,5) DEFAULT 0.0 NOT NULL,
    precise_taxes_amount_cents numeric(30,5) DEFAULT 0.0 NOT NULL,
    taxes_rate double precision DEFAULT 0.0 NOT NULL,
    organization_id uuid NOT NULL,
    xml_file character varying,
    offset_amount_cents bigint DEFAULT 0 NOT NULL,
    offset_amount_currency character varying
);


--
-- Name: credit_notes_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_notes_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_note_id uuid NOT NULL,
    tax_id uuid,
    tax_description character varying,
    tax_code character varying NOT NULL,
    tax_name character varying NOT NULL,
    tax_rate double precision DEFAULT 0.0 NOT NULL,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    base_amount_cents bigint DEFAULT 0 NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credits (
    invoice_id uuid,
    applied_coupon_id uuid,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    credit_note_id uuid,
    before_taxes boolean DEFAULT false NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    progressive_billing_invoice_id uuid,
    organization_id uuid NOT NULL
);


--
-- Name: customer_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_metadata (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    key character varying NOT NULL,
    value character varying NOT NULL,
    display_in_invoice boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_id character varying NOT NULL,
    name character varying,
    organization_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    country character varying,
    address_line1 character varying,
    address_line2 character varying,
    state character varying,
    zipcode character varying,
    email character varying,
    city character varying,
    url character varying,
    phone character varying,
    logo_url character varying,
    legal_name character varying,
    legal_number character varying,
    vat_rate double precision,
    payment_provider character varying,
    slug character varying,
    sequential_id bigint,
    currency character varying,
    invoice_grace_period integer,
    timezone character varying,
    deleted_at timestamp(6) without time zone,
    document_locale character varying,
    tax_identification_number character varying,
    net_payment_term integer,
    external_salesforce_id character varying,
    payment_provider_code character varying,
    shipping_address_line1 character varying,
    shipping_address_line2 character varying,
    shipping_city character varying,
    shipping_zipcode character varying,
    shipping_state character varying,
    shipping_country character varying,
    finalize_zero_amount_invoice integer DEFAULT 0 NOT NULL,
    firstname character varying,
    lastname character varying,
    customer_type public.customer_type,
    applied_dunning_campaign_id uuid,
    exclude_from_dunning_campaign boolean DEFAULT false NOT NULL,
    last_dunning_campaign_attempt integer DEFAULT 0 NOT NULL,
    last_dunning_campaign_attempt_at timestamp without time zone,
    skip_invoice_custom_sections boolean DEFAULT false NOT NULL,
    account_type public.customer_account_type DEFAULT 'customer'::public.customer_account_type NOT NULL,
    billing_entity_id uuid NOT NULL,
    payment_receipt_counter bigint DEFAULT 0 NOT NULL,
    subscription_invoice_issuing_date_anchor public.subscription_invoice_issuing_date_anchors,
    subscription_invoice_issuing_date_adjustment public.subscription_invoice_issuing_date_adjustments,
    awaiting_wallet_refresh boolean DEFAULT false NOT NULL,
    dunning_currency_attempts jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT check_customers_on_invoice_grace_period CHECK ((invoice_grace_period >= 0)),
    CONSTRAINT check_customers_on_net_payment_term CHECK ((net_payment_term >= 0))
);


--
-- Name: customers_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: customers_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: daily_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_usages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    external_subscription_id character varying NOT NULL,
    from_datetime timestamp(6) without time zone NOT NULL,
    to_datetime timestamp(6) without time zone NOT NULL,
    usage jsonb DEFAULT '"{}"'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    refreshed_at timestamp(6) without time zone NOT NULL,
    usage_diff jsonb DEFAULT '"{}"'::jsonb NOT NULL,
    usage_date date
);


--
-- Name: data_export_parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_export_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    index integer,
    data_export_id uuid NOT NULL,
    object_ids uuid[] NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    csv_lines text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: data_exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_exports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    format integer,
    resource_type character varying NOT NULL,
    resource_query jsonb DEFAULT '{}'::jsonb,
    status integer DEFAULT 0 NOT NULL,
    expires_at timestamp without time zone,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    membership_id uuid,
    organization_id uuid NOT NULL
);


--
-- Name: dunning_campaign_thresholds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dunning_campaign_thresholds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dunning_campaign_id uuid NOT NULL,
    currency character varying NOT NULL,
    amount_cents bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp without time zone,
    organization_id uuid NOT NULL
);


--
-- Name: dunning_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dunning_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description text,
    applied_to_organization boolean DEFAULT false NOT NULL,
    days_between_attempts integer DEFAULT 1 NOT NULL,
    max_attempts integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp without time zone,
    bcc_emails character varying[] DEFAULT '{}'::character varying[]
);


--
-- Name: enriched_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enriched_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    event_id uuid NOT NULL,
    transaction_id character varying NOT NULL,
    external_subscription_id character varying NOT NULL,
    code character varying NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    subscription_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    charge_id uuid NOT NULL,
    charge_filter_id uuid,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    value character varying,
    decimal_value numeric(40,15) DEFAULT 0.0 NOT NULL,
    enriched_at timestamp(6) without time zone NOT NULL,
    operation_type character varying,
    precise_total_amount_cents numeric(40,15),
    target_wallet_code character varying
)
PARTITION BY RANGE ("timestamp");


--
-- Name: enriched_events_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enriched_events_default (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    event_id uuid NOT NULL,
    transaction_id character varying NOT NULL,
    external_subscription_id character varying NOT NULL,
    code character varying NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    subscription_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    charge_id uuid NOT NULL,
    charge_filter_id uuid,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    value character varying,
    decimal_value numeric(40,15) DEFAULT 0.0 NOT NULL,
    enriched_at timestamp(6) without time zone NOT NULL,
    operation_type character varying,
    precise_total_amount_cents numeric(40,15),
    target_wallet_code character varying
);


--
-- Name: enriched_store_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enriched_store_migrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    status public.enriched_store_migration_status DEFAULT 'pending'::public.enriched_store_migration_status NOT NULL,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: enriched_store_subscription_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enriched_store_subscription_migrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    enriched_store_migration_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    status public.enriched_store_sub_migration_status DEFAULT 'pending'::public.enriched_store_sub_migration_status NOT NULL,
    billable_metric_codes jsonb DEFAULT '[]'::jsonb,
    events_reprocessed_count integer DEFAULT 0,
    duplicates_removed_count integer DEFAULT 0,
    dedup_pending_queries jsonb DEFAULT '[]'::jsonb,
    comparison_results jsonb DEFAULT '{}'::jsonb,
    error_message text,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    attempts integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entitlement_entitlement_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_entitlement_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entitlement_privilege_id uuid NOT NULL,
    entitlement_entitlement_id uuid NOT NULL,
    value character varying NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entitlement_entitlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_entitlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entitlement_feature_id uuid NOT NULL,
    plan_id uuid,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    subscription_id uuid,
    CONSTRAINT entitlement_check_exactly_one_parent CHECK (((plan_id IS NOT NULL) <> (subscription_id IS NOT NULL)))
);


--
-- Name: entitlement_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_features (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    code character varying NOT NULL,
    name character varying,
    description character varying,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entitlement_privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_privileges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entitlement_feature_id uuid NOT NULL,
    code character varying NOT NULL,
    name character varying,
    value_type public.entitlement_privilege_value_types DEFAULT 'string'::public.entitlement_privilege_value_types NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entitlement_subscription_feature_removals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entitlement_subscription_feature_removals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    entitlement_feature_id uuid,
    subscription_id uuid NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    entitlement_privilege_id uuid,
    CONSTRAINT check_exactly_one_feature_or_privilege_removal CHECK (((entitlement_feature_id IS NOT NULL) <> (entitlement_privilege_id IS NOT NULL)))
);


--
-- Name: error_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_details (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type character varying NOT NULL,
    owner_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    error_code integer DEFAULT 0 NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid,
    transaction_id character varying NOT NULL,
    code character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    "timestamp" timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    subscription_id uuid,
    deleted_at timestamp(6) without time zone,
    external_customer_id character varying,
    external_subscription_id character varying,
    precise_total_amount_cents numeric(40,15)
)
WITH (autovacuum_vacuum_scale_factor='0.005');


--
-- Name: exports_applied_coupons; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_applied_coupons AS
 SELECT ac.organization_id,
    ac.id AS lago_id,
    ac.coupon_id AS lago_coupon_id,
    ac.customer_id AS lago_customer_id,
        CASE ac.status
            WHEN 0 THEN 'active'::text
            WHEN 1 THEN 'terminated'::text
            ELSE NULL::text
        END AS status,
    ac.amount_cents,
        CASE ac.frequency
            WHEN 0 THEN NULL::bigint
            WHEN 1 THEN NULL::bigint
            ELSE
            CASE
                WHEN (cp.coupon_type = 1) THEN NULL::bigint
                ELSE (ac.amount_cents - ( SELECT (sum(cr.amount_cents))::bigint AS sum
                   FROM public.credits cr
                  WHERE (cr.applied_coupon_id = ac.id)))
            END
        END AS amount_cents_remaining,
    ac.amount_currency,
    ac.percentage_rate,
        CASE ac.frequency
            WHEN 0 THEN 'once'::text
            WHEN 1 THEN 'recurring'::text
            WHEN 2 THEN 'forever'::text
            ELSE NULL::text
        END AS frequency,
    ac.frequency_duration,
    ac.frequency_duration_remaining,
    ac.created_at,
    ac.terminated_at,
    ac.updated_at,
    ( SELECT json_agg(json_build_object('lago_id', cr.id, 'amount_cents', cr.amount_cents, 'amount_currency', cr.amount_currency, 'before_taxes', cr.before_taxes)) AS json_agg
           FROM public.credits cr
          WHERE (cr.applied_coupon_id = ac.id)) AS credits
   FROM (public.applied_coupons ac
     LEFT JOIN public.coupons cp ON ((cp.id = ac.coupon_id)));


--
-- Name: exports_billable_metrics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_billable_metrics AS
 SELECT bm.organization_id,
    bm.id AS lago_id,
    bm.name,
    bm.code,
    bm.description,
        CASE bm.aggregation_type
            WHEN 0 THEN 'count_agg'::text
            WHEN 1 THEN 'sum_agg'::text
            WHEN 2 THEN 'max_agg'::text
            WHEN 3 THEN 'unique_count_agg'::text
            WHEN 5 THEN 'weighted_sum_agg'::text
            WHEN 6 THEN 'latest_agg'::text
            WHEN 7 THEN 'custom_agg'::text
            ELSE 'unknown'::text
        END AS aggregation_type,
    (bm.weighted_interval)::text AS weighted_interval,
    bm.recurring,
    (bm.rounding_function)::text AS rounding_function,
    bm.rounding_precision,
    bm.created_at,
    bm.updated_at,
    bm.field_name,
    bm.expression,
    COALESCE(( SELECT json_agg(json_build_object('key', bmf.key, 'values', bmf."values")) AS json_agg
           FROM public.billable_metric_filters bmf
          WHERE ((bmf.billable_metric_id = bm.id) AND (bmf.deleted_at IS NULL))), '[]'::json) AS filters
   FROM public.billable_metrics bm
  WHERE (bm.deleted_at IS NULL);


--
-- Name: exports_billing_entities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_billing_entities AS
 SELECT be.organization_id,
    be.id AS lago_id,
    be.code,
    be.name,
    be.legal_name,
    be.legal_number,
    be.email,
    be.address_line1,
    be.address_line2,
    be.city,
    be.zipcode,
    be.state,
    be.country,
    be.vat_rate,
    be.timezone,
    be.created_at,
    be.updated_at,
    be.archived_at,
    be.deleted_at
   FROM public.billing_entities be;


--
-- Name: exports_charges; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_charges AS
 SELECT c.organization_id,
    c.id AS lago_id,
    c.billable_metric_id AS lago_billable_metric_id,
    c.plan_id AS lago_plan_id,
    c.invoice_display_name,
    c.created_at,
    c.updated_at,
    c.deleted_at,
        CASE c.charge_model
            WHEN 0 THEN 'standard'::text
            WHEN 1 THEN 'graduated'::text
            WHEN 2 THEN 'package'::text
            WHEN 3 THEN 'percentage'::text
            WHEN 4 THEN 'volume'::text
            WHEN 5 THEN 'graduated_percentage'::text
            WHEN 6 THEN 'custom'::text
            WHEN 7 THEN 'dynamic'::text
            ELSE NULL::text
        END AS charge_model,
    c.invoiceable,
        CASE c.regroup_paid_fees
            WHEN 0 THEN 'invoice'::text
            ELSE NULL::text
        END AS regroup_paid_fees,
    c.pay_in_advance,
    c.prorated,
    c.min_amount_cents,
    c.properties,
    ( SELECT json_agg(json_build_object('invoice_display_name', cf.invoice_display_name, 'properties', cf.properties, 'values', ( SELECT json_agg(json_build_object(cfcv.billable_metric_filter_id, cfcv."values")) AS json_agg
                   FROM public.charge_filter_values cfcv
                  WHERE (cfcv.charge_filter_id = cf.id)))) AS json_agg
           FROM public.charge_filters cf
          WHERE (cf.charge_id = c.id)) AS charge_filters
   FROM public.charges c;


--
-- Name: exports_coupons; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_coupons AS
 SELECT cp.organization_id,
    cp.id AS lago_id,
    cp.name,
    cp.code,
    cp.description,
        CASE cp.coupon_type
            WHEN 0 THEN 'fixed_amount'::text
            WHEN 1 THEN 'percentage'::text
            ELSE NULL::text
        END AS coupon_type,
    cp.amount_cents,
    cp.amount_currency,
    cp.percentage_rate,
        CASE cp.frequency
            WHEN 0 THEN 'once'::text
            WHEN 1 THEN 'recurring'::text
            WHEN 2 THEN 'forever'::text
            ELSE NULL::text
        END AS frequency,
    cp.frequency_duration,
    cp.reusable,
    cp.limited_plans,
    cp.limited_billable_metrics,
    to_json(ARRAY( SELECT cpt.plan_id
           FROM public.coupon_targets cpt
          WHERE ((cpt.coupon_id = cp.id) AND (cpt.plan_id IS NOT NULL)))) AS lago_plan_ids,
    to_json(ARRAY( SELECT cpt.billable_metric_id
           FROM public.coupon_targets cpt
          WHERE ((cpt.coupon_id = cp.id) AND (cpt.billable_metric_id IS NOT NULL)))) AS lago_billable_metrics_ids,
    cp.created_at,
        CASE cp.expiration
            WHEN 0 THEN 'no_expiration'::text
            WHEN 1 THEN 'time_limit'::text
            ELSE NULL::text
        END AS expiration,
    cp.expiration_at,
    cp.terminated_at,
    cp.updated_at
   FROM public.coupons cp;


--
-- Name: item_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_metadata (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    owner_type character varying NOT NULL,
    owner_id uuid NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT item_metadata_value_must_be_json_object CHECK ((jsonb_typeof(value) = 'object'::text))
);


--
-- Name: exports_credit_notes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_credit_notes AS
 SELECT cn.organization_id,
    cn.id AS lago_id,
    cn.sequential_id,
    cn.number,
    cn.invoice_id AS lago_invoice_id,
    cn.issuing_date,
        CASE cn.credit_status
            WHEN 0 THEN 'available'::text
            WHEN 1 THEN 'consumed'::text
            WHEN 2 THEN 'voided'::text
            ELSE NULL::text
        END AS credit_status,
        CASE cn.refund_status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'succeeded'::text
            WHEN 2 THEN 'failed'::text
            ELSE NULL::text
        END AS refund_status,
        CASE cn.reason
            WHEN 0 THEN 'duplicated_charge'::text
            WHEN 1 THEN 'product_unsatisfactory'::text
            WHEN 2 THEN 'order_change'::text
            WHEN 3 THEN 'order_cancellation'::text
            WHEN 4 THEN 'fraudulent_charge'::text
            WHEN 5 THEN 'other'::text
            ELSE NULL::text
        END AS reason,
    cn.description,
    cn.total_amount_currency AS currency,
    cn.total_amount_cents,
    cn.taxes_amount_cents,
    (round(((( SELECT (sum(ci.precise_amount_cents))::bigint AS sum
           FROM public.credit_note_items ci
          WHERE (ci.credit_note_id = cn.id)))::numeric - cn.precise_coupons_adjustment_amount_cents)))::bigint AS sub_total_excluding_taxes_amount_cents,
    cn.balance_amount_cents,
    cn.credit_amount_cents,
    cn.refund_amount_cents,
    cn.coupons_adjustment_amount_cents,
    cn.taxes_rate,
    cn.created_at,
    cn.updated_at,
    cn.refunded_at,
    ( SELECT json_agg(json_build_object('lago_id', ci.id, 'amount_cents', ci.amount_cents, 'amount_currency', ci.amount_currency, 'lago_fee_id', ci.fee_id)) AS json_agg
           FROM public.credit_note_items ci
          WHERE (ci.credit_note_id = cn.id)) AS items,
    ( SELECT json_agg(json_build_object('key', je.key, 'value', je.value)) AS json_agg
           FROM public.item_metadata im,
            LATERAL jsonb_each_text(im.value) je(key, value)
          WHERE (((im.owner_type)::text = 'CreditNote'::text) AND (im.owner_id = cn.id))) AS metadata,
    ( SELECT json_agg(json_build_object('lago_id', ed.id, 'error_code', ed.error_code, 'details', ed.details)) AS json_agg
           FROM public.error_details ed
          WHERE (((ed.owner_type)::text = 'CreditNote'::text) AND (ed.owner_id = cn.id))) AS error_details
   FROM public.credit_notes cn;


--
-- Name: exports_credit_notes_taxes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_credit_notes_taxes AS
 SELECT cnt.organization_id,
    cnt.id AS lago_id,
    cnt.tax_id AS lago_tax_id,
    cnt.credit_note_id AS lago_credit_note_id,
    cnt.tax_name,
    cnt.tax_code,
    cnt.tax_rate,
    cnt.tax_description,
    cnt.base_amount_cents,
    cnt.amount_cents,
    cnt.amount_currency,
    cnt.created_at,
    cnt.updated_at
   FROM public.credit_notes_taxes cnt;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    api_key character varying,
    webhook_url character varying,
    vat_rate double precision DEFAULT 0.0 NOT NULL,
    country character varying,
    address_line1 character varying,
    address_line2 character varying,
    state character varying,
    zipcode character varying,
    email character varying,
    city character varying,
    logo character varying,
    legal_name character varying,
    legal_number character varying,
    invoice_footer text,
    invoice_grace_period integer DEFAULT 0 NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    document_locale character varying DEFAULT 'en'::character varying NOT NULL,
    email_settings character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    tax_identification_number character varying,
    net_payment_term integer DEFAULT 0 NOT NULL,
    default_currency character varying DEFAULT 'USD'::character varying NOT NULL,
    document_numbering integer DEFAULT 0 NOT NULL,
    document_number_prefix character varying,
    eu_tax_management boolean DEFAULT false,
    premium_integrations character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    custom_aggregation boolean DEFAULT false,
    finalize_zero_amount_invoice boolean DEFAULT true NOT NULL,
    clickhouse_events_store boolean DEFAULT false NOT NULL,
    hmac_key character varying NOT NULL,
    authentication_methods character varying[] DEFAULT '{email_password,google_oauth}'::character varying[] NOT NULL,
    audit_logs_period integer DEFAULT 30,
    pre_filter_events boolean DEFAULT false NOT NULL,
    clickhouse_deduplication_enabled boolean DEFAULT false NOT NULL,
    feature_flags character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    max_wallets integer,
    slug character varying NOT NULL,
    CONSTRAINT check_organizations_on_invoice_grace_period CHECK ((invoice_grace_period >= 0)),
    CONSTRAINT check_organizations_on_net_payment_term CHECK ((net_payment_term >= 0))
);


--
-- Name: payment_provider_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_provider_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    payment_provider_id uuid,
    type character varying NOT NULL,
    provider_customer_id character varying,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    organization_id uuid NOT NULL
);


--
-- Name: exports_customers; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_customers AS
 SELECT c.organization_id,
    c.id AS lago_id,
    c.billing_entity_id,
    c.external_id,
    (c.account_type)::text AS account_type,
    c.name,
    c.firstname,
    c.lastname,
    (c.customer_type)::text AS customer_type,
    c.sequential_id,
    c.slug,
    c.created_at,
    c.updated_at,
    c.deleted_at,
    c.country,
    c.address_line1,
    c.address_line2,
    c.state,
    c.zipcode,
    c.email,
    c.city,
    c.url,
    c.phone,
    c.legal_name,
    c.legal_number,
    c.currency,
    c.tax_identification_number,
    c.timezone,
    COALESCE(c.timezone, o.timezone, 'UTC'::character varying) AS applicable_timezone,
    c.net_payment_term,
    c.external_salesforce_id,
        CASE c.finalize_zero_amount_invoice
            WHEN 0 THEN 'inherit'::text
            WHEN 1 THEN 'skip'::text
            WHEN 2 THEN 'finalize'::text
            ELSE NULL::text
        END AS finalize_zero_amount_invoice,
    c.skip_invoice_custom_sections,
    c.payment_provider,
    c.payment_provider_code,
    c.invoice_grace_period,
    c.vat_rate,
    COALESCE(c.invoice_grace_period, o.invoice_grace_period) AS applicable_invoice_grace_period,
    c.document_locale,
    ppc.provider_customer_id,
    ppc.settings AS provider_settings,
    '{}'::json AS metadata,
    '[]'::json AS lago_taxes_ids
   FROM ((public.customers c
     LEFT JOIN public.organizations o ON ((o.id = c.organization_id)))
     LEFT JOIN public.payment_provider_customers ppc ON (((ppc.customer_id = c.id) AND (ppc.deleted_at IS NULL) AND (ppc.payment_provider_id IS NOT NULL))));


--
-- Name: exports_daily_usages; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_daily_usages AS
 SELECT du.organization_id,
    du.id AS lago_id,
    du.from_datetime,
    du.to_datetime,
    du.refreshed_at,
    du.usage_date,
    du.usage AS daily_usage,
    du.usage_diff AS daily_usage_diff,
    du.created_at,
    du.updated_at,
    du.customer_id AS lago_customer_id,
    du.subscription_id AS lago_subscription_id,
    du.external_subscription_id
   FROM public.daily_usages du;


--
-- Name: exports_entitlement_entitlement_values; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_entitlement_entitlement_values AS
 SELECT ev.id AS lago_id,
    ev.organization_id,
    ev.entitlement_entitlement_id AS lago_entitlement_entitlement_id,
    ev.entitlement_privilege_id AS lago_entitlement_privilege_id,
    ev.value,
    ev.deleted_at,
    ev.created_at,
    ev.updated_at
   FROM public.entitlement_entitlement_values ev;


--
-- Name: exports_entitlement_entitlements; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_entitlement_entitlements AS
 SELECT ee.id AS lago_id,
    ee.organization_id,
    ee.entitlement_feature_id AS lago_entitlement_feature_id,
    ee.plan_id AS lago_plan_id,
    ee.subscription_id AS lago_subscription_id,
    ee.deleted_at,
    ee.created_at,
    ee.updated_at
   FROM public.entitlement_entitlements ee;


--
-- Name: exports_entitlement_features; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_entitlement_features AS
 SELECT ef.id AS lago_id,
    ef.organization_id,
    ef.code,
    ef.name,
    ef.description,
    ef.deleted_at,
    ef.created_at,
    ef.updated_at
   FROM public.entitlement_features ef;


--
-- Name: fees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid,
    charge_id uuid,
    subscription_id uuid,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    taxes_amount_cents bigint NOT NULL,
    taxes_rate double precision DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    units numeric DEFAULT 0.0 NOT NULL,
    applied_add_on_id uuid,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    fee_type integer,
    invoiceable_type character varying,
    invoiceable_id uuid,
    events_count integer,
    group_id uuid,
    pay_in_advance_event_id uuid,
    payment_status integer DEFAULT 0 NOT NULL,
    succeeded_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    refunded_at timestamp(6) without time zone,
    true_up_parent_fee_id uuid,
    add_on_id uuid,
    description character varying,
    unit_amount_cents bigint DEFAULT 0 NOT NULL,
    pay_in_advance boolean DEFAULT false NOT NULL,
    precise_coupons_amount_cents numeric(30,5) DEFAULT 0.0 NOT NULL,
    total_aggregated_units numeric,
    invoice_display_name character varying,
    precise_unit_amount numeric(30,15) DEFAULT 0.0 NOT NULL,
    amount_details jsonb DEFAULT '{}'::jsonb NOT NULL,
    charge_filter_id uuid,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    pay_in_advance_event_transaction_id character varying,
    deleted_at timestamp(6) without time zone,
    precise_amount_cents numeric(40,15) DEFAULT 0.0 NOT NULL,
    taxes_precise_amount_cents numeric(40,15) DEFAULT 0.0 NOT NULL,
    taxes_base_rate double precision DEFAULT 1.0 NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid NOT NULL,
    precise_credit_notes_amount_cents numeric(30,5) DEFAULT 0.0 NOT NULL,
    fixed_charge_id uuid,
    duplicated_in_advance boolean DEFAULT false,
    original_fee_id uuid
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code character varying NOT NULL,
    "interval" integer NOT NULL,
    description character varying,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    trial_period double precision,
    pay_in_advance boolean DEFAULT false NOT NULL,
    bill_charges_monthly boolean,
    parent_id uuid,
    deleted_at timestamp(6) without time zone,
    pending_deletion boolean DEFAULT false NOT NULL,
    invoice_display_name character varying,
    bill_fixed_charges_monthly boolean DEFAULT false
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    status integer NOT NULL,
    canceled_at timestamp without time zone,
    terminated_at timestamp without time zone,
    started_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    previous_subscription_id uuid,
    name character varying,
    external_id character varying NOT NULL,
    billing_time integer DEFAULT 0 NOT NULL,
    subscription_at timestamp(6) without time zone,
    ending_at timestamp(6) without time zone,
    trial_ended_at timestamp(6) without time zone,
    organization_id uuid NOT NULL,
    on_termination_credit_note public.subscription_on_termination_credit_note,
    on_termination_invoice public.subscription_on_termination_invoice DEFAULT 'generate'::public.subscription_on_termination_invoice NOT NULL,
    payment_method_id uuid,
    payment_method_type public.payment_method_types DEFAULT 'provider'::public.payment_method_types NOT NULL,
    skip_invoice_custom_sections boolean DEFAULT false NOT NULL,
    progressive_billing_disabled boolean DEFAULT false NOT NULL,
    last_received_event_on date,
    cancelation_reason public.subscription_cancelation_reasons,
    incompleted_at timestamp(6) without time zone,
    activated_at timestamp(6) without time zone,
    billing_entity_id uuid,
    consolidate_invoice boolean DEFAULT true NOT NULL,
    skip_daily_usage boolean DEFAULT false NOT NULL,
    cancellation_reason public.subscription_cancellation_reasons
);


--
-- Name: exports_fees; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_fees AS
 SELECT f.organization_id,
    f.id AS lago_id,
    f.charge_id AS lago_charge_id,
    f.charge_filter_id AS lago_charge_filter_id,
    f.invoice_id AS lago_invoice_id,
    f.subscription_id AS lago_subscription_id,
    c.id AS lago_customer_id,
    json_build_object('type',
        CASE f.fee_type
            WHEN 0 THEN 'charge'::text
            WHEN 1 THEN 'add_on'::text
            WHEN 2 THEN 'subscription'::text
            WHEN 3 THEN 'credit'::text
            WHEN 4 THEN 'commitment'::text
            ELSE 'unknown'::text
        END, 'code',
        CASE f.fee_type
            WHEN 0 THEN bm.code
            WHEN 1 THEN ao.code
            WHEN 3 THEN 'credit'::character varying
            ELSE p.code
        END, 'name',
        CASE f.fee_type
            WHEN 0 THEN bm.name
            WHEN 1 THEN ao.name
            WHEN 3 THEN 'credit'::character varying
            ELSE p.name
        END, 'description',
        CASE f.fee_type
            WHEN 0 THEN bm.description
            WHEN 1 THEN ao.description
            WHEN 3 THEN 'credit'::character varying
            ELSE p.description
        END, 'invoice_display_name', COALESCE(f.invoice_display_name,
        CASE f.fee_type
            WHEN 0 THEN COALESCE(ch.invoice_display_name, bm.name)
            WHEN 1 THEN COALESCE(ao.invoice_display_name, ao.name)
            WHEN 3 THEN 'credit'::character varying
            ELSE p.invoice_display_name
        END), 'filters', ( SELECT json_agg(json_build_object('id', cf.id, 'charge_id', cf.charge_id, 'properties', cf.properties, 'invoice_display_name', cf.invoice_display_name)) AS json_agg
           FROM public.charge_filters cf
          WHERE (cf.charge_id = f.charge_id)), 'lago_item_id',
        CASE f.fee_type
            WHEN 0 THEN bm.id
            WHEN 1 THEN ao.id
            WHEN 3 THEN f.invoiceable_id
            ELSE f.subscription_id
        END, 'item_type',
        CASE f.fee_type
            WHEN 0 THEN 'billable_metric'::text
            WHEN 1 THEN 'add_on'::text
            WHEN 3 THEN 'wallet_transaction'::text
            ELSE 'subscription'::text
        END, 'grouped_by', f.grouped_by) AS item,
    f.pay_in_advance,
    f.amount_cents,
    ch.invoiceable,
    f.taxes_amount_cents,
    f.taxes_precise_amount_cents,
    f.taxes_rate,
    (f.amount_cents + f.taxes_amount_cents) AS total_amount_cents,
    f.amount_currency AS currency,
    f.units,
    f.description,
    f.precise_amount_cents,
    f.precise_unit_amount,
    f.precise_coupons_amount_cents,
    (f.precise_amount_cents + f.taxes_precise_amount_cents) AS precise_total_amount_cents,
    f.precise_credit_notes_amount_cents,
    f.events_count,
        CASE f.payment_status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'succeeded'::text
            WHEN 2 THEN 'failed'::text
            WHEN 3 THEN 'refunded'::text
            ELSE 'unknown'::text
        END AS payment_status,
    f.created_at,
    f.succeeded_at,
    f.failed_at,
    f.refunded_at,
    f.amount_details,
    f.updated_at,
        CASE f.fee_type
            WHEN 0 THEN (((f.properties ->> 'charges_from_datetime'::text))::timestamp with time zone)::text
            ELSE (((f.properties ->> 'from_datetime'::text))::timestamp with time zone)::text
        END AS from_date,
        CASE f.fee_type
            WHEN 0 THEN (((f.properties ->> 'charges_to_datetime'::text))::timestamp with time zone)::text
            ELSE (((f.properties ->> 'to_datetime'::text))::timestamp with time zone)::text
        END AS to_date
   FROM ((((((public.fees f
     LEFT JOIN public.subscriptions s ON ((f.subscription_id = s.id)))
     LEFT JOIN public.customers c ON ((s.customer_id = c.id)))
     LEFT JOIN public.charges ch ON ((f.charge_id = ch.id)))
     LEFT JOIN public.billable_metrics bm ON ((ch.billable_metric_id = bm.id)))
     LEFT JOIN public.add_ons ao ON ((f.add_on_id = ao.id)))
     LEFT JOIN public.plans p ON ((s.plan_id = p.id)));


--
-- Name: fees_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fees_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fee_id uuid NOT NULL,
    tax_id uuid,
    tax_description character varying,
    tax_code character varying NOT NULL,
    tax_name character varying NOT NULL,
    tax_rate double precision DEFAULT 0.0 NOT NULL,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    precise_amount_cents numeric(40,15) DEFAULT 0.0 NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: exports_fees_taxes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_fees_taxes AS
 SELECT ft.organization_id,
    ft.id AS lago_id,
    ft.fee_id AS lago_fee_id,
    ft.tax_id AS lago_tax_id,
    ft.tax_name,
    ft.tax_code,
    ft.tax_rate,
    ft.tax_description,
    ft.amount_cents,
    ft.amount_currency,
    ft.created_at,
    ft.updated_at
   FROM public.fees_taxes ft;


--
-- Name: integration_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    integration_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    external_customer_id character varying,
    type character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: exports_integration_customers; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_integration_customers AS
 SELECT ic.id AS lago_id,
    ic.organization_id,
    ic.customer_id AS lago_customer_id,
    ic.integration_id AS lago_integration_id,
    ic.external_customer_id,
    ic.type,
    ic.settings,
    ic.created_at,
    ic.updated_at
   FROM public.integration_customers ic;


--
-- Name: invoice_settlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_settlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid NOT NULL,
    target_invoice_id uuid NOT NULL,
    settlement_type public.invoice_settlement_settlement_type NOT NULL,
    source_payment_id uuid,
    source_credit_note_id uuid,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: exports_invoice_settlements; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_invoice_settlements AS
 SELECT ins.id AS lago_id,
    ins.organization_id,
    ins.billing_entity_id AS lago_billing_entity_id,
    ins.target_invoice_id AS lago_target_invoice_id,
    (ins.settlement_type)::text AS settlement_type,
    ins.source_payment_id AS lago_source_payment_id,
    ins.source_credit_note_id AS lago_source_credit_note_id,
    ins.amount_cents,
    ins.amount_currency,
    ins.created_at,
    ins.updated_at
   FROM public.invoice_settlements ins;


--
-- Name: invoice_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    recurring boolean,
    "timestamp" timestamp(6) without time zone,
    from_datetime timestamp(6) without time zone,
    to_datetime timestamp(6) without time zone,
    charges_from_datetime timestamp(6) without time zone,
    charges_to_datetime timestamp(6) without time zone,
    invoicing_reason public.subscription_invoicing_reason,
    organization_id uuid NOT NULL,
    regenerated_invoice_id uuid,
    fixed_charges_from_datetime timestamp(6) without time zone,
    fixed_charges_to_datetime timestamp(6) without time zone
);


--
-- Name: exports_invoice_subscriptions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_invoice_subscriptions AS
 SELECT ins.organization_id,
    ins.id AS lago_id,
    ins.invoice_id AS lago_invoice_id,
    ins.regenerated_invoice_id AS lago_regenerated_invoice_id,
    ins.subscription_id AS lago_subscription_id,
    ins.created_at,
    ins.updated_at,
    ins.from_datetime,
    ins.to_datetime,
    ins.charges_from_datetime,
    ins.charges_to_datetime,
    ins."timestamp",
    (ins.invoicing_reason)::text AS invoicing_reason
   FROM public.invoice_subscriptions ins;


--
-- Name: invoice_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_metadata (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    issuing_date date,
    taxes_amount_cents bigint DEFAULT 0 NOT NULL,
    total_amount_cents bigint DEFAULT 0 NOT NULL,
    invoice_type integer DEFAULT 0 NOT NULL,
    payment_status integer DEFAULT 0 NOT NULL,
    number character varying DEFAULT ''::character varying NOT NULL,
    sequential_id integer,
    file character varying,
    customer_id uuid,
    taxes_rate double precision DEFAULT 0.0 NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    payment_attempts integer DEFAULT 0 NOT NULL,
    ready_for_payment_processing boolean DEFAULT true NOT NULL,
    organization_id uuid NOT NULL,
    version_number integer DEFAULT 4 NOT NULL,
    currency character varying,
    fees_amount_cents bigint DEFAULT 0 NOT NULL,
    coupons_amount_cents bigint DEFAULT 0 NOT NULL,
    credit_notes_amount_cents bigint DEFAULT 0 NOT NULL,
    prepaid_credit_amount_cents bigint DEFAULT 0 NOT NULL,
    sub_total_excluding_taxes_amount_cents bigint DEFAULT 0 NOT NULL,
    sub_total_including_taxes_amount_cents bigint DEFAULT 0 NOT NULL,
    payment_due_date date,
    net_payment_term integer DEFAULT 0 NOT NULL,
    voided_at timestamp(6) without time zone,
    organization_sequential_id integer DEFAULT 0 NOT NULL,
    ready_to_be_refreshed boolean DEFAULT false NOT NULL,
    payment_dispute_lost_at timestamp(6) without time zone DEFAULT NULL::timestamp without time zone,
    skip_charges boolean DEFAULT false NOT NULL,
    payment_overdue boolean DEFAULT false,
    negative_amount_cents bigint DEFAULT 0 NOT NULL,
    progressive_billing_credit_amount_cents bigint DEFAULT 0 NOT NULL,
    tax_status public.tax_status,
    total_paid_amount_cents bigint DEFAULT 0 NOT NULL,
    self_billed boolean DEFAULT false NOT NULL,
    applied_grace_period integer,
    billing_entity_id uuid NOT NULL,
    billing_entity_sequential_id integer,
    finalized_at timestamp without time zone,
    voided_invoice_id uuid,
    xml_file character varying,
    expected_finalization_date date,
    prepaid_granted_credit_amount_cents bigint,
    prepaid_purchased_credit_amount_cents bigint,
    payment_method_id uuid,
    skip_automatic_payment boolean,
    purchase_order_number character varying,
    CONSTRAINT check_organizations_on_net_payment_term CHECK ((net_payment_term >= 0))
);


--
-- Name: exports_invoices; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_invoices AS
 SELECT i.organization_id,
    i.id AS lago_id,
    i.sequential_id,
    i.customer_id,
    i.number,
    (i.issuing_date)::timestamp with time zone AS issuing_date,
    (i.payment_due_date)::timestamp with time zone AS payment_due_date,
    i.net_payment_term,
        CASE i.invoice_type
            WHEN 0 THEN 'subscription'::text
            WHEN 1 THEN 'add_on'::text
            WHEN 2 THEN 'credit'::text
            WHEN 3 THEN 'one_off'::text
            WHEN 4 THEN 'advance_charges'::text
            WHEN 5 THEN 'progressive_billing'::text
            ELSE NULL::text
        END AS invoice_type,
        CASE i.status
            WHEN 0 THEN 'draft'::text
            WHEN 1 THEN 'finalized'::text
            WHEN 2 THEN 'voided'::text
            WHEN 3 THEN 'generating'::text
            WHEN 4 THEN 'failed'::text
            WHEN 5 THEN 'open'::text
            WHEN 6 THEN 'close'::text
            WHEN 7 THEN 'pending'::text
            ELSE NULL::text
        END AS status,
        CASE i.payment_status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'succeeded'::text
            WHEN 2 THEN 'failed'::text
            ELSE NULL::text
        END AS payment_status,
    (i.payment_dispute_lost_at)::timestamp with time zone AS payment_dispute_lost_at,
    i.payment_overdue,
    i.currency,
    i.fees_amount_cents,
    i.taxes_amount_cents,
    i.progressive_billing_credit_amount_cents,
    i.coupons_amount_cents,
    i.credit_notes_amount_cents,
    i.sub_total_excluding_taxes_amount_cents,
    i.sub_total_including_taxes_amount_cents,
    i.total_amount_cents,
    (i.total_amount_cents - i.total_paid_amount_cents) AS total_due_amount_cents,
    i.prepaid_credit_amount_cents,
    i.prepaid_granted_credit_amount_cents,
    i.prepaid_purchased_credit_amount_cents,
    i.version_number,
    i.created_at,
    i.updated_at,
    i.voided_at,
    ( SELECT json_agg(json_build_object('lago_id', m.id, 'key', m.key, 'value', m.value, 'created_at', m.created_at)) AS json_agg
           FROM public.invoice_metadata m
          WHERE (m.invoice_id = i.id)) AS metadata,
    ( SELECT json_agg(json_build_object('lago_id', ed.id, 'error_code', ed.error_code, 'details', ed.details)) AS json_agg
           FROM public.error_details ed
          WHERE (ed.owner_id = i.id)) AS error_details
   FROM public.invoices i
  WHERE (i.status = ANY (ARRAY[0, 1, 2, 4, 7]));


--
-- Name: invoices_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    tax_id uuid,
    tax_description character varying,
    tax_code character varying NOT NULL,
    tax_name character varying NOT NULL,
    tax_rate double precision DEFAULT 0.0 NOT NULL,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    fees_amount_cents bigint DEFAULT 0 NOT NULL,
    taxable_base_amount_cents bigint DEFAULT 0 NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: exports_invoices_taxes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_invoices_taxes AS
 SELECT it.organization_id,
    it.id AS lago_id,
    it.invoice_id AS lago_invoice_id,
    it.tax_id AS lago_tax_id,
    it.tax_name,
    it.tax_code,
    it.tax_rate,
    it.tax_description,
    it.amount_cents,
    it.amount_currency,
    it.fees_amount_cents,
    it.created_at,
    it.updated_at
   FROM public.invoices_taxes it;


--
-- Name: exports_item_metadata; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_item_metadata AS
 SELECT im.id AS lago_id,
    im.organization_id,
    im.owner_type,
    im.owner_id AS lago_owner_id,
    im.value,
    im.created_at,
    im.updated_at
   FROM public.item_metadata im;


--
-- Name: invoices_payment_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices_payment_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    payment_request_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: payment_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    email character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL,
    payment_status integer DEFAULT 0 NOT NULL,
    payment_attempts integer DEFAULT 0 NOT NULL,
    ready_for_payment_processing boolean DEFAULT true NOT NULL,
    dunning_campaign_id uuid
);


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid,
    payment_provider_id uuid,
    payment_provider_customer_id uuid,
    amount_cents bigint NOT NULL,
    amount_currency character varying NOT NULL,
    provider_payment_id character varying,
    status character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    payable_type character varying DEFAULT 'Invoice'::character varying NOT NULL,
    payable_id uuid,
    provider_payment_data jsonb DEFAULT '{}'::jsonb,
    payable_payment_status public.payment_payable_payment_status,
    payment_type public.payment_type DEFAULT 'provider'::public.payment_type NOT NULL,
    reference character varying,
    provider_payment_method_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider_payment_method_id character varying,
    organization_id uuid NOT NULL,
    customer_id uuid,
    error_code character varying,
    payment_method_id uuid
);


--
-- Name: exports_payment_requests; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_payment_requests AS
 SELECT pr.organization_id,
    pr.id AS lago_id,
    pr.customer_id AS lago_customer_id,
    pr.payment_attempts,
    pr.amount_cents,
    pr.amount_currency,
    pr.email,
    pr.ready_for_payment_processing,
        CASE pr.payment_status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'succeeded'::text
            WHEN 2 THEN 'failed'::text
            ELSE NULL::text
        END AS payment_status,
    to_json(ARRAY( SELECT p.id
           FROM public.payments p
          WHERE ((p.payable_id = pr.id) AND ((p.payable_type)::text = 'PaymentRequest'::text))
          ORDER BY p.created_at)) AS payment_ids,
    to_json(ARRAY( SELECT apr.invoice_id
           FROM public.invoices_payment_requests apr
          WHERE (apr.payment_request_id = pr.id)
          ORDER BY apr.created_at)) AS invoice_ids,
    pr.created_at,
    pr.updated_at
   FROM public.payment_requests pr;


--
-- Name: exports_payments; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_payments AS
 SELECT p.organization_id,
    p.id AS lago_id,
    p.amount_cents,
    p.amount_currency,
    (p.payable_payment_status)::text AS payment_status,
    (p.payment_type)::text AS payment_type,
    p.reference,
    p.provider_payment_id AS external_payment_id,
    (p.created_at)::timestamp with time zone AS created_at,
    (p.updated_at)::timestamp with time zone AS updated_at,
        CASE
            WHEN ((p.payable_type)::text = 'Invoice'::text) THEN to_json(ARRAY[p.payable_id])
            WHEN ((p.payable_type)::text = 'PaymentRequest'::text) THEN to_json(ARRAY( SELECT ai.invoice_id
               FROM public.invoices_payment_requests ai
              WHERE (ai.payment_request_id = p.payable_id)
              ORDER BY ai.created_at))
            ELSE to_json(ARRAY[]::uuid[])
        END AS invoice_ids
   FROM public.payments p;


--
-- Name: plans_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: exports_plans; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_plans AS
 SELECT p.organization_id,
    p.id AS lago_id,
    p.name,
    p.invoice_display_name,
    p.created_at,
    p.updated_at,
    p.code,
        CASE p."interval"
            WHEN 0 THEN 'weekly'::text
            WHEN 1 THEN 'monthly'::text
            WHEN 2 THEN 'yearly'::text
            WHEN 3 THEN 'quarterly'::text
            ELSE NULL::text
        END AS plan_interval,
    p.description,
    p.amount_cents,
    p.amount_currency,
    p.trial_period,
    p.pay_in_advance,
    p.bill_charges_monthly,
    p.parent_id,
    to_json(ARRAY( SELECT pt.tax_id AS lago_tax_id
           FROM public.plans_taxes pt
          WHERE (pt.plan_id = p.id))) AS lago_taxes_ids
   FROM public.plans p
  WHERE (p.deleted_at IS NULL);


--
-- Name: exports_subscriptions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_subscriptions AS
 SELECT s.organization_id,
    s.id AS lago_id,
    s.external_id,
    s.customer_id AS lago_customer_id,
    s.name,
    s.plan_id AS lago_plan_id,
        CASE s.status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'active'::text
            WHEN 2 THEN 'terminated'::text
            WHEN 3 THEN 'canceled'::text
            ELSE NULL::text
        END AS status,
        CASE s.billing_time
            WHEN 0 THEN 'calendar'::text
            WHEN 1 THEN 'anniversary'::text
            ELSE NULL::text
        END AS billing_time,
    s.subscription_at,
    s.started_at,
    s.trial_ended_at,
    s.ending_at,
    s.terminated_at,
    s.canceled_at,
    s.created_at,
    s.updated_at,
    to_json(ARRAY( SELECT ns.id
           FROM public.subscriptions ns
          WHERE (ns.previous_subscription_id = s.id))) AS lago_next_subscriptions_id,
    s.previous_subscription_id AS lago_previous_subscription_id
   FROM public.subscriptions s;


--
-- Name: taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    description character varying,
    code character varying NOT NULL,
    name character varying NOT NULL,
    rate double precision DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    applied_to_organization boolean DEFAULT false NOT NULL,
    auto_generated boolean DEFAULT false NOT NULL,
    deleted_at timestamp(6) without time zone
);


--
-- Name: exports_taxes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_taxes AS
 SELECT tx.organization_id,
    tx.id AS lago_id,
    tx.name,
    tx.code,
    tx.rate,
    tx.description,
    tx.applied_to_organization,
    tx.created_at,
    tx.updated_at
   FROM public.taxes tx;


--
-- Name: usage_monitoring_alert_thresholds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_monitoring_alert_thresholds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    usage_monitoring_alert_id uuid NOT NULL,
    value numeric(30,5) NOT NULL,
    code character varying,
    recurring boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: exports_usage_monitoring_alert_thresholds; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_usage_monitoring_alert_thresholds AS
 SELECT ath.id AS lago_id,
    ath.organization_id,
    ath.usage_monitoring_alert_id AS lago_alert_id,
    ath.value,
    ath.code,
    ath.recurring,
    ath.created_at,
    ath.updated_at
   FROM public.usage_monitoring_alert_thresholds ath;


--
-- Name: usage_monitoring_triggered_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_monitoring_triggered_alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    usage_monitoring_alert_id uuid NOT NULL,
    subscription_id uuid,
    current_value numeric(30,5) NOT NULL,
    previous_value numeric(30,5) NOT NULL,
    crossed_thresholds jsonb DEFAULT '{}'::jsonb,
    triggered_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    wallet_id uuid,
    CONSTRAINT chk_triggered_alerts_subscription_xor_wallet CHECK (((subscription_id IS NOT NULL) <> (wallet_id IS NOT NULL)))
);


--
-- Name: exports_usage_monitoring_triggered_alerts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_usage_monitoring_triggered_alerts AS
 SELECT ta.id AS lago_id,
    ta.organization_id,
    ta.usage_monitoring_alert_id AS lago_alert_id,
    ta.subscription_id AS lago_subscription_id,
    ta.wallet_id AS lago_wallet_id,
    ta.current_value,
    ta.previous_value,
    ta.crossed_thresholds,
    ta.triggered_at,
    ta.created_at,
    ta.updated_at
   FROM public.usage_monitoring_triggered_alerts ta;


--
-- Name: usage_thresholds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_thresholds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid,
    threshold_display_name character varying,
    amount_cents bigint NOT NULL,
    recurring boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    organization_id uuid NOT NULL,
    subscription_id uuid,
    CONSTRAINT usage_thresholds_check_exactly_one_parent CHECK (((plan_id IS NOT NULL) <> (subscription_id IS NOT NULL)))
);


--
-- Name: exports_usage_thresholds; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_usage_thresholds AS
 SELECT ut.organization_id,
    ut.plan_id AS lago_plan_id,
    ut.id AS lago_id,
    ut.amount_cents,
    ut.recurring,
    ut.threshold_display_name,
    ut.created_at,
    ut.updated_at,
    ut.deleted_at
   FROM public.usage_thresholds ut;


--
-- Name: wallet_transaction_consumptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_transaction_consumptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    inbound_wallet_transaction_id uuid NOT NULL,
    outbound_wallet_transaction_id uuid NOT NULL,
    consumed_amount_cents bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: exports_wallet_transaction_consumptions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_wallet_transaction_consumptions AS
 SELECT wtc.id AS lago_id,
    wtc.organization_id,
    wtc.inbound_wallet_transaction_id AS lago_inbound_wallet_transaction_id,
    wtc.outbound_wallet_transaction_id AS lago_outbound_wallet_transaction_id,
    wtc.consumed_amount_cents,
    wtc.created_at,
    wtc.updated_at
   FROM public.wallet_transaction_consumptions wtc;


--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_id uuid NOT NULL,
    transaction_type integer NOT NULL,
    status integer NOT NULL,
    amount numeric(30,5) DEFAULT 0.0 NOT NULL,
    credit_amount numeric(30,5) DEFAULT 0.0 NOT NULL,
    settled_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    invoice_id uuid,
    source integer DEFAULT 0 NOT NULL,
    transaction_status integer DEFAULT 0 NOT NULL,
    invoice_requires_successful_payment boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '[]'::jsonb,
    credit_note_id uuid,
    failed_at timestamp(6) without time zone,
    organization_id uuid NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    priority integer DEFAULT 50 NOT NULL,
    name character varying(255),
    payment_method_id uuid,
    payment_method_type public.payment_method_types DEFAULT 'provider'::public.payment_method_types NOT NULL,
    skip_invoice_custom_sections boolean DEFAULT false NOT NULL,
    remaining_amount_cents bigint,
    voided_invoice_id uuid,
    billing_entity_id uuid,
    CONSTRAINT remaining_amount_cents_non_negative CHECK (((remaining_amount_cents >= 0) OR (remaining_amount_cents IS NULL)))
);


--
-- Name: exports_wallet_transactions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_wallet_transactions AS
 SELECT wt.organization_id,
    wt.id AS lago_id,
    wt.wallet_id AS lago_wallet_id,
        CASE wt.status
            WHEN 0 THEN 'pending'::text
            WHEN 1 THEN 'settled'::text
            WHEN 2 THEN 'failed'::text
            ELSE NULL::text
        END AS status,
        CASE wt.source
            WHEN 0 THEN 'manual'::text
            WHEN 1 THEN 'interval'::text
            WHEN 2 THEN 'threshold'::text
            ELSE NULL::text
        END AS source,
        CASE wt.transaction_status
            WHEN 0 THEN 'purchased'::text
            WHEN 1 THEN 'granted'::text
            WHEN 2 THEN 'voided'::text
            WHEN 3 THEN 'invoiced'::text
            ELSE NULL::text
        END AS transaction_status,
        CASE wt.transaction_type
            WHEN 0 THEN 'inbound'::text
            WHEN 1 THEN 'outbound'::text
            ELSE NULL::text
        END AS transaction_type,
    wt.amount,
    wt.credit_amount,
    wt.settled_at,
    wt.failed_at,
    wt.created_at,
    wt.updated_at,
    wt.invoice_requires_successful_payment,
    wt.metadata,
    wt.invoice_id AS lago_invoice_id
   FROM public.wallet_transactions wt;


--
-- Name: wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_id uuid NOT NULL,
    status integer NOT NULL,
    name character varying,
    rate_amount numeric(30,5) DEFAULT 0.0 NOT NULL,
    credits_balance numeric(30,5) DEFAULT 0.0 NOT NULL,
    consumed_credits numeric(30,5) DEFAULT 0.0 NOT NULL,
    expiration_at timestamp without time zone,
    last_balance_sync_at timestamp without time zone,
    last_consumed_credit_at timestamp without time zone,
    terminated_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    balance_cents bigint DEFAULT 0 NOT NULL,
    balance_currency character varying NOT NULL,
    consumed_amount_cents bigint DEFAULT 0 NOT NULL,
    consumed_amount_currency character varying NOT NULL,
    ongoing_balance_cents bigint DEFAULT 0 NOT NULL,
    ongoing_usage_balance_cents bigint DEFAULT 0 NOT NULL,
    credits_ongoing_balance numeric(30,5) DEFAULT 0.0 NOT NULL,
    credits_ongoing_usage_balance numeric(30,5) DEFAULT 0.0 NOT NULL,
    depleted_ongoing_balance boolean DEFAULT false NOT NULL,
    invoice_requires_successful_payment boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    ready_to_be_refreshed boolean DEFAULT false NOT NULL,
    organization_id uuid NOT NULL,
    allowed_fee_types character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    last_ongoing_balance_sync_at timestamp without time zone,
    priority integer DEFAULT 50 NOT NULL,
    paid_top_up_min_amount_cents bigint,
    paid_top_up_max_amount_cents bigint,
    payment_method_id uuid,
    payment_method_type public.payment_method_types DEFAULT 'provider'::public.payment_method_types NOT NULL,
    skip_invoice_custom_sections boolean DEFAULT false NOT NULL,
    traceable boolean DEFAULT false NOT NULL,
    code character varying,
    billing_entity_id uuid
);


--
-- Name: exports_wallets; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exports_wallets AS
 SELECT w.organization_id,
    w.id AS lago_id,
    w.customer_id AS lago_customer_id,
        CASE w.status
            WHEN 0 THEN 'active'::text
            WHEN 1 THEN 'terminated'::text
            ELSE NULL::text
        END AS status,
    w.balance_currency AS currency,
    w.name,
    w.rate_amount,
    w.credits_balance,
    w.credits_ongoing_balance,
    w.credits_ongoing_usage_balance,
    w.balance_cents,
    w.ongoing_balance_cents,
    w.ongoing_usage_balance_cents,
    w.consumed_credits,
    w.created_at,
    w.updated_at,
    w.terminated_at,
    w.last_balance_sync_at,
    w.last_consumed_credit_at,
    w.invoice_requires_successful_payment
   FROM public.wallets w;


--
-- Name: fixed_charge_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixed_charge_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    fixed_charge_id uuid NOT NULL,
    units numeric(30,10) DEFAULT 0.0 NOT NULL,
    "timestamp" timestamp(6) without time zone,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: fixed_charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixed_charges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    add_on_id uuid NOT NULL,
    parent_id uuid,
    charge_model public.fixed_charge_charge_model DEFAULT 'standard'::public.fixed_charge_charge_model NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    invoice_display_name character varying,
    pay_in_advance boolean DEFAULT false NOT NULL,
    prorated boolean DEFAULT false NOT NULL,
    units numeric(30,10) DEFAULT 0.0 NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code character varying NOT NULL
);


--
-- Name: fixed_charges_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixed_charges_taxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fixed_charge_id uuid NOT NULL,
    tax_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: flat_filters; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.flat_filters AS
SELECT
    NULL::uuid AS organization_id,
    NULL::character varying AS billable_metric_code,
    NULL::uuid AS plan_id,
    NULL::uuid AS charge_id,
    NULL::timestamp(6) without time zone AS charge_updated_at,
    NULL::uuid AS charge_filter_id,
    NULL::timestamp(6) without time zone AS charge_filter_updated_at,
    NULL::jsonb AS filters,
    NULL::jsonb AS pricing_group_keys,
    NULL::boolean AS pay_in_advance,
    NULL::boolean AS accepts_target_wallet;


--
-- Name: group_properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_properties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    charge_id uuid NOT NULL,
    group_id uuid NOT NULL,
    "values" jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    invoice_display_name character varying
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    billable_metric_id uuid NOT NULL,
    parent_group_id uuid,
    key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone
);


--
-- Name: idempotency_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idempotency_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    idempotency_key bytea NOT NULL,
    resource_id uuid,
    resource_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid
);


--
-- Name: inbound_webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inbound_webhooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source character varying NOT NULL,
    event_type character varying NOT NULL,
    payload jsonb NOT NULL,
    status public.inbound_webhook_status DEFAULT 'pending'::public.inbound_webhook_status NOT NULL,
    organization_id uuid NOT NULL,
    code character varying,
    signature character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    processing_at timestamp without time zone
);


--
-- Name: integration_collection_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_collection_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    integration_id uuid NOT NULL,
    mapping_type integer NOT NULL,
    type character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid
);


--
-- Name: integration_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    integration_id uuid NOT NULL,
    item_type integer NOT NULL,
    external_id character varying NOT NULL,
    external_account_code character varying,
    external_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: integration_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    integration_id uuid NOT NULL,
    mappable_type character varying NOT NULL,
    mappable_id uuid NOT NULL,
    type character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid
);


--
-- Name: integration_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_resources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    syncable_type character varying NOT NULL,
    syncable_id uuid NOT NULL,
    external_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    integration_id uuid,
    resource_type integer DEFAULT 0 NOT NULL,
    organization_id uuid NOT NULL
);


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    type character varying NOT NULL,
    secrets character varying,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    membership_id uuid,
    email character varying NOT NULL,
    token character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    accepted_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    roles character varying[] DEFAULT '{}'::character varying[] NOT NULL
);


--
-- Name: invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description character varying,
    display_name character varying,
    details character varying,
    organization_id uuid NOT NULL,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    section_type public.invoice_custom_section_type DEFAULT 'manual'::public.invoice_custom_section_type NOT NULL
);


--
-- Name: last_hour_events_mv; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.last_hour_events_mv AS
 WITH billable_metric_filters AS (
         SELECT billable_metrics_1.organization_id AS bm_organization_id,
            billable_metrics_1.id AS bm_id,
            billable_metrics_1.code AS bm_code,
            filters.key AS filter_key,
            filters."values" AS filter_values
           FROM (public.billable_metrics billable_metrics_1
             JOIN public.billable_metric_filters filters ON ((filters.billable_metric_id = billable_metrics_1.id)))
          WHERE ((billable_metrics_1.deleted_at IS NULL) AND (filters.deleted_at IS NULL))
        )
 SELECT events.organization_id,
    events.transaction_id,
    events.properties,
    billable_metrics.code AS billable_metric_code,
    (billable_metrics.aggregation_type <> 0) AS field_name_mandatory,
    (billable_metrics.aggregation_type = ANY (ARRAY[1, 2, 5, 6])) AS numeric_field_mandatory,
    (events.properties ->> (billable_metrics.field_name)::text) AS field_value,
    ((events.properties ->> (billable_metrics.field_name)::text) ~ '^-?\d+(\.\d+)?$'::text) AS is_numeric_field_value,
    (events.properties ? (billable_metric_filters.filter_key)::text) AS has_filter_keys,
    ((events.properties ->> (billable_metric_filters.filter_key)::text) = ANY ((billable_metric_filters.filter_values)::text[])) AS has_valid_filter_values
   FROM ((public.events
     LEFT JOIN public.billable_metrics ON ((((billable_metrics.code)::text = (events.code)::text) AND (events.organization_id = billable_metrics.organization_id))))
     LEFT JOIN billable_metric_filters ON ((billable_metrics.id = billable_metric_filters.bm_id)))
  WHERE ((events.deleted_at IS NULL) AND (events.created_at >= (date_trunc('hour'::text, now()) - '01:00:00'::interval)) AND (events.created_at < date_trunc('hour'::text, now())) AND (billable_metrics.deleted_at IS NULL))
  WITH NO DATA;


--
-- Name: lifetime_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifetime_usages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    current_usage_amount_cents bigint DEFAULT 0 NOT NULL,
    invoiced_usage_amount_cents bigint DEFAULT 0 NOT NULL,
    recalculate_current_usage boolean DEFAULT false NOT NULL,
    recalculate_invoiced_usage boolean DEFAULT false NOT NULL,
    current_usage_amount_refreshed_at timestamp without time zone,
    invoiced_usage_amount_refreshed_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    historical_usage_amount_cents bigint DEFAULT 0 NOT NULL
);


--
-- Name: membership_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    role_id uuid NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    revoked_at timestamp(6) without time zone
);


--
-- Name: order_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_forms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    quote_version_id uuid NOT NULL,
    number character varying NOT NULL,
    sequential_id integer NOT NULL,
    status public.order_form_status DEFAULT 'generated'::public.order_form_status NOT NULL,
    void_reason public.order_form_void_reason,
    expires_at timestamp(6) without time zone,
    signed_at timestamp(6) without time zone,
    voided_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT order_forms_constraint_sequential_id_positive CHECK ((sequential_id > 0))
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    order_form_id uuid NOT NULL,
    number character varying NOT NULL,
    sequential_id integer NOT NULL,
    status public.order_status DEFAULT 'created'::public.order_status NOT NULL,
    execution_mode public.order_execution_mode,
    execute_at timestamp(6) without time zone,
    executed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT orders_constraint_sequential_id_positive CHECK ((sequential_id > 0))
);


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_resets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token character varying NOT NULL,
    expire_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: payment_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    payment_url character varying,
    status integer DEFAULT 0 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    provider_session_id character varying
);


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_methods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    payment_provider_id uuid,
    payment_provider_customer_id uuid,
    provider_method_id character varying NOT NULL,
    provider_method_type character varying,
    is_default boolean DEFAULT false NOT NULL,
    deleted_at timestamp(6) without time zone,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: payment_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    type character varying NOT NULL,
    secrets character varying,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    deleted_at timestamp(6) without time zone
);


--
-- Name: payment_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_receipts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    number character varying NOT NULL,
    payment_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    billing_entity_id uuid NOT NULL
);


--
-- Name: pending_vies_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pending_vies_checks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    billing_entity_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    attempts_count integer DEFAULT 0 NOT NULL,
    last_attempt_at timestamp(6) without time zone,
    tax_identification_number character varying,
    last_error_type character varying,
    last_error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: presentation_breakdowns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.presentation_breakdowns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    fee_id uuid NOT NULL,
    presentation_by jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    units numeric DEFAULT 0.0 NOT NULL
);


--
-- Name: pricing_unit_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pricing_unit_usages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    fee_id uuid NOT NULL,
    pricing_unit_id uuid NOT NULL,
    short_name character varying NOT NULL,
    amount_cents bigint NOT NULL,
    precise_amount_cents numeric(40,15) DEFAULT 0.0 NOT NULL,
    unit_amount_cents bigint DEFAULT 0 NOT NULL,
    conversion_rate numeric(40,15) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    precise_unit_amount numeric(30,15) DEFAULT 0.0 NOT NULL
);


--
-- Name: pricing_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pricing_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    short_name character varying NOT NULL,
    description text,
    organization_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: quantified_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quantified_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_subscription_id character varying NOT NULL,
    external_id character varying,
    added_at timestamp(6) without time zone NOT NULL,
    removed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    billable_metric_id uuid,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    deleted_at timestamp(6) without time zone,
    group_id uuid,
    organization_id uuid NOT NULL,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    charge_filter_id uuid
);


--
-- Name: quote_owners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_owners (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    quote_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: quote_owners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quote_owners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quote_owners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quote_owners_id_seq OWNED BY public.quote_owners.id;


--
-- Name: quote_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quote_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_id uuid NOT NULL,
    sequential_id integer NOT NULL,
    status public.quote_status DEFAULT 'draft'::public.quote_status NOT NULL,
    approved_at timestamp(6) without time zone,
    voided_at timestamp(6) without time zone,
    void_reason public.quote_void_reason,
    billing_items jsonb,
    content text,
    share_token character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    currency character varying,
    start_date date,
    end_date date,
    mention_variables jsonb,
    CONSTRAINT quote_versions_constraint_approved_at_matches_status CHECK (((status = 'approved'::public.quote_status) = (approved_at IS NOT NULL))),
    CONSTRAINT quote_versions_constraint_sequential_id_positive CHECK ((sequential_id > 0)),
    CONSTRAINT quote_versions_constraint_void_fields_match_status CHECK (((status = 'voided'::public.quote_status) = ((void_reason IS NOT NULL) AND (voided_at IS NOT NULL))))
);


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    subscription_id uuid,
    number character varying NOT NULL,
    sequential_id integer NOT NULL,
    order_type public.quote_order_type NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT quotes_constraint_sequential_id_positive CHECK ((sequential_id > 0))
);


--
-- Name: recurring_transaction_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_transaction_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_id uuid NOT NULL,
    trigger integer DEFAULT 0 NOT NULL,
    paid_credits numeric(30,5) DEFAULT 0.0 NOT NULL,
    granted_credits numeric(30,5) DEFAULT 0.0 NOT NULL,
    threshold_credits numeric(30,5) DEFAULT 0.0,
    "interval" integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    method integer DEFAULT 0 NOT NULL,
    target_ongoing_balance numeric(30,5),
    started_at timestamp(6) without time zone,
    invoice_requires_successful_payment boolean DEFAULT false NOT NULL,
    transaction_metadata jsonb DEFAULT '[]'::jsonb,
    expiration_at timestamp(6) without time zone,
    terminated_at timestamp(6) without time zone,
    status integer DEFAULT 0,
    organization_id uuid NOT NULL,
    ignore_paid_top_up_limits boolean DEFAULT false NOT NULL,
    transaction_name character varying(255),
    payment_method_id uuid,
    payment_method_type public.payment_method_types DEFAULT 'provider'::public.payment_method_types NOT NULL,
    skip_invoice_custom_sections boolean DEFAULT false NOT NULL,
    grants_target_top_up boolean
);


--
-- Name: recurring_transaction_rules_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_transaction_rules_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    recurring_transaction_rule_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: refunds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refunds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    payment_id uuid NOT NULL,
    credit_note_id uuid,
    payment_provider_id uuid,
    payment_provider_customer_id uuid NOT NULL,
    amount_cents bigint DEFAULT 0 NOT NULL,
    amount_currency character varying NOT NULL,
    status character varying NOT NULL,
    provider_refund_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id uuid NOT NULL,
    refundable_type character varying,
    refundable_id uuid,
    reason character varying,
    CONSTRAINT refunds_credit_note_or_refundable_present CHECK (((credit_note_id IS NOT NULL) OR ((refundable_type IS NOT NULL) AND (refundable_id IS NOT NULL))))
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    code character varying NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    permissions character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    name character varying NOT NULL,
    description character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    CONSTRAINT code_is_valid CHECK (((code)::text ~ '^[a-z0-9_]{1,100}$'::text)),
    CONSTRAINT custom_role_should_have_permissions CHECK (((organization_id IS NULL) OR (cardinality(permissions) > 0))),
    CONSTRAINT description_max_length CHECK ((length((description)::text) <= 255)),
    CONSTRAINT name_is_valid CHECK (((name)::text ~ '^.{1,100}$'::text)),
    CONSTRAINT permissions_has_no_empty_parts CHECK (((NOT ((permissions)::text ~ '([\{,]:|::|:[,\}])'::text)) AND (NOT (''::text = ANY ((permissions)::text[]))))),
    CONSTRAINT predefined_role_cannot_have_permissions CHECK (((organization_id IS NOT NULL) OR (cardinality(permissions) = 0)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: subscription_activation_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_activation_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    type public.subscription_activation_rule_types NOT NULL,
    timeout_hours integer DEFAULT 0 NOT NULL,
    status public.subscription_activation_rule_statuses DEFAULT 'inactive'::public.subscription_activation_rule_statuses NOT NULL,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: subscription_fixed_charge_units_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_fixed_charge_units_overrides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    fixed_charge_id uuid NOT NULL,
    units numeric(30,10) DEFAULT 0.0 NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT sub_fc_units_overrides_units_non_negative CHECK ((units >= (0)::numeric))
);


--
-- Name: subscriptions_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: usage_monitoring_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_monitoring_alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    subscription_external_id character varying,
    billable_metric_id uuid,
    alert_type public.usage_monitoring_alert_types NOT NULL,
    previous_value numeric(30,5) DEFAULT 0.0 NOT NULL,
    last_processed_at timestamp(6) without time zone,
    name character varying,
    code character varying NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    wallet_id uuid,
    direction public.usage_monitoring_alert_direction DEFAULT 'increasing'::public.usage_monitoring_alert_direction NOT NULL,
    CONSTRAINT chk_alerts_subscription_xor_wallet CHECK (((subscription_external_id IS NOT NULL) <> (wallet_id IS NOT NULL)))
);


--
-- Name: usage_monitoring_subscription_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_monitoring_subscription_activities (
    id bigint NOT NULL,
    organization_id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    enqueued boolean DEFAULT false NOT NULL,
    inserted_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    enqueued_at timestamp(6) without time zone
);


--
-- Name: usage_monitoring_subscription_activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_monitoring_subscription_activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_monitoring_subscription_activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_monitoring_subscription_activities_id_seq OWNED BY public.usage_monitoring_subscription_activities.id;


--
-- Name: user_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    fingerprint character varying NOT NULL,
    browser character varying,
    os character varying,
    device_type character varying,
    last_logged_at timestamp(6) without time zone NOT NULL,
    last_ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying,
    password_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_id character varying NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object jsonb,
    object_changes jsonb,
    created_at timestamp(6) without time zone,
    lago_version character varying
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: wallet_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    wallet_id uuid NOT NULL,
    billable_metric_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: wallet_transactions_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_transactions_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    wallet_transaction_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: wallets_invoice_custom_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallets_invoice_custom_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    wallet_id uuid NOT NULL,
    invoice_custom_section_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: webhook_endpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_endpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    webhook_url character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    signature_algo integer DEFAULT 0 NOT NULL,
    event_types character varying[],
    name character varying
);


--
-- Name: webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_id uuid,
    object_type character varying,
    status integer DEFAULT 0 NOT NULL,
    retries integer DEFAULT 0 NOT NULL,
    http_status integer,
    endpoint character varying,
    webhook_type character varying,
    payload json,
    response json,
    last_retried_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    webhook_endpoint_id uuid,
    organization_id uuid NOT NULL,
    payload_key character varying,
    response_key character varying
);


--
-- Name: enriched_events_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_events ATTACH PARTITION public.enriched_events_default DEFAULT;


--
-- Name: quote_owners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_owners ALTER COLUMN id SET DEFAULT nextval('public.quote_owners_id_seq'::regclass);


--
-- Name: usage_monitoring_subscription_activities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_subscription_activities ALTER COLUMN id SET DEFAULT nextval('public.usage_monitoring_subscription_activities_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: add_ons add_ons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons
    ADD CONSTRAINT add_ons_pkey PRIMARY KEY (id);


--
-- Name: add_ons_taxes add_ons_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons_taxes
    ADD CONSTRAINT add_ons_taxes_pkey PRIMARY KEY (id);


--
-- Name: adjusted_fees adjusted_fees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT adjusted_fees_pkey PRIMARY KEY (id);


--
-- Name: ai_conversations ai_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: applied_add_ons applied_add_ons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_add_ons
    ADD CONSTRAINT applied_add_ons_pkey PRIMARY KEY (id);


--
-- Name: applied_coupons applied_coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_coupons
    ADD CONSTRAINT applied_coupons_pkey PRIMARY KEY (id);


--
-- Name: applied_invoice_custom_sections applied_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_invoice_custom_sections
    ADD CONSTRAINT applied_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: applied_pricing_units applied_pricing_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_pricing_units
    ADD CONSTRAINT applied_pricing_units_pkey PRIMARY KEY (id);


--
-- Name: applied_usage_thresholds applied_usage_thresholds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_usage_thresholds
    ADD CONSTRAINT applied_usage_thresholds_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: billable_metric_filters billable_metric_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billable_metric_filters
    ADD CONSTRAINT billable_metric_filters_pkey PRIMARY KEY (id);


--
-- Name: billable_metrics billable_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billable_metrics
    ADD CONSTRAINT billable_metrics_pkey PRIMARY KEY (id);


--
-- Name: billing_entities_invoice_custom_sections billing_entities_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_invoice_custom_sections
    ADD CONSTRAINT billing_entities_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: billing_entities billing_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities
    ADD CONSTRAINT billing_entities_pkey PRIMARY KEY (id);


--
-- Name: billing_entities_taxes billing_entities_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_taxes
    ADD CONSTRAINT billing_entities_taxes_pkey PRIMARY KEY (id);


--
-- Name: cached_aggregations cached_aggregations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cached_aggregations
    ADD CONSTRAINT cached_aggregations_pkey PRIMARY KEY (id);


--
-- Name: charge_filter_values charge_filter_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filter_values
    ADD CONSTRAINT charge_filter_values_pkey PRIMARY KEY (id);


--
-- Name: charge_filters charge_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filters
    ADD CONSTRAINT charge_filters_pkey PRIMARY KEY (id);


--
-- Name: charges charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (id);


--
-- Name: charges_taxes charges_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges_taxes
    ADD CONSTRAINT charges_taxes_pkey PRIMARY KEY (id);


--
-- Name: commitments commitments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments
    ADD CONSTRAINT commitments_pkey PRIMARY KEY (id);


--
-- Name: commitments_taxes commitments_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments_taxes
    ADD CONSTRAINT commitments_taxes_pkey PRIMARY KEY (id);


--
-- Name: coupon_targets coupon_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_targets
    ADD CONSTRAINT coupon_targets_pkey PRIMARY KEY (id);


--
-- Name: coupons coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (id);


--
-- Name: credit_note_items credit_note_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_items
    ADD CONSTRAINT credit_note_items_pkey PRIMARY KEY (id);


--
-- Name: credit_notes credit_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT credit_notes_pkey PRIMARY KEY (id);


--
-- Name: credit_notes_taxes credit_notes_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes_taxes
    ADD CONSTRAINT credit_notes_taxes_pkey PRIMARY KEY (id);


--
-- Name: credits credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT credits_pkey PRIMARY KEY (id);


--
-- Name: customer_metadata customer_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_metadata
    ADD CONSTRAINT customer_metadata_pkey PRIMARY KEY (id);


--
-- Name: customers_invoice_custom_sections customers_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_invoice_custom_sections
    ADD CONSTRAINT customers_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: customers_taxes customers_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_taxes
    ADD CONSTRAINT customers_taxes_pkey PRIMARY KEY (id);


--
-- Name: daily_usages daily_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_usages
    ADD CONSTRAINT daily_usages_pkey PRIMARY KEY (id);


--
-- Name: data_export_parts data_export_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_parts
    ADD CONSTRAINT data_export_parts_pkey PRIMARY KEY (id);


--
-- Name: data_exports data_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_exports
    ADD CONSTRAINT data_exports_pkey PRIMARY KEY (id);


--
-- Name: dunning_campaign_thresholds dunning_campaign_thresholds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dunning_campaign_thresholds
    ADD CONSTRAINT dunning_campaign_thresholds_pkey PRIMARY KEY (id);


--
-- Name: dunning_campaigns dunning_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dunning_campaigns
    ADD CONSTRAINT dunning_campaigns_pkey PRIMARY KEY (id);


--
-- Name: enriched_store_migrations enriched_store_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_migrations
    ADD CONSTRAINT enriched_store_migrations_pkey PRIMARY KEY (id);


--
-- Name: enriched_store_subscription_migrations enriched_store_subscription_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_subscription_migrations
    ADD CONSTRAINT enriched_store_subscription_migrations_pkey PRIMARY KEY (id);


--
-- Name: entitlement_entitlement_values entitlement_entitlement_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlement_values
    ADD CONSTRAINT entitlement_entitlement_values_pkey PRIMARY KEY (id);


--
-- Name: entitlement_entitlements entitlement_entitlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlements
    ADD CONSTRAINT entitlement_entitlements_pkey PRIMARY KEY (id);


--
-- Name: entitlement_features entitlement_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_features
    ADD CONSTRAINT entitlement_features_pkey PRIMARY KEY (id);


--
-- Name: entitlement_privileges entitlement_privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_privileges
    ADD CONSTRAINT entitlement_privileges_pkey PRIMARY KEY (id);


--
-- Name: entitlement_subscription_feature_removals entitlement_subscription_feature_removals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_feature_removals
    ADD CONSTRAINT entitlement_subscription_feature_removals_pkey PRIMARY KEY (id);


--
-- Name: error_details error_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_details
    ADD CONSTRAINT error_details_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: fees fees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fees_pkey PRIMARY KEY (id);


--
-- Name: fees_taxes fees_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees_taxes
    ADD CONSTRAINT fees_taxes_pkey PRIMARY KEY (id);


--
-- Name: fixed_charge_events fixed_charge_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charge_events
    ADD CONSTRAINT fixed_charge_events_pkey PRIMARY KEY (id);


--
-- Name: fixed_charges fixed_charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges
    ADD CONSTRAINT fixed_charges_pkey PRIMARY KEY (id);


--
-- Name: fixed_charges_taxes fixed_charges_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges_taxes
    ADD CONSTRAINT fixed_charges_taxes_pkey PRIMARY KEY (id);


--
-- Name: group_properties group_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_properties
    ADD CONSTRAINT group_properties_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: idempotency_records idempotency_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_records
    ADD CONSTRAINT idempotency_records_pkey PRIMARY KEY (id);


--
-- Name: inbound_webhooks inbound_webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbound_webhooks
    ADD CONSTRAINT inbound_webhooks_pkey PRIMARY KEY (id);


--
-- Name: integration_collection_mappings integration_collection_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_collection_mappings
    ADD CONSTRAINT integration_collection_mappings_pkey PRIMARY KEY (id);


--
-- Name: integration_customers integration_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_customers
    ADD CONSTRAINT integration_customers_pkey PRIMARY KEY (id);


--
-- Name: integration_items integration_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_items
    ADD CONSTRAINT integration_items_pkey PRIMARY KEY (id);


--
-- Name: integration_mappings integration_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_mappings
    ADD CONSTRAINT integration_mappings_pkey PRIMARY KEY (id);


--
-- Name: integration_resources integration_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_resources
    ADD CONSTRAINT integration_resources_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: invoice_custom_sections invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_custom_sections
    ADD CONSTRAINT invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: invoice_metadata invoice_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_metadata
    ADD CONSTRAINT invoice_metadata_pkey PRIMARY KEY (id);


--
-- Name: invoice_settlements invoice_settlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT invoice_settlements_pkey PRIMARY KEY (id);


--
-- Name: invoice_subscriptions invoice_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_subscriptions
    ADD CONSTRAINT invoice_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: invoices_payment_requests invoices_payment_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_payment_requests
    ADD CONSTRAINT invoices_payment_requests_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: invoices_taxes invoices_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_taxes
    ADD CONSTRAINT invoices_taxes_pkey PRIMARY KEY (id);


--
-- Name: item_metadata item_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_metadata
    ADD CONSTRAINT item_metadata_pkey PRIMARY KEY (id);


--
-- Name: lifetime_usages lifetime_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifetime_usages
    ADD CONSTRAINT lifetime_usages_pkey PRIMARY KEY (id);


--
-- Name: membership_roles membership_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_roles
    ADD CONSTRAINT membership_roles_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: order_forms order_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_forms
    ADD CONSTRAINT order_forms_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: payment_intents payment_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_intents
    ADD CONSTRAINT payment_intents_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_provider_customers payment_provider_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_provider_customers
    ADD CONSTRAINT payment_provider_customers_pkey PRIMARY KEY (id);


--
-- Name: payment_providers payment_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_providers
    ADD CONSTRAINT payment_providers_pkey PRIMARY KEY (id);


--
-- Name: payment_receipts payment_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receipts
    ADD CONSTRAINT payment_receipts_pkey PRIMARY KEY (id);


--
-- Name: payment_requests payment_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_requests
    ADD CONSTRAINT payment_requests_pkey PRIMARY KEY (id);


--
-- Name: payments payments_customer_id_null; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.payments
    ADD CONSTRAINT payments_customer_id_null CHECK ((customer_id IS NOT NULL)) NOT VALID;


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: pending_vies_checks pending_vies_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_vies_checks
    ADD CONSTRAINT pending_vies_checks_pkey PRIMARY KEY (id);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: plans_taxes plans_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans_taxes
    ADD CONSTRAINT plans_taxes_pkey PRIMARY KEY (id);


--
-- Name: presentation_breakdowns presentation_breakdowns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presentation_breakdowns
    ADD CONSTRAINT presentation_breakdowns_pkey PRIMARY KEY (id);


--
-- Name: pricing_unit_usages pricing_unit_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_unit_usages
    ADD CONSTRAINT pricing_unit_usages_pkey PRIMARY KEY (id);


--
-- Name: pricing_units pricing_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_units
    ADD CONSTRAINT pricing_units_pkey PRIMARY KEY (id);


--
-- Name: quantified_events quantified_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quantified_events
    ADD CONSTRAINT quantified_events_pkey PRIMARY KEY (id);


--
-- Name: quote_owners quote_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_owners
    ADD CONSTRAINT quote_owners_pkey PRIMARY KEY (id);


--
-- Name: quote_versions quote_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_versions
    ADD CONSTRAINT quote_versions_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);


--
-- Name: recurring_transaction_rules_invoice_custom_sections recurring_transaction_rules_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules_invoice_custom_sections
    ADD CONSTRAINT recurring_transaction_rules_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: recurring_transaction_rules recurring_transaction_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules
    ADD CONSTRAINT recurring_transaction_rules_pkey PRIMARY KEY (id);


--
-- Name: refunds refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT refunds_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: subscription_activation_rules subscription_activation_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_activation_rules
    ADD CONSTRAINT subscription_activation_rules_pkey PRIMARY KEY (id);


--
-- Name: subscription_fixed_charge_units_overrides subscription_fixed_charge_units_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_fixed_charge_units_overrides
    ADD CONSTRAINT subscription_fixed_charge_units_overrides_pkey PRIMARY KEY (id);


--
-- Name: subscriptions_invoice_custom_sections subscriptions_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions_invoice_custom_sections
    ADD CONSTRAINT subscriptions_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: taxes taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxes
    ADD CONSTRAINT taxes_pkey PRIMARY KEY (id);


--
-- Name: usage_monitoring_alert_thresholds usage_monitoring_alert_thresholds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alert_thresholds
    ADD CONSTRAINT usage_monitoring_alert_thresholds_pkey PRIMARY KEY (id);


--
-- Name: usage_monitoring_alerts usage_monitoring_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alerts
    ADD CONSTRAINT usage_monitoring_alerts_pkey PRIMARY KEY (id);


--
-- Name: usage_monitoring_subscription_activities usage_monitoring_subscription_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_subscription_activities
    ADD CONSTRAINT usage_monitoring_subscription_activities_pkey PRIMARY KEY (id);


--
-- Name: usage_monitoring_triggered_alerts usage_monitoring_triggered_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_triggered_alerts
    ADD CONSTRAINT usage_monitoring_triggered_alerts_pkey PRIMARY KEY (id);


--
-- Name: usage_thresholds usage_thresholds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_thresholds
    ADD CONSTRAINT usage_thresholds_pkey PRIMARY KEY (id);


--
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: wallet_targets wallet_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_targets
    ADD CONSTRAINT wallet_targets_pkey PRIMARY KEY (id);


--
-- Name: wallet_transaction_consumptions wallet_transaction_consumptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction_consumptions
    ADD CONSTRAINT wallet_transaction_consumptions_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions_invoice_custom_sections wallet_transactions_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions_invoice_custom_sections
    ADD CONSTRAINT wallet_transactions_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: wallets_invoice_custom_sections wallets_invoice_custom_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets_invoice_custom_sections
    ADD CONSTRAINT wallets_invoice_custom_sections_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_pkey PRIMARY KEY (id);


--
-- Name: webhook_endpoints webhook_endpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT webhook_endpoints_pkey PRIMARY KEY (id);


--
-- Name: webhooks webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT webhooks_pkey PRIMARY KEY (id);


--
-- Name: index_enriched_events_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enriched_events_on_event_id ON ONLY public.enriched_events USING btree (event_id);


--
-- Name: enriched_events_default_event_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX enriched_events_default_event_id_idx ON public.enriched_events_default USING btree (event_id);


--
-- Name: idx_unique_on_enriched_events; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_on_enriched_events ON ONLY public.enriched_events USING btree (organization_id, external_subscription_id, transaction_id, "timestamp", charge_id);


--
-- Name: enriched_events_default_organization_id_external_subscript_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX enriched_events_default_organization_id_external_subscript_idx1 ON public.enriched_events_default USING btree (organization_id, external_subscription_id, transaction_id, "timestamp", charge_id);


--
-- Name: idx_lookup_on_enriched_events; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lookup_on_enriched_events ON ONLY public.enriched_events USING btree (organization_id, external_subscription_id, code, "timestamp");


--
-- Name: enriched_events_default_organization_id_external_subscripti_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX enriched_events_default_organization_id_external_subscripti_idx ON public.enriched_events_default USING btree (organization_id, external_subscription_id, code, "timestamp");


--
-- Name: idx_billing_on_enriched_events; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_on_enriched_events ON ONLY public.enriched_events USING btree (organization_id, subscription_id, charge_id, charge_filter_id, "timestamp");


--
-- Name: enriched_events_default_organization_id_subscription_id_cha_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX enriched_events_default_organization_id_subscription_id_cha_idx ON public.enriched_events_default USING btree (organization_id, subscription_id, charge_id, charge_filter_id, "timestamp");


--
-- Name: idx_aggregation_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aggregation_lookup ON public.cached_aggregations USING btree (external_subscription_id, charge_id, "timestamp") INCLUDE (organization_id, grouped_by);


--
-- Name: idx_alerts_code_unique_per_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alerts_code_unique_per_subscription ON public.usage_monitoring_alerts USING btree (code, subscription_external_id, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_alerts_unique_per_type_per_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alerts_unique_per_type_per_subscription ON public.usage_monitoring_alerts USING btree (subscription_external_id, organization_id, alert_type) WHERE ((billable_metric_id IS NULL) AND (deleted_at IS NULL));


--
-- Name: idx_alerts_unique_per_type_per_subscription_with_bm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alerts_unique_per_type_per_subscription_with_bm ON public.usage_monitoring_alerts USING btree (subscription_external_id, organization_id, alert_type, billable_metric_id) WHERE ((billable_metric_id IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: idx_alerts_unique_per_type_per_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alerts_unique_per_type_per_wallet ON public.usage_monitoring_alerts USING btree (wallet_id, organization_id, alert_type) WHERE ((billable_metric_id IS NULL) AND (deleted_at IS NULL));


--
-- Name: idx_billable_metrics_id_agg_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billable_metrics_id_agg_type ON public.billable_metrics USING btree (id) INCLUDE (aggregation_type);


--
-- Name: idx_cached_aggregation_filtered_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cached_aggregation_filtered_lookup ON public.cached_aggregations USING btree (organization_id, external_subscription_id, charge_id, "timestamp" DESC, created_at DESC) INCLUDE (grouped_by, charge_filter_id, event_transaction_id);


--
-- Name: idx_enqueued_per_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enqueued_per_organization ON public.usage_monitoring_subscription_activities USING btree (organization_id, enqueued);


--
-- Name: idx_enriched_store_sub_migrations_on_migration_and_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_enriched_store_sub_migrations_on_migration_and_subscription ON public.enriched_store_subscription_migrations USING btree (enriched_store_migration_id, subscription_id);


--
-- Name: idx_events_billing_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_billing_lookup ON public.events USING btree (external_subscription_id, organization_id, code, "timestamp") INCLUDE (properties) WHERE (deleted_at IS NULL);


--
-- Name: idx_events_for_distinct_codes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_for_distinct_codes ON public.events USING btree (external_subscription_id, organization_id, "timestamp") INCLUDE (code) WHERE (deleted_at IS NULL);


--
-- Name: idx_features_code_unique_per_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_features_code_unique_per_organization ON public.entitlement_features USING btree (code, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_invoice_subscriptions_on_subscription_with_timestamps; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_subscriptions_on_subscription_with_timestamps ON public.invoice_subscriptions USING btree (subscription_id, COALESCE(to_datetime, created_at) DESC);


--
-- Name: idx_invoices_organization_id_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoices_organization_id_status ON public.invoices USING btree (organization_id, status);


--
-- Name: idx_on_billing_entity_id_724373e5ae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_billing_entity_id_724373e5ae ON public.billing_entities_invoice_custom_sections USING btree (billing_entity_id);


--
-- Name: idx_on_billing_entity_id_billing_entity_sequential__bd26b2e655; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_billing_entity_id_billing_entity_sequential__bd26b2e655 ON public.invoices USING btree (billing_entity_id, billing_entity_sequential_id DESC) INCLUDE (self_billed);


--
-- Name: idx_on_billing_entity_id_customer_id_invoice_custom_e7aada65cb; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_billing_entity_id_customer_id_invoice_custom_e7aada65cb ON public.customers_invoice_custom_sections USING btree (billing_entity_id, customer_id, invoice_custom_section_id);


--
-- Name: idx_on_billing_entity_id_invoice_custom_section_id_bd78c547d3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_billing_entity_id_invoice_custom_section_id_bd78c547d3 ON public.billing_entities_invoice_custom_sections USING btree (billing_entity_id, invoice_custom_section_id);


--
-- Name: idx_on_dunning_campaign_id_currency_fbf233b2ae; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_dunning_campaign_id_currency_fbf233b2ae ON public.dunning_campaign_thresholds USING btree (dunning_campaign_id, currency) WHERE (deleted_at IS NULL);


--
-- Name: idx_on_enriched_store_migration_id_e409c5dc43; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_enriched_store_migration_id_e409c5dc43 ON public.enriched_store_subscription_migrations USING btree (enriched_store_migration_id);


--
-- Name: idx_on_entitlement_entitlement_id_48c0b3356a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entitlement_entitlement_id_48c0b3356a ON public.entitlement_entitlement_values USING btree (entitlement_entitlement_id);


--
-- Name: idx_on_entitlement_feature_id_821ae72311; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entitlement_feature_id_821ae72311 ON public.entitlement_subscription_feature_removals USING btree (entitlement_feature_id);


--
-- Name: idx_on_entitlement_privilege_id_6a228dc433; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entitlement_privilege_id_6a228dc433 ON public.entitlement_entitlement_values USING btree (entitlement_privilege_id);


--
-- Name: idx_on_entitlement_privilege_id_9946ccf514; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_entitlement_privilege_id_9946ccf514 ON public.entitlement_subscription_feature_removals USING btree (entitlement_privilege_id);


--
-- Name: idx_on_entitlement_privilege_id_entitlement_entitle_9d0542eb1a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_entitlement_privilege_id_entitlement_entitle_9d0542eb1a ON public.entitlement_entitlement_values USING btree (entitlement_privilege_id, entitlement_entitlement_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_on_fixed_charge_id_06503ae1a5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_fixed_charge_id_06503ae1a5 ON public.subscription_fixed_charge_units_overrides USING btree (fixed_charge_id);


--
-- Name: idx_on_inbound_wallet_transaction_id_e54d00758d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_inbound_wallet_transaction_id_e54d00758d ON public.wallet_transaction_consumptions USING btree (inbound_wallet_transaction_id);


--
-- Name: idx_on_invoice_custom_section_id_50c2a2e7c0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_50c2a2e7c0 ON public.recurring_transaction_rules_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_custom_section_id_5f37496c8c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_5f37496c8c ON public.customers_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_custom_section_id_aca4661c33; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_aca4661c33 ON public.wallets_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_custom_section_id_b381df5bb5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_b381df5bb5 ON public.wallet_transactions_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_custom_section_id_ccb39e9622; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_ccb39e9622 ON public.billing_entities_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_custom_section_id_d8b9068730; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_invoice_custom_section_id_d8b9068730 ON public.subscriptions_invoice_custom_sections USING btree (invoice_custom_section_id);


--
-- Name: idx_on_invoice_id_payment_request_id_aa550779a4; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_invoice_id_payment_request_id_aa550779a4 ON public.invoices_payment_requests USING btree (invoice_id, payment_request_id);


--
-- Name: idx_on_organization_id_2be2ef98ea; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_2be2ef98ea ON public.enriched_store_subscription_migrations USING btree (organization_id);


--
-- Name: idx_on_organization_id_376a587b04; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_376a587b04 ON public.usage_monitoring_subscription_activities USING btree (organization_id);


--
-- Name: idx_on_organization_id_7020c3c43a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_7020c3c43a ON public.entitlement_subscription_feature_removals USING btree (organization_id);


--
-- Name: idx_on_organization_id_83703a45f4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_83703a45f4 ON public.billing_entities_invoice_custom_sections USING btree (organization_id);


--
-- Name: idx_on_organization_id_ccdf05cbfe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_ccdf05cbfe ON public.wallet_transactions_invoice_custom_sections USING btree (organization_id);


--
-- Name: idx_on_organization_id_deleted_at_225e3f789d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_deleted_at_225e3f789d ON public.invoice_custom_sections USING btree (organization_id, deleted_at);


--
-- Name: idx_on_organization_id_e73219f079; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_e73219f079 ON public.recurring_transaction_rules_invoice_custom_sections USING btree (organization_id);


--
-- Name: idx_on_organization_id_e742f77454; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_e742f77454 ON public.subscription_fixed_charge_units_overrides USING btree (organization_id);


--
-- Name: idx_on_organization_id_external_id_gin_trgm_ops_fb8058a497; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_external_id_gin_trgm_ops_fb8058a497 ON public.subscriptions USING gin (organization_id, external_id public.gin_trgm_ops);


--
-- Name: idx_on_organization_id_external_subscription_id_df3a30d96d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_external_subscription_id_df3a30d96d ON public.daily_usages USING btree (organization_id, external_subscription_id);


--
-- Name: idx_on_organization_id_organization_sequential_id_2387146f54; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_organization_sequential_id_2387146f54 ON public.invoices USING btree (organization_id, organization_sequential_id DESC) INCLUDE (self_billed);


--
-- Name: idx_on_organization_id_provider_payment_id_gin_trgm_2bcf073c0b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_provider_payment_id_gin_trgm_2bcf073c0b ON public.payments USING gin (organization_id, provider_payment_id public.gin_trgm_ops);


--
-- Name: idx_on_organization_id_subscription_at_created_at_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_subscription_at_created_at_id ON public.subscriptions USING btree (organization_id, subscription_at DESC NULLS LAST, created_at DESC, id);


--
-- Name: idx_on_outbound_wallet_transaction_id_cf6ff733c6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_outbound_wallet_transaction_id_cf6ff733c6 ON public.wallet_transaction_consumptions USING btree (outbound_wallet_transaction_id);


--
-- Name: idx_on_plan_id_billable_metric_id_pay_in_advance_4a205974cb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_plan_id_billable_metric_id_pay_in_advance_4a205974cb ON public.charges USING btree (plan_id, billable_metric_id, pay_in_advance) WHERE (deleted_at IS NULL);


--
-- Name: idx_on_recurring_transaction_rule_id_fba3d39cca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_recurring_transaction_rule_id_fba3d39cca ON public.recurring_transaction_rules_invoice_custom_sections USING btree (recurring_transaction_rule_id);


--
-- Name: idx_on_subscription_id_295edd8bb3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subscription_id_295edd8bb3 ON public.entitlement_subscription_feature_removals USING btree (subscription_id);


--
-- Name: idx_on_subscription_id_b41afd08e0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subscription_id_b41afd08e0 ON public.enriched_store_subscription_migrations USING btree (subscription_id);


--
-- Name: idx_on_subscription_id_bd763c5aa3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_subscription_id_bd763c5aa3 ON public.subscription_fixed_charge_units_overrides USING btree (subscription_id);


--
-- Name: idx_on_subscription_id_type_8feb7b9623; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_subscription_id_type_8feb7b9623 ON public.subscription_activation_rules USING btree (subscription_id, type);


--
-- Name: idx_on_usage_monitoring_alert_id_4290c95dec; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_usage_monitoring_alert_id_4290c95dec ON public.usage_monitoring_triggered_alerts USING btree (usage_monitoring_alert_id);


--
-- Name: idx_on_usage_monitoring_alert_id_78eb24d06c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_usage_monitoring_alert_id_78eb24d06c ON public.usage_monitoring_alert_thresholds USING btree (usage_monitoring_alert_id);


--
-- Name: idx_on_usage_monitoring_alert_id_recurring_756a2a370d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_usage_monitoring_alert_id_recurring_756a2a370d ON public.usage_monitoring_alert_thresholds USING btree (usage_monitoring_alert_id, recurring) WHERE (recurring IS TRUE);


--
-- Name: idx_on_usage_threshold_id_invoice_id_cb82cdf163; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_usage_threshold_id_invoice_id_cb82cdf163 ON public.applied_usage_thresholds USING btree (usage_threshold_id, invoice_id);


--
-- Name: idx_on_wallet_transaction_id_ac2826109e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_wallet_transaction_id_ac2826109e ON public.wallet_transactions_invoice_custom_sections USING btree (wallet_transaction_id);


--
-- Name: idx_pay_in_advance_duplication_guard_charge; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pay_in_advance_duplication_guard_charge ON public.fees USING btree (pay_in_advance_event_transaction_id, charge_id) WHERE ((deleted_at IS NULL) AND (charge_filter_id IS NULL) AND (pay_in_advance_event_transaction_id IS NOT NULL) AND (pay_in_advance = true) AND (duplicated_in_advance = false) AND (original_fee_id IS NULL));


--
-- Name: idx_pay_in_advance_duplication_guard_charge_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pay_in_advance_duplication_guard_charge_filter ON public.fees USING btree (pay_in_advance_event_transaction_id, charge_id, charge_filter_id) WHERE ((deleted_at IS NULL) AND (charge_filter_id IS NOT NULL) AND (pay_in_advance_event_transaction_id IS NOT NULL) AND (pay_in_advance = true) AND (duplicated_in_advance = false) AND (original_fee_id IS NULL));


--
-- Name: idx_privileges_code_unique_per_feature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_privileges_code_unique_per_feature ON public.entitlement_privileges USING btree (code, entitlement_feature_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_subscription_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_subscription_unique ON public.usage_monitoring_subscription_activities USING btree (subscription_id);


--
-- Name: idx_unique_feature_per_plan; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_feature_per_plan ON public.entitlement_entitlements USING btree (entitlement_feature_id, plan_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_feature_per_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_feature_per_subscription ON public.entitlement_entitlements USING btree (entitlement_feature_id, subscription_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_feature_removal_per_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_feature_removal_per_subscription ON public.entitlement_subscription_feature_removals USING btree (subscription_id, entitlement_feature_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_privilege_removal_per_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_privilege_removal_per_subscription ON public.entitlement_subscription_feature_removals USING btree (subscription_id, entitlement_privilege_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_tax_code_per_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_tax_code_per_organization ON public.taxes USING btree (code, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_usage_thresholds_on_amount_plan_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_usage_thresholds_on_amount_plan_recurring ON public.usage_thresholds USING btree (amount_cents, plan_id, recurring) WHERE ((deleted_at IS NULL) AND (plan_id IS NOT NULL));


--
-- Name: idx_usage_thresholds_on_amount_subscription_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_usage_thresholds_on_amount_subscription_recurring ON public.usage_thresholds USING btree (amount_cents, subscription_id, recurring) WHERE ((deleted_at IS NULL) AND (subscription_id IS NOT NULL));


--
-- Name: idx_usage_thresholds_plan_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_usage_thresholds_plan_recurring ON public.usage_thresholds USING btree (plan_id, recurring) WHERE ((recurring IS TRUE) AND (deleted_at IS NULL) AND (plan_id IS NOT NULL));


--
-- Name: idx_usage_thresholds_subscription_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_usage_thresholds_subscription_recurring ON public.usage_thresholds USING btree (subscription_id, recurring) WHERE ((recurring IS TRUE) AND (deleted_at IS NULL) AND (subscription_id IS NOT NULL));


--
-- Name: idx_wallet_transactions_available_inbound; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_transactions_available_inbound ON public.wallet_transactions USING btree (wallet_id, priority, (
CASE
    WHEN (transaction_status = 1) THEN 0
    ELSE 1
END), created_at) WHERE ((remaining_amount_cents > 0) AND (transaction_type = 0) AND (status = 1));


--
-- Name: idx_wallet_tx_consumptions_inbound_outbound; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_wallet_tx_consumptions_inbound_outbound ON public.wallet_transaction_consumptions USING btree (inbound_wallet_transaction_id, outbound_wallet_transaction_id);


--
-- Name: index_activation_rules_pending_with_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activation_rules_pending_with_expiry ON public.subscription_activation_rules USING btree (status, expires_at) WHERE ((status = 'pending'::public.subscription_activation_rule_statuses) AND (expires_at IS NOT NULL));


--
-- Name: index_active_charge_filter_values; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_charge_filter_values ON public.charge_filter_values USING btree (charge_filter_id) WHERE (deleted_at IS NULL);


--
-- Name: index_active_charge_filters; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_charge_filters ON public.charge_filters USING btree (charge_id) WHERE (deleted_at IS NULL);


--
-- Name: index_active_metric_filters; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_metric_filters ON public.billable_metric_filters USING btree (billable_metric_id) WHERE (deleted_at IS NULL);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_add_ons_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_add_ons_on_deleted_at ON public.add_ons USING btree (deleted_at);


--
-- Name: index_add_ons_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_add_ons_on_organization_id ON public.add_ons USING btree (organization_id);


--
-- Name: index_add_ons_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_add_ons_on_organization_id_and_code ON public.add_ons USING btree (organization_id, code) WHERE (deleted_at IS NULL);


--
-- Name: index_add_ons_taxes_on_add_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_add_ons_taxes_on_add_on_id ON public.add_ons_taxes USING btree (add_on_id);


--
-- Name: index_add_ons_taxes_on_add_on_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_add_ons_taxes_on_add_on_id_and_tax_id ON public.add_ons_taxes USING btree (add_on_id, tax_id);


--
-- Name: index_add_ons_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_add_ons_taxes_on_organization_id ON public.add_ons_taxes USING btree (organization_id);


--
-- Name: index_add_ons_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_add_ons_taxes_on_tax_id ON public.add_ons_taxes USING btree (tax_id);


--
-- Name: index_adjusted_fees_on_charge_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_charge_filter_id ON public.adjusted_fees USING btree (charge_filter_id);


--
-- Name: index_adjusted_fees_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_charge_id ON public.adjusted_fees USING btree (charge_id);


--
-- Name: index_adjusted_fees_on_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_fee_id ON public.adjusted_fees USING btree (fee_id);


--
-- Name: index_adjusted_fees_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_group_id ON public.adjusted_fees USING btree (group_id);


--
-- Name: index_adjusted_fees_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_invoice_id ON public.adjusted_fees USING btree (invoice_id);


--
-- Name: index_adjusted_fees_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_organization_id ON public.adjusted_fees USING btree (organization_id);


--
-- Name: index_adjusted_fees_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjusted_fees_on_subscription_id ON public.adjusted_fees USING btree (subscription_id);


--
-- Name: index_ai_conversations_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_conversations_on_membership_id ON public.ai_conversations USING btree (membership_id);


--
-- Name: index_ai_conversations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_conversations_on_organization_id ON public.ai_conversations USING btree (organization_id);


--
-- Name: index_api_keys_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_organization_id ON public.api_keys USING btree (organization_id);


--
-- Name: index_api_keys_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_value ON public.api_keys USING btree (value);


--
-- Name: index_applied_add_ons_on_add_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_add_ons_on_add_on_id ON public.applied_add_ons USING btree (add_on_id);


--
-- Name: index_applied_add_ons_on_add_on_id_and_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_add_ons_on_add_on_id_and_customer_id ON public.applied_add_ons USING btree (add_on_id, customer_id);


--
-- Name: index_applied_add_ons_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_add_ons_on_customer_id ON public.applied_add_ons USING btree (customer_id);


--
-- Name: index_applied_coupons_on_coupon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_coupons_on_coupon_id ON public.applied_coupons USING btree (coupon_id);


--
-- Name: index_applied_coupons_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_coupons_on_customer_id ON public.applied_coupons USING btree (customer_id);


--
-- Name: index_applied_coupons_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_coupons_on_organization_id ON public.applied_coupons USING btree (organization_id);


--
-- Name: index_applied_invoice_custom_sections_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_invoice_custom_sections_on_invoice_id ON public.applied_invoice_custom_sections USING btree (invoice_id);


--
-- Name: index_applied_invoice_custom_sections_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_invoice_custom_sections_on_organization_id ON public.applied_invoice_custom_sections USING btree (organization_id);


--
-- Name: index_applied_pricing_units_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_pricing_units_on_organization_id ON public.applied_pricing_units USING btree (organization_id);


--
-- Name: index_applied_pricing_units_on_pricing_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_pricing_units_on_pricing_unit_id ON public.applied_pricing_units USING btree (pricing_unit_id);


--
-- Name: index_applied_pricing_units_on_pricing_unitable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_pricing_units_on_pricing_unitable ON public.applied_pricing_units USING btree (pricing_unitable_type, pricing_unitable_id);


--
-- Name: index_applied_usage_thresholds_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_usage_thresholds_on_invoice_id ON public.applied_usage_thresholds USING btree (invoice_id);


--
-- Name: index_applied_usage_thresholds_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_usage_thresholds_on_organization_id ON public.applied_usage_thresholds USING btree (organization_id);


--
-- Name: index_applied_usage_thresholds_on_usage_threshold_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_usage_thresholds_on_usage_threshold_id ON public.applied_usage_thresholds USING btree (usage_threshold_id);


--
-- Name: index_billable_metric_filters_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metric_filters_on_billable_metric_id ON public.billable_metric_filters USING btree (billable_metric_id);


--
-- Name: index_billable_metric_filters_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metric_filters_on_deleted_at ON public.billable_metric_filters USING btree (deleted_at);


--
-- Name: index_billable_metric_filters_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metric_filters_on_organization_id ON public.billable_metric_filters USING btree (organization_id);


--
-- Name: index_billable_metrics_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metrics_on_deleted_at ON public.billable_metrics USING btree (deleted_at);


--
-- Name: index_billable_metrics_on_org_id_and_code_and_expr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metrics_on_org_id_and_code_and_expr ON public.billable_metrics USING btree (organization_id, code, expression) WHERE ((expression IS NOT NULL) AND ((expression)::text <> ''::text));


--
-- Name: index_billable_metrics_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billable_metrics_on_organization_id ON public.billable_metrics USING btree (organization_id);


--
-- Name: index_billable_metrics_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billable_metrics_on_organization_id_and_code ON public.billable_metrics USING btree (organization_id, code) WHERE (deleted_at IS NULL);


--
-- Name: index_billing_entities_on_applied_dunning_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_entities_on_applied_dunning_campaign_id ON public.billing_entities USING btree (applied_dunning_campaign_id);


--
-- Name: index_billing_entities_on_code_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_entities_on_code_and_organization_id ON public.billing_entities USING btree (code, organization_id) WHERE ((deleted_at IS NULL) AND (archived_at IS NULL));


--
-- Name: index_billing_entities_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_entities_on_organization_id ON public.billing_entities USING btree (organization_id);


--
-- Name: index_billing_entities_taxes_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_entities_taxes_on_billing_entity_id ON public.billing_entities_taxes USING btree (billing_entity_id);


--
-- Name: index_billing_entities_taxes_on_billing_entity_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_billing_entities_taxes_on_billing_entity_id_and_tax_id ON public.billing_entities_taxes USING btree (billing_entity_id, tax_id);


--
-- Name: index_billing_entities_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_entities_taxes_on_organization_id ON public.billing_entities_taxes USING btree (organization_id);


--
-- Name: index_billing_entities_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_billing_entities_taxes_on_tax_id ON public.billing_entities_taxes USING btree (tax_id);


--
-- Name: index_cached_aggregations_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cached_aggregations_on_charge_id ON public.cached_aggregations USING btree (charge_id);


--
-- Name: index_cached_aggregations_on_event_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cached_aggregations_on_event_transaction_id ON public.cached_aggregations USING btree (organization_id, event_transaction_id);


--
-- Name: index_cached_aggregations_on_external_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cached_aggregations_on_external_subscription_id ON public.cached_aggregations USING btree (external_subscription_id);


--
-- Name: index_charge_filter_values_on_billable_metric_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filter_values_on_billable_metric_filter_id ON public.charge_filter_values USING btree (billable_metric_filter_id);


--
-- Name: index_charge_filter_values_on_charge_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filter_values_on_charge_filter_id ON public.charge_filter_values USING btree (charge_filter_id);


--
-- Name: index_charge_filter_values_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filter_values_on_deleted_at ON public.charge_filter_values USING btree (deleted_at);


--
-- Name: index_charge_filter_values_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filter_values_on_organization_id ON public.charge_filter_values USING btree (organization_id);


--
-- Name: index_charge_filters_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filters_on_charge_id ON public.charge_filters USING btree (charge_id);


--
-- Name: index_charge_filters_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filters_on_deleted_at ON public.charge_filters USING btree (deleted_at);


--
-- Name: index_charge_filters_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_filters_on_organization_id ON public.charge_filters USING btree (organization_id);


--
-- Name: index_charges_on_accepts_target_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_accepts_target_wallet ON public.charges USING btree (accepts_target_wallet) WHERE (accepts_target_wallet = true);


--
-- Name: index_charges_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_billable_metric_id ON public.charges USING btree (billable_metric_id) WHERE (deleted_at IS NULL);


--
-- Name: index_charges_on_billable_metric_id_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_billable_metric_id_all ON public.charges USING btree (billable_metric_id);


--
-- Name: index_charges_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_deleted_at ON public.charges USING btree (deleted_at);


--
-- Name: index_charges_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_organization_id ON public.charges USING btree (organization_id);


--
-- Name: index_charges_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_parent_id ON public.charges USING btree (parent_id);


--
-- Name: index_charges_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_plan_id ON public.charges USING btree (plan_id);


--
-- Name: index_charges_on_plan_id_and_billable_metric_id_and_prorated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_plan_id_and_billable_metric_id_and_prorated ON public.charges USING btree (plan_id, billable_metric_id, prorated) WHERE (deleted_at IS NULL);


--
-- Name: index_charges_on_plan_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_charges_on_plan_id_and_code ON public.charges USING btree (plan_id, code) WHERE ((deleted_at IS NULL) AND (parent_id IS NULL));


--
-- Name: index_charges_pay_in_advance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_pay_in_advance ON public.charges USING btree (billable_metric_id) WHERE ((deleted_at IS NULL) AND (pay_in_advance = true));


--
-- Name: index_charges_taxes_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_taxes_on_charge_id ON public.charges_taxes USING btree (charge_id);


--
-- Name: index_charges_taxes_on_charge_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_charges_taxes_on_charge_id_and_tax_id ON public.charges_taxes USING btree (charge_id, tax_id);


--
-- Name: index_charges_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_taxes_on_organization_id ON public.charges_taxes USING btree (organization_id);


--
-- Name: index_charges_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_taxes_on_tax_id ON public.charges_taxes USING btree (tax_id);


--
-- Name: index_commitments_on_commitment_type_and_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitments_on_commitment_type_and_plan_id ON public.commitments USING btree (commitment_type, plan_id);


--
-- Name: index_commitments_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitments_on_organization_id ON public.commitments USING btree (organization_id);


--
-- Name: index_commitments_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitments_on_plan_id ON public.commitments USING btree (plan_id);


--
-- Name: index_commitments_taxes_on_commitment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitments_taxes_on_commitment_id ON public.commitments_taxes USING btree (commitment_id);


--
-- Name: index_commitments_taxes_on_commitment_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitments_taxes_on_commitment_id_and_tax_id ON public.commitments_taxes USING btree (commitment_id, tax_id);


--
-- Name: index_commitments_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitments_taxes_on_organization_id ON public.commitments_taxes USING btree (organization_id);


--
-- Name: index_commitments_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitments_taxes_on_tax_id ON public.commitments_taxes USING btree (tax_id);


--
-- Name: index_coupon_targets_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupon_targets_on_billable_metric_id ON public.coupon_targets USING btree (billable_metric_id);


--
-- Name: index_coupon_targets_on_coupon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupon_targets_on_coupon_id ON public.coupon_targets USING btree (coupon_id);


--
-- Name: index_coupon_targets_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupon_targets_on_deleted_at ON public.coupon_targets USING btree (deleted_at);


--
-- Name: index_coupon_targets_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupon_targets_on_organization_id ON public.coupon_targets USING btree (organization_id);


--
-- Name: index_coupon_targets_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupon_targets_on_plan_id ON public.coupon_targets USING btree (plan_id);


--
-- Name: index_coupons_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupons_on_deleted_at ON public.coupons USING btree (deleted_at);


--
-- Name: index_coupons_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coupons_on_organization_id ON public.coupons USING btree (organization_id);


--
-- Name: index_coupons_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_coupons_on_organization_id_and_code ON public.coupons USING btree (organization_id, code) WHERE (deleted_at IS NULL);


--
-- Name: index_credit_note_items_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_items_on_credit_note_id ON public.credit_note_items USING btree (credit_note_id);


--
-- Name: index_credit_note_items_on_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_items_on_fee_id ON public.credit_note_items USING btree (fee_id);


--
-- Name: index_credit_note_items_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_note_items_on_organization_id ON public.credit_note_items USING btree (organization_id);


--
-- Name: index_credit_notes_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_customer_id ON public.credit_notes USING btree (customer_id);


--
-- Name: index_credit_notes_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_invoice_id ON public.credit_notes USING btree (invoice_id);


--
-- Name: index_credit_notes_on_invoice_id_and_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_credit_notes_on_invoice_id_and_sequential_id ON public.credit_notes USING btree (invoice_id, sequential_id);


--
-- Name: index_credit_notes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_on_organization_id ON public.credit_notes USING btree (organization_id);


--
-- Name: index_credit_notes_taxes_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_taxes_on_credit_note_id ON public.credit_notes_taxes USING btree (credit_note_id);


--
-- Name: index_credit_notes_taxes_on_credit_note_id_and_tax_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_credit_notes_taxes_on_credit_note_id_and_tax_code ON public.credit_notes_taxes USING btree (credit_note_id, tax_code);


--
-- Name: index_credit_notes_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_taxes_on_organization_id ON public.credit_notes_taxes USING btree (organization_id);


--
-- Name: index_credit_notes_taxes_on_tax_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_taxes_on_tax_code ON public.credit_notes_taxes USING btree (tax_code);


--
-- Name: index_credit_notes_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_notes_taxes_on_tax_id ON public.credit_notes_taxes USING btree (tax_id);


--
-- Name: index_credits_on_applied_coupon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_applied_coupon_id ON public.credits USING btree (applied_coupon_id);


--
-- Name: index_credits_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_credit_note_id ON public.credits USING btree (credit_note_id);


--
-- Name: index_credits_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_invoice_id ON public.credits USING btree (invoice_id);


--
-- Name: index_credits_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_organization_id ON public.credits USING btree (organization_id);


--
-- Name: index_credits_on_progressive_billing_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_progressive_billing_invoice_id ON public.credits USING btree (progressive_billing_invoice_id);


--
-- Name: index_customer_metadata_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customer_metadata_on_customer_id ON public.customer_metadata USING btree (customer_id);


--
-- Name: index_customer_metadata_on_customer_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customer_metadata_on_customer_id_and_key ON public.customer_metadata USING btree (customer_id, key);


--
-- Name: index_customer_metadata_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customer_metadata_on_organization_id ON public.customer_metadata USING btree (organization_id);


--
-- Name: index_customers_by_cursor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_by_cursor ON public.customers USING btree (organization_id, created_at DESC, id);


--
-- Name: index_customers_invoice_custom_sections_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_invoice_custom_sections_on_billing_entity_id ON public.customers_invoice_custom_sections USING btree (billing_entity_id);


--
-- Name: index_customers_invoice_custom_sections_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_invoice_custom_sections_on_customer_id ON public.customers_invoice_custom_sections USING btree (customer_id);


--
-- Name: index_customers_invoice_custom_sections_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_invoice_custom_sections_on_organization_id ON public.customers_invoice_custom_sections USING btree (organization_id);


--
-- Name: index_customers_on_account_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_account_type ON public.customers USING btree (account_type);


--
-- Name: index_customers_on_applied_dunning_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_applied_dunning_campaign_id ON public.customers USING btree (applied_dunning_campaign_id);


--
-- Name: index_customers_on_awaiting_wallet_refresh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_awaiting_wallet_refresh ON public.customers USING btree (awaiting_wallet_refresh);


--
-- Name: index_customers_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_billing_entity_id ON public.customers USING btree (billing_entity_id);


--
-- Name: index_customers_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_deleted_at ON public.customers USING btree (deleted_at);


--
-- Name: index_customers_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_external_id ON public.customers USING btree (organization_id, external_id);


--
-- Name: index_customers_on_external_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_external_id_and_organization_id ON public.customers USING btree (external_id, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_org_id_and_sequential_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_org_id_and_sequential_id_unique ON public.customers USING btree (organization_id, sequential_id) WHERE (sequential_id IS NOT NULL);


--
-- Name: index_customers_on_organization_id_email_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_email_gin_trgm_ops ON public.customers USING gin (organization_id, email public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_external_id_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_external_id_gin_trgm_ops ON public.customers USING gin (organization_id, external_id public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_firstname_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_firstname_gin_trgm_ops ON public.customers USING gin (organization_id, firstname public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_kept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_kept ON public.customers USING btree (organization_id) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_lastname_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_lastname_gin_trgm_ops ON public.customers USING gin (organization_id, lastname public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_legal_name_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_legal_name_gin_trgm_ops ON public.customers USING gin (organization_id, legal_name public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_organization_id_name_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_organization_id_name_gin_trgm_ops ON public.customers USING gin (organization_id, name public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_customers_on_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_sequential_id ON public.customers USING btree (sequential_id);


--
-- Name: index_customers_taxes_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_taxes_on_customer_id ON public.customers_taxes USING btree (customer_id);


--
-- Name: index_customers_taxes_on_customer_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_taxes_on_customer_id_and_tax_id ON public.customers_taxes USING btree (customer_id, tax_id);


--
-- Name: index_customers_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_taxes_on_organization_id ON public.customers_taxes USING btree (organization_id);


--
-- Name: index_customers_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_taxes_on_tax_id ON public.customers_taxes USING btree (tax_id);


--
-- Name: index_daily_usages_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_usages_on_customer_id ON public.daily_usages USING btree (customer_id);


--
-- Name: index_daily_usages_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_usages_on_organization_id ON public.daily_usages USING btree (organization_id);


--
-- Name: index_daily_usages_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_usages_on_subscription_id ON public.daily_usages USING btree (subscription_id);


--
-- Name: index_daily_usages_on_subscription_id_and_usage_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_usages_on_subscription_id_and_usage_date ON public.daily_usages USING btree (subscription_id, usage_date);


--
-- Name: index_daily_usages_on_usage_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_usages_on_usage_date ON public.daily_usages USING btree (usage_date);


--
-- Name: index_data_export_parts_on_data_export_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_export_parts_on_data_export_id ON public.data_export_parts USING btree (data_export_id);


--
-- Name: index_data_export_parts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_export_parts_on_organization_id ON public.data_export_parts USING btree (organization_id);


--
-- Name: index_data_exports_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_exports_on_membership_id ON public.data_exports USING btree (membership_id);


--
-- Name: index_data_exports_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_exports_on_organization_id ON public.data_exports USING btree (organization_id);


--
-- Name: index_dunning_campaign_thresholds_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dunning_campaign_thresholds_on_deleted_at ON public.dunning_campaign_thresholds USING btree (deleted_at);


--
-- Name: index_dunning_campaign_thresholds_on_dunning_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dunning_campaign_thresholds_on_dunning_campaign_id ON public.dunning_campaign_thresholds USING btree (dunning_campaign_id);


--
-- Name: index_dunning_campaign_thresholds_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dunning_campaign_thresholds_on_organization_id ON public.dunning_campaign_thresholds USING btree (organization_id);


--
-- Name: index_dunning_campaigns_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dunning_campaigns_on_deleted_at ON public.dunning_campaigns USING btree (deleted_at);


--
-- Name: index_dunning_campaigns_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dunning_campaigns_on_organization_id ON public.dunning_campaigns USING btree (organization_id);


--
-- Name: index_dunning_campaigns_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dunning_campaigns_on_organization_id_and_code ON public.dunning_campaigns USING btree (organization_id, code) WHERE (deleted_at IS NULL);


--
-- Name: index_enriched_store_migrations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enriched_store_migrations_on_organization_id ON public.enriched_store_migrations USING btree (organization_id);


--
-- Name: index_entitlement_entitlement_values_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_entitlement_values_on_organization_id ON public.entitlement_entitlement_values USING btree (organization_id);


--
-- Name: index_entitlement_entitlements_on_entitlement_feature_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_entitlements_on_entitlement_feature_id ON public.entitlement_entitlements USING btree (entitlement_feature_id);


--
-- Name: index_entitlement_entitlements_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_entitlements_on_organization_id ON public.entitlement_entitlements USING btree (organization_id);


--
-- Name: index_entitlement_entitlements_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_entitlements_on_plan_id ON public.entitlement_entitlements USING btree (plan_id);


--
-- Name: index_entitlement_entitlements_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_entitlements_on_subscription_id ON public.entitlement_entitlements USING btree (subscription_id);


--
-- Name: index_entitlement_features_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_features_on_organization_id ON public.entitlement_features USING btree (organization_id);


--
-- Name: index_entitlement_privileges_on_entitlement_feature_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_privileges_on_entitlement_feature_id ON public.entitlement_privileges USING btree (entitlement_feature_id);


--
-- Name: index_entitlement_privileges_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_privileges_on_organization_id ON public.entitlement_privileges USING btree (organization_id);


--
-- Name: index_entitlement_subscription_feature_removals_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entitlement_subscription_feature_removals_on_deleted_at ON public.entitlement_subscription_feature_removals USING btree (deleted_at);


--
-- Name: index_error_details_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_details_on_deleted_at ON public.error_details USING btree (deleted_at);


--
-- Name: index_error_details_on_error_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_details_on_error_code ON public.error_details USING btree (error_code);


--
-- Name: index_error_details_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_details_on_organization_id ON public.error_details USING btree (organization_id);


--
-- Name: index_error_details_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_details_on_owner ON public.error_details USING btree (owner_type, owner_id);


--
-- Name: index_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_created_at ON public.events USING btree (created_at) WHERE (deleted_at IS NULL);


--
-- Name: index_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id ON public.events USING btree (organization_id);


--
-- Name: index_events_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_code ON public.events USING btree (organization_id, code);


--
-- Name: index_events_on_organization_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_created_at ON public.events USING btree (organization_id, created_at DESC) WHERE (deleted_at IS NULL);


--
-- Name: index_events_on_organization_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_timestamp ON public.events USING btree (organization_id, "timestamp" DESC) WHERE (deleted_at IS NULL);


--
-- Name: index_events_on_organization_id_and_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_transaction_id ON public.events USING btree (organization_id, transaction_id) WHERE (deleted_at IS NULL);


--
-- Name: index_fees_on_add_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_add_on_id ON public.fees USING btree (add_on_id);


--
-- Name: index_fees_on_applied_add_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_applied_add_on_id ON public.fees USING btree (applied_add_on_id);


--
-- Name: index_fees_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_billing_entity_id ON public.fees USING btree (billing_entity_id);


--
-- Name: index_fees_on_charge_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_charge_filter_id ON public.fees USING btree (charge_filter_id);


--
-- Name: index_fees_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_charge_id ON public.fees USING btree (charge_id);


--
-- Name: index_fees_on_charge_id_and_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_charge_id_and_invoice_id ON public.fees USING btree (charge_id, invoice_id) WHERE (deleted_at IS NULL);


--
-- Name: index_fees_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_deleted_at ON public.fees USING btree (deleted_at);


--
-- Name: index_fees_on_fixed_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_fixed_charge_id ON public.fees USING btree (fixed_charge_id);


--
-- Name: index_fees_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_group_id ON public.fees USING btree (group_id);


--
-- Name: index_fees_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_invoice_id ON public.fees USING btree (invoice_id);


--
-- Name: index_fees_on_invoiceable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_invoiceable ON public.fees USING btree (invoiceable_type, invoiceable_id);


--
-- Name: index_fees_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_organization_id ON public.fees USING btree (organization_id);


--
-- Name: index_fees_on_organization_id_and_created_at_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_organization_id_and_created_at_and_id ON public.fees USING btree (organization_id, created_at, id) WHERE (deleted_at IS NULL);


--
-- Name: index_fees_on_original_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_original_fee_id ON public.fees USING btree (original_fee_id);


--
-- Name: index_fees_on_pay_in_advance_event_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_pay_in_advance_event_transaction_id ON public.fees USING btree (pay_in_advance_event_transaction_id) WHERE (deleted_at IS NULL);


--
-- Name: index_fees_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_subscription_id ON public.fees USING btree (subscription_id);


--
-- Name: index_fees_on_true_up_parent_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_on_true_up_parent_fee_id ON public.fees USING btree (true_up_parent_fee_id);


--
-- Name: index_fees_taxes_on_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_taxes_on_fee_id ON public.fees_taxes USING btree (fee_id);


--
-- Name: index_fees_taxes_on_fee_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fees_taxes_on_fee_id_and_tax_id ON public.fees_taxes USING btree (fee_id, tax_id) WHERE ((tax_id IS NOT NULL) AND (created_at >= '2023-09-12 00:00:00'::timestamp without time zone));


--
-- Name: index_fees_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_taxes_on_organization_id ON public.fees_taxes USING btree (organization_id);


--
-- Name: index_fees_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fees_taxes_on_tax_id ON public.fees_taxes USING btree (tax_id);


--
-- Name: index_fixed_charge_events_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charge_events_on_deleted_at ON public.fixed_charge_events USING btree (deleted_at);


--
-- Name: index_fixed_charge_events_on_fixed_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charge_events_on_fixed_charge_id ON public.fixed_charge_events USING btree (fixed_charge_id);


--
-- Name: index_fixed_charge_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charge_events_on_organization_id ON public.fixed_charge_events USING btree (organization_id);


--
-- Name: index_fixed_charge_events_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charge_events_on_subscription_id ON public.fixed_charge_events USING btree (subscription_id);


--
-- Name: index_fixed_charges_on_add_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_on_add_on_id ON public.fixed_charges USING btree (add_on_id);


--
-- Name: index_fixed_charges_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_on_deleted_at ON public.fixed_charges USING btree (deleted_at);


--
-- Name: index_fixed_charges_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_on_organization_id ON public.fixed_charges USING btree (organization_id);


--
-- Name: index_fixed_charges_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_on_parent_id ON public.fixed_charges USING btree (parent_id);


--
-- Name: index_fixed_charges_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_on_plan_id ON public.fixed_charges USING btree (plan_id);


--
-- Name: index_fixed_charges_on_plan_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fixed_charges_on_plan_id_and_code ON public.fixed_charges USING btree (plan_id, code) WHERE ((deleted_at IS NULL) AND (parent_id IS NULL));


--
-- Name: index_fixed_charges_taxes_on_fixed_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_taxes_on_fixed_charge_id ON public.fixed_charges_taxes USING btree (fixed_charge_id);


--
-- Name: index_fixed_charges_taxes_on_fixed_charge_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fixed_charges_taxes_on_fixed_charge_id_and_tax_id ON public.fixed_charges_taxes USING btree (fixed_charge_id, tax_id);


--
-- Name: index_fixed_charges_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_taxes_on_organization_id ON public.fixed_charges_taxes USING btree (organization_id);


--
-- Name: index_fixed_charges_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fixed_charges_taxes_on_tax_id ON public.fixed_charges_taxes USING btree (tax_id);


--
-- Name: index_group_properties_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_properties_on_charge_id ON public.group_properties USING btree (charge_id);


--
-- Name: index_group_properties_on_charge_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_properties_on_charge_id_and_group_id ON public.group_properties USING btree (charge_id, group_id);


--
-- Name: index_group_properties_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_properties_on_deleted_at ON public.group_properties USING btree (deleted_at);


--
-- Name: index_group_properties_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_properties_on_group_id ON public.group_properties USING btree (group_id);


--
-- Name: index_groups_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_groups_on_billable_metric_id ON public.groups USING btree (billable_metric_id);


--
-- Name: index_groups_on_billable_metric_id_and_parent_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_groups_on_billable_metric_id_and_parent_group_id ON public.groups USING btree (billable_metric_id, parent_group_id);


--
-- Name: index_groups_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_groups_on_deleted_at ON public.groups USING btree (deleted_at);


--
-- Name: index_groups_on_parent_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_groups_on_parent_group_id ON public.groups USING btree (parent_group_id);


--
-- Name: index_idempotency_records_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_idempotency_records_on_idempotency_key ON public.idempotency_records USING btree (idempotency_key);


--
-- Name: index_idempotency_records_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_idempotency_records_on_organization_id ON public.idempotency_records USING btree (organization_id);


--
-- Name: index_idempotency_records_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_idempotency_records_on_resource_type_and_resource_id ON public.idempotency_records USING btree (resource_type, resource_id);


--
-- Name: index_inbound_webhooks_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inbound_webhooks_on_organization_id ON public.inbound_webhooks USING btree (organization_id);


--
-- Name: index_inbound_webhooks_on_status_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inbound_webhooks_on_status_and_created_at ON public.inbound_webhooks USING btree (status, created_at) WHERE (status = 'pending'::public.inbound_webhook_status);


--
-- Name: index_inbound_webhooks_on_status_and_processing_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inbound_webhooks_on_status_and_processing_at ON public.inbound_webhooks USING btree (status, processing_at) WHERE (status = 'processing'::public.inbound_webhook_status);


--
-- Name: index_int_collection_mappings_unique_billing_entity_is_not_null; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_int_collection_mappings_unique_billing_entity_is_not_null ON public.integration_collection_mappings USING btree (mapping_type, integration_id, billing_entity_id) WHERE (billing_entity_id IS NOT NULL);


--
-- Name: index_int_collection_mappings_unique_billing_entity_is_null; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_int_collection_mappings_unique_billing_entity_is_null ON public.integration_collection_mappings USING btree (mapping_type, integration_id, organization_id) WHERE (billing_entity_id IS NULL);


--
-- Name: index_int_items_on_external_id_and_int_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_int_items_on_external_id_and_int_id_and_type ON public.integration_items USING btree (external_id, integration_id, item_type);


--
-- Name: index_integration_collection_mappings_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_collection_mappings_on_billing_entity_id ON public.integration_collection_mappings USING btree (billing_entity_id);


--
-- Name: index_integration_collection_mappings_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_collection_mappings_on_integration_id ON public.integration_collection_mappings USING btree (integration_id);


--
-- Name: index_integration_collection_mappings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_collection_mappings_on_organization_id ON public.integration_collection_mappings USING btree (organization_id);


--
-- Name: index_integration_customers_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_customers_on_customer_id ON public.integration_customers USING btree (customer_id);


--
-- Name: index_integration_customers_on_customer_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_customers_on_customer_id_and_type ON public.integration_customers USING btree (customer_id, type);


--
-- Name: index_integration_customers_on_external_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_customers_on_external_customer_id ON public.integration_customers USING btree (external_customer_id);


--
-- Name: index_integration_customers_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_customers_on_integration_id ON public.integration_customers USING btree (integration_id);


--
-- Name: index_integration_customers_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_customers_on_organization_id ON public.integration_customers USING btree (organization_id);


--
-- Name: index_integration_items_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_items_on_integration_id ON public.integration_items USING btree (integration_id);


--
-- Name: index_integration_items_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_items_on_organization_id ON public.integration_items USING btree (organization_id);


--
-- Name: index_integration_mappings_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_mappings_on_integration_id ON public.integration_mappings USING btree (integration_id);


--
-- Name: index_integration_mappings_on_mappable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_mappings_on_mappable ON public.integration_mappings USING btree (mappable_type, mappable_id);


--
-- Name: index_integration_mappings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_mappings_on_organization_id ON public.integration_mappings USING btree (organization_id);


--
-- Name: index_integration_mappings_unique_billing_entity_id_is_not_null; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_mappings_unique_billing_entity_id_is_not_null ON public.integration_mappings USING btree (mappable_type, mappable_id, integration_id, billing_entity_id) WHERE (billing_entity_id IS NOT NULL);


--
-- Name: index_integration_mappings_unique_billing_entity_id_is_null; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_mappings_unique_billing_entity_id_is_null ON public.integration_mappings USING btree (mappable_type, mappable_id, integration_id, organization_id) WHERE (billing_entity_id IS NULL);


--
-- Name: index_integration_resources_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_resources_on_integration_id ON public.integration_resources USING btree (integration_id);


--
-- Name: index_integration_resources_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_resources_on_organization_id ON public.integration_resources USING btree (organization_id);


--
-- Name: index_integration_resources_on_syncable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_resources_on_syncable ON public.integration_resources USING btree (syncable_type, syncable_id);


--
-- Name: index_integrations_on_code_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integrations_on_code_and_organization_id ON public.integrations USING btree (code, organization_id);


--
-- Name: index_integrations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_organization_id ON public.integrations USING btree (organization_id);


--
-- Name: index_invites_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invites_on_membership_id ON public.invites USING btree (membership_id);


--
-- Name: index_invites_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invites_on_organization_id ON public.invites USING btree (organization_id);


--
-- Name: index_invites_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invites_on_token ON public.invites USING btree (token);


--
-- Name: index_invoice_custom_sections_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_custom_sections_on_organization_id ON public.invoice_custom_sections USING btree (organization_id);


--
-- Name: index_invoice_custom_sections_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoice_custom_sections_on_organization_id_and_code ON public.invoice_custom_sections USING btree (organization_id, code) WHERE (deleted_at IS NULL);


--
-- Name: index_invoice_custom_sections_on_section_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_custom_sections_on_section_type ON public.invoice_custom_sections USING btree (section_type);


--
-- Name: index_invoice_metadata_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_metadata_on_invoice_id ON public.invoice_metadata USING btree (invoice_id);


--
-- Name: index_invoice_metadata_on_invoice_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoice_metadata_on_invoice_id_and_key ON public.invoice_metadata USING btree (invoice_id, key);


--
-- Name: index_invoice_metadata_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_metadata_on_organization_id ON public.invoice_metadata USING btree (organization_id);


--
-- Name: index_invoice_settlements_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_settlements_on_billing_entity_id ON public.invoice_settlements USING btree (billing_entity_id);


--
-- Name: index_invoice_settlements_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_settlements_on_organization_id ON public.invoice_settlements USING btree (organization_id);


--
-- Name: index_invoice_settlements_on_source_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_settlements_on_source_credit_note_id ON public.invoice_settlements USING btree (source_credit_note_id);


--
-- Name: index_invoice_settlements_on_source_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_settlements_on_source_payment_id ON public.invoice_settlements USING btree (source_payment_id);


--
-- Name: index_invoice_settlements_on_target_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_settlements_on_target_invoice_id ON public.invoice_settlements USING btree (target_invoice_id);


--
-- Name: index_invoice_subscriptions_boundaries; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_subscriptions_boundaries ON public.invoice_subscriptions USING btree (subscription_id, from_datetime, to_datetime);


--
-- Name: index_invoice_subscriptions_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_subscriptions_on_invoice_id ON public.invoice_subscriptions USING btree (invoice_id);


--
-- Name: index_invoice_subscriptions_on_invoice_id_and_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoice_subscriptions_on_invoice_id_and_subscription_id ON public.invoice_subscriptions USING btree (invoice_id, subscription_id) WHERE (created_at >= '2023-11-23 00:00:00'::timestamp without time zone);


--
-- Name: index_invoice_subscriptions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_subscriptions_on_organization_id ON public.invoice_subscriptions USING btree (organization_id);


--
-- Name: index_invoice_subscriptions_on_regenerated_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_subscriptions_on_regenerated_invoice_id ON public.invoice_subscriptions USING btree (regenerated_invoice_id);


--
-- Name: index_invoice_subscriptions_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_subscriptions_on_subscription_id ON public.invoice_subscriptions USING btree (subscription_id);


--
-- Name: index_invoices_by_cursor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_by_cursor ON public.invoices USING btree (organization_id, issuing_date DESC, created_at DESC, id);


--
-- Name: index_invoices_on_customer_billing_entity_sequential; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_on_customer_billing_entity_sequential ON public.invoices USING btree (customer_id, billing_entity_id, sequential_id);


--
-- Name: index_invoices_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_number ON public.invoices USING btree (number);


--
-- Name: index_invoices_on_organization_id_and_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_organization_id_and_customer_id ON public.invoices USING btree (customer_id, organization_id);


--
-- Name: index_invoices_on_organization_id_number_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_organization_id_number_gin_trgm_ops ON public.invoices USING gin (organization_id, number public.gin_trgm_ops);


--
-- Name: index_invoices_on_payment_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_payment_due_date ON public.invoices USING btree (payment_due_date) WHERE ((status = 1) AND (payment_status <> 1) AND (payment_overdue = false) AND (payment_dispute_lost_at IS NULL));


--
-- Name: index_invoices_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_payment_method_id ON public.invoices USING btree (payment_method_id);


--
-- Name: index_invoices_on_ready_to_be_refreshed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_ready_to_be_refreshed ON public.invoices USING btree (ready_to_be_refreshed) WHERE (ready_to_be_refreshed = true);


--
-- Name: index_invoices_on_voided_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_voided_invoice_id ON public.invoices USING btree (voided_invoice_id);


--
-- Name: index_invoices_payment_requests_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_payment_requests_on_invoice_id ON public.invoices_payment_requests USING btree (invoice_id);


--
-- Name: index_invoices_payment_requests_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_payment_requests_on_organization_id ON public.invoices_payment_requests USING btree (organization_id);


--
-- Name: index_invoices_payment_requests_on_payment_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_payment_requests_on_payment_request_id ON public.invoices_payment_requests USING btree (payment_request_id);


--
-- Name: index_invoices_taxes_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_taxes_on_invoice_id ON public.invoices_taxes USING btree (invoice_id);


--
-- Name: index_invoices_taxes_on_invoice_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_taxes_on_invoice_id_and_tax_id ON public.invoices_taxes USING btree (invoice_id, tax_id) WHERE ((tax_id IS NOT NULL) AND (created_at >= '2023-09-12 00:00:00'::timestamp without time zone));


--
-- Name: index_invoices_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_taxes_on_organization_id ON public.invoices_taxes USING btree (organization_id);


--
-- Name: index_invoices_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_taxes_on_tax_id ON public.invoices_taxes USING btree (tax_id);


--
-- Name: index_item_metadata_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_metadata_on_organization_id ON public.item_metadata USING btree (organization_id);


--
-- Name: index_item_metadata_on_owner_type_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_item_metadata_on_owner_type_and_owner_id ON public.item_metadata USING btree (owner_type, owner_id);


--
-- Name: index_item_metadata_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_metadata_on_value ON public.item_metadata USING gin (value);


--
-- Name: index_lifetime_usages_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lifetime_usages_on_organization_id ON public.lifetime_usages USING btree (organization_id);


--
-- Name: index_lifetime_usages_on_recalculate_current_usage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lifetime_usages_on_recalculate_current_usage ON public.lifetime_usages USING btree (recalculate_current_usage) WHERE ((deleted_at IS NULL) AND (recalculate_current_usage = true));


--
-- Name: index_lifetime_usages_on_recalculate_invoiced_usage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lifetime_usages_on_recalculate_invoiced_usage ON public.lifetime_usages USING btree (recalculate_invoiced_usage) WHERE ((deleted_at IS NULL) AND (recalculate_invoiced_usage = true));


--
-- Name: index_lifetime_usages_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_lifetime_usages_on_subscription_id ON public.lifetime_usages USING btree (subscription_id);


--
-- Name: index_membership_roles_by_membership_and_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_membership_roles_by_membership_and_organization ON public.membership_roles USING btree (membership_id, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: index_membership_roles_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_membership_roles_on_role_id ON public.membership_roles USING btree (role_id);


--
-- Name: index_membership_roles_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_membership_roles_uniqueness ON public.membership_roles USING btree (membership_id, role_id) WHERE (deleted_at IS NULL);


--
-- Name: index_memberships_by_id_and_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_by_id_and_organization ON public.memberships USING btree (id, organization_id);


--
-- Name: index_memberships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id ON public.memberships USING btree (organization_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_memberships_on_user_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_user_id_and_organization_id ON public.memberships USING btree (user_id, organization_id) WHERE (revoked_at IS NULL);


--
-- Name: index_order_forms_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_forms_on_customer_id ON public.order_forms USING btree (customer_id);


--
-- Name: index_order_forms_on_organization_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_forms_on_organization_id_and_created_at ON public.order_forms USING btree (organization_id, created_at);


--
-- Name: index_order_forms_on_organization_id_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_forms_on_organization_id_and_expires_at ON public.order_forms USING btree (organization_id, expires_at);


--
-- Name: index_order_forms_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_forms_on_organization_id_and_status ON public.order_forms USING btree (organization_id, status);


--
-- Name: index_order_forms_on_quote_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_order_forms_on_quote_version_id ON public.order_forms USING btree (quote_version_id);


--
-- Name: index_orders_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_customer_id ON public.orders USING btree (customer_id);


--
-- Name: index_orders_on_order_form_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_orders_on_order_form_id ON public.orders USING btree (order_form_id);


--
-- Name: index_orders_on_organization_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_organization_id_and_created_at ON public.orders USING btree (organization_id, created_at);


--
-- Name: index_orders_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_organization_id_and_status ON public.orders USING btree (organization_id, status);


--
-- Name: index_organizations_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_api_key ON public.organizations USING btree (api_key);


--
-- Name: index_organizations_on_hmac_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_hmac_key ON public.organizations USING btree (hmac_key);


--
-- Name: index_organizations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_slug ON public.organizations USING btree (slug);


--
-- Name: index_password_resets_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_password_resets_on_token ON public.password_resets USING btree (token);


--
-- Name: index_password_resets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_password_resets_on_user_id ON public.password_resets USING btree (user_id);


--
-- Name: index_payment_intents_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_intents_on_invoice_id ON public.payment_intents USING btree (invoice_id);


--
-- Name: index_payment_intents_on_invoice_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_intents_on_invoice_id_and_status ON public.payment_intents USING btree (invoice_id, status) WHERE (status = 0);


--
-- Name: index_payment_intents_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_intents_on_organization_id ON public.payment_intents USING btree (organization_id);


--
-- Name: index_payment_methods_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_customer_id ON public.payment_methods USING btree (customer_id);


--
-- Name: index_payment_methods_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_organization_id ON public.payment_methods USING btree (organization_id);


--
-- Name: index_payment_methods_on_payment_provider_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_payment_provider_customer_id ON public.payment_methods USING btree (payment_provider_customer_id);


--
-- Name: index_payment_methods_on_payment_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_payment_provider_id ON public.payment_methods USING btree (payment_provider_id);


--
-- Name: index_payment_methods_on_provider_customer_and_provider_method; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_methods_on_provider_customer_and_provider_method ON public.payment_methods USING btree (payment_provider_customer_id, provider_method_id) WHERE (deleted_at IS NULL);


--
-- Name: index_payment_methods_on_provider_method_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_methods_on_provider_method_type ON public.payment_methods USING btree (provider_method_type);


--
-- Name: index_payment_provider_customers_on_customer_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_provider_customers_on_customer_id_and_type ON public.payment_provider_customers USING btree (customer_id, type) WHERE (deleted_at IS NULL);


--
-- Name: index_payment_provider_customers_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_provider_customers_on_organization_id ON public.payment_provider_customers USING btree (organization_id);


--
-- Name: index_payment_provider_customers_on_payment_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_provider_customers_on_payment_provider_id ON public.payment_provider_customers USING btree (payment_provider_id);


--
-- Name: index_payment_provider_customers_on_provider_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_provider_customers_on_provider_customer_id ON public.payment_provider_customers USING btree (provider_customer_id);


--
-- Name: index_payment_providers_on_code_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_providers_on_code_and_organization_id ON public.payment_providers USING btree (code, organization_id) WHERE (deleted_at IS NULL);


--
-- Name: index_payment_providers_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_providers_on_organization_id ON public.payment_providers USING btree (organization_id);


--
-- Name: index_payment_receipts_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_receipts_on_billing_entity_id ON public.payment_receipts USING btree (billing_entity_id);


--
-- Name: index_payment_receipts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_receipts_on_organization_id ON public.payment_receipts USING btree (organization_id);


--
-- Name: index_payment_receipts_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_receipts_on_payment_id ON public.payment_receipts USING btree (payment_id);


--
-- Name: index_payment_requests_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_requests_on_customer_id ON public.payment_requests USING btree (customer_id);


--
-- Name: index_payment_requests_on_dunning_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_requests_on_dunning_campaign_id ON public.payment_requests USING btree (dunning_campaign_id);


--
-- Name: index_payment_requests_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_requests_on_organization_id ON public.payment_requests USING btree (organization_id);


--
-- Name: index_payments_by_cursor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_by_cursor ON public.payments USING btree (organization_id, created_at DESC, id);


--
-- Name: index_payments_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_customer_id ON public.payments USING btree (customer_id);


--
-- Name: index_payments_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_invoice_id ON public.payments USING btree (invoice_id);


--
-- Name: index_payments_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_organization_id ON public.payments USING btree (organization_id);


--
-- Name: index_payments_on_organization_id_reference_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_organization_id_reference_gin_trgm_ops ON public.payments USING gin (organization_id, reference public.gin_trgm_ops);


--
-- Name: index_payments_on_payable_id_and_payable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_payable_id_and_payable_type ON public.payments USING btree (payable_id, payable_type) WHERE ((payable_payment_status = ANY (ARRAY['pending'::public.payment_payable_payment_status, 'processing'::public.payment_payable_payment_status])) AND (payment_type = 'provider'::public.payment_type));


--
-- Name: index_payments_on_payable_id_and_payable_type_and_error_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payable_id_and_payable_type_and_error_code ON public.payments USING btree (payable_id, payable_type, error_code);


--
-- Name: index_payments_on_payable_type_and_payable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payable_type_and_payable_id ON public.payments USING btree (payable_type, payable_id);


--
-- Name: index_payments_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payment_method_id ON public.payments USING btree (payment_method_id);


--
-- Name: index_payments_on_payment_provider_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payment_provider_customer_id ON public.payments USING btree (payment_provider_customer_id);


--
-- Name: index_payments_on_payment_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payment_provider_id ON public.payments USING btree (payment_provider_id);


--
-- Name: index_payments_on_payment_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_payment_type ON public.payments USING btree (payment_type);


--
-- Name: index_payments_on_provider_payment_id_and_payment_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_provider_payment_id_and_payment_provider_id ON public.payments USING btree (provider_payment_id, payment_provider_id) WHERE (provider_payment_id IS NOT NULL);


--
-- Name: index_pending_active_subscriptions_on_plan_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pending_active_subscriptions_on_plan_id_and_status ON public.subscriptions USING btree (plan_id, status) WHERE (status = ANY (ARRAY[0, 1]));


--
-- Name: index_pending_vies_checks_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pending_vies_checks_on_billing_entity_id ON public.pending_vies_checks USING btree (billing_entity_id);


--
-- Name: index_pending_vies_checks_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pending_vies_checks_on_customer_id ON public.pending_vies_checks USING btree (customer_id);


--
-- Name: index_pending_vies_checks_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pending_vies_checks_on_organization_id ON public.pending_vies_checks USING btree (organization_id);


--
-- Name: index_plans_on_bill_fixed_charges_monthly; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_bill_fixed_charges_monthly ON public.plans USING btree (bill_fixed_charges_monthly) WHERE ((deleted_at IS NULL) AND (bill_fixed_charges_monthly IS TRUE));


--
-- Name: index_plans_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_created_at ON public.plans USING btree (created_at);


--
-- Name: index_plans_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_deleted_at ON public.plans USING btree (deleted_at);


--
-- Name: index_plans_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_organization_id ON public.plans USING btree (organization_id);


--
-- Name: index_plans_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_on_organization_id_and_code ON public.plans USING btree (organization_id, code) WHERE ((deleted_at IS NULL) AND (parent_id IS NULL));


--
-- Name: index_plans_on_organization_id_code_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_organization_id_code_gin_trgm_ops ON public.plans USING gin (organization_id, code public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_plans_on_organization_id_name_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_organization_id_name_gin_trgm_ops ON public.plans USING gin (organization_id, name public.gin_trgm_ops) WHERE (deleted_at IS NULL);


--
-- Name: index_plans_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_on_parent_id ON public.plans USING btree (parent_id);


--
-- Name: index_plans_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_taxes_on_organization_id ON public.plans_taxes USING btree (organization_id);


--
-- Name: index_plans_taxes_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_taxes_on_plan_id ON public.plans_taxes USING btree (plan_id);


--
-- Name: index_plans_taxes_on_plan_id_and_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_taxes_on_plan_id_and_tax_id ON public.plans_taxes USING btree (plan_id, tax_id);


--
-- Name: index_plans_taxes_on_tax_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plans_taxes_on_tax_id ON public.plans_taxes USING btree (tax_id);


--
-- Name: index_presentation_breakdowns_on_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_presentation_breakdowns_on_fee_id ON public.presentation_breakdowns USING btree (fee_id);


--
-- Name: index_presentation_breakdowns_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_presentation_breakdowns_on_organization_id ON public.presentation_breakdowns USING btree (organization_id);


--
-- Name: index_pricing_unit_usages_on_fee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pricing_unit_usages_on_fee_id ON public.pricing_unit_usages USING btree (fee_id);


--
-- Name: index_pricing_unit_usages_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pricing_unit_usages_on_organization_id ON public.pricing_unit_usages USING btree (organization_id);


--
-- Name: index_pricing_unit_usages_on_pricing_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pricing_unit_usages_on_pricing_unit_id ON public.pricing_unit_usages USING btree (pricing_unit_id);


--
-- Name: index_pricing_units_on_code_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pricing_units_on_code_and_organization_id ON public.pricing_units USING btree (code, organization_id);


--
-- Name: index_pricing_units_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pricing_units_on_organization_id ON public.pricing_units USING btree (organization_id);


--
-- Name: index_quantified_events_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_billable_metric_id ON public.quantified_events USING btree (billable_metric_id);


--
-- Name: index_quantified_events_on_charge_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_charge_filter_id ON public.quantified_events USING btree (charge_filter_id);


--
-- Name: index_quantified_events_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_deleted_at ON public.quantified_events USING btree (deleted_at);


--
-- Name: index_quantified_events_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_external_id ON public.quantified_events USING btree (external_id);


--
-- Name: index_quantified_events_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_group_id ON public.quantified_events USING btree (group_id);


--
-- Name: index_quantified_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quantified_events_on_organization_id ON public.quantified_events USING btree (organization_id);


--
-- Name: index_quote_owners_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_owners_on_organization_id ON public.quote_owners USING btree (organization_id);


--
-- Name: index_quote_owners_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_owners_on_user_id ON public.quote_owners USING btree (user_id);


--
-- Name: index_quote_versions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_versions_on_organization_id ON public.quote_versions USING btree (organization_id);


--
-- Name: index_quote_versions_on_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quote_versions_on_quote_id ON public.quote_versions USING btree (quote_id);


--
-- Name: index_quotes_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_customer_id ON public.quotes USING btree (customer_id);


--
-- Name: index_quotes_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quotes_on_subscription_id ON public.quotes USING btree (subscription_id);


--
-- Name: index_recurring_transaction_rules_on_expiration_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurring_transaction_rules_on_expiration_at ON public.recurring_transaction_rules USING btree (expiration_at);


--
-- Name: index_recurring_transaction_rules_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurring_transaction_rules_on_organization_id ON public.recurring_transaction_rules USING btree (organization_id);


--
-- Name: index_recurring_transaction_rules_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurring_transaction_rules_on_payment_method_id ON public.recurring_transaction_rules USING btree (payment_method_id);


--
-- Name: index_recurring_transaction_rules_on_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurring_transaction_rules_on_started_at ON public.recurring_transaction_rules USING btree (started_at);


--
-- Name: index_recurring_transaction_rules_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recurring_transaction_rules_on_wallet_id ON public.recurring_transaction_rules USING btree (wallet_id);


--
-- Name: index_refunds_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_credit_note_id ON public.refunds USING btree (credit_note_id);


--
-- Name: index_refunds_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_organization_id ON public.refunds USING btree (organization_id);


--
-- Name: index_refunds_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_payment_id ON public.refunds USING btree (payment_id);


--
-- Name: index_refunds_on_payment_provider_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_payment_provider_customer_id ON public.refunds USING btree (payment_provider_customer_id);


--
-- Name: index_refunds_on_payment_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_payment_provider_id ON public.refunds USING btree (payment_provider_id);


--
-- Name: index_refunds_on_refundable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_refundable ON public.refunds USING btree (refundable_type, refundable_id);


--
-- Name: index_roles_by_code_per_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_by_code_per_organization ON public.roles USING btree (organization_id NULLS FIRST, code) WHERE (deleted_at IS NULL);


--
-- Name: index_roles_by_unique_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_by_unique_admin ON public.roles USING btree (admin) WHERE (admin AND (deleted_at IS NULL));


--
-- Name: index_roles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_organization_id ON public.roles USING btree (organization_id);


--
-- Name: index_rtr_invoice_custom_sections_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rtr_invoice_custom_sections_unique ON public.recurring_transaction_rules_invoice_custom_sections USING btree (recurring_transaction_rule_id, invoice_custom_section_id);


--
-- Name: index_search_quantified_events; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_quantified_events ON public.quantified_events USING btree (organization_id, external_subscription_id, billable_metric_id);


--
-- Name: index_sub_fc_units_overrides_on_sub_id_and_fc_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sub_fc_units_overrides_on_sub_id_and_fc_id ON public.subscription_fixed_charge_units_overrides USING btree (subscription_id, fixed_charge_id) WHERE (deleted_at IS NULL);


--
-- Name: index_subscription_activation_rules_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscription_activation_rules_on_organization_id ON public.subscription_activation_rules USING btree (organization_id);


--
-- Name: index_subscription_fixed_charge_units_overrides_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscription_fixed_charge_units_overrides_on_deleted_at ON public.subscription_fixed_charge_units_overrides USING btree (deleted_at);


--
-- Name: index_subscriptions_invoice_custom_sections_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_invoice_custom_sections_on_organization_id ON public.subscriptions_invoice_custom_sections USING btree (organization_id);


--
-- Name: index_subscriptions_invoice_custom_sections_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_invoice_custom_sections_on_subscription_id ON public.subscriptions_invoice_custom_sections USING btree (subscription_id);


--
-- Name: index_subscriptions_invoice_custom_sections_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_invoice_custom_sections_unique ON public.subscriptions_invoice_custom_sections USING btree (subscription_id, invoice_custom_section_id);


--
-- Name: index_subscriptions_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_billing_entity_id ON public.subscriptions USING btree (billing_entity_id);


--
-- Name: index_subscriptions_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_customer_id ON public.subscriptions USING btree (customer_id);


--
-- Name: index_subscriptions_on_ending_at_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_ending_at_active ON public.subscriptions USING btree (ending_at) WHERE ((status = 1) AND (ending_at IS NOT NULL));


--
-- Name: index_subscriptions_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_external_id ON public.subscriptions USING btree (external_id);


--
-- Name: index_subscriptions_on_last_received_event_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_last_received_event_on ON public.subscriptions USING btree (last_received_event_on);


--
-- Name: index_subscriptions_on_last_received_event_on_null; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_last_received_event_on_null ON public.subscriptions USING btree (id) WHERE (last_received_event_on IS NULL);


--
-- Name: index_subscriptions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_organization_id ON public.subscriptions USING btree (organization_id);


--
-- Name: index_subscriptions_on_organization_id_name_gin_trgm_ops; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_organization_id_name_gin_trgm_ops ON public.subscriptions USING gin (organization_id, name public.gin_trgm_ops);


--
-- Name: index_subscriptions_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_payment_method_id ON public.subscriptions USING btree (payment_method_id);


--
-- Name: index_subscriptions_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_plan_id ON public.subscriptions USING btree (plan_id);


--
-- Name: index_subscriptions_on_previous_subscription_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_previous_subscription_id_and_status ON public.subscriptions USING btree (previous_subscription_id, status);


--
-- Name: index_subscriptions_on_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_started_at ON public.subscriptions USING btree (started_at);


--
-- Name: index_subscriptions_on_started_at_and_ending_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_started_at_and_ending_at ON public.subscriptions USING btree (started_at, ending_at);


--
-- Name: index_subscriptions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_status ON public.subscriptions USING btree (status);


--
-- Name: index_taxes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxes_on_organization_id ON public.taxes USING btree (organization_id);


--
-- Name: index_uniq_invoice_subscriptions_on_charges_from_to_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_uniq_invoice_subscriptions_on_charges_from_to_datetime ON public.invoice_subscriptions USING btree (subscription_id, charges_from_datetime, charges_to_datetime) WHERE ((created_at >= '2023-06-09 00:00:00'::timestamp without time zone) AND (recurring IS TRUE) AND (regenerated_invoice_id IS NULL));


--
-- Name: index_uniq_invoice_subscriptions_on_fixed_charges_boundaries; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_uniq_invoice_subscriptions_on_fixed_charges_boundaries ON public.invoice_subscriptions USING btree (subscription_id, fixed_charges_from_datetime, fixed_charges_to_datetime) WHERE ((fixed_charges_from_datetime IS NOT NULL) AND (recurring IS TRUE) AND (regenerated_invoice_id IS NULL));


--
-- Name: index_uniq_wallet_code_per_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_uniq_wallet_code_per_customer ON public.wallets USING btree (customer_id, code) WHERE (status = 0);


--
-- Name: index_unique_applied_to_organization_per_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_applied_to_organization_per_organization ON public.dunning_campaigns USING btree (organization_id) WHERE ((applied_to_organization = true) AND (deleted_at IS NULL));


--
-- Name: index_unique_order_forms_on_organization_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_order_forms_on_organization_number ON public.order_forms USING btree (organization_id, number);


--
-- Name: index_unique_order_forms_on_organization_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_order_forms_on_organization_sequential_id ON public.order_forms USING btree (organization_id, sequential_id);


--
-- Name: index_unique_orders_on_organization_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_orders_on_organization_number ON public.orders USING btree (organization_id, number);


--
-- Name: index_unique_orders_on_organization_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_orders_on_organization_sequential_id ON public.orders USING btree (organization_id, sequential_id);


--
-- Name: index_unique_quote_owners_on_quote_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quote_owners_on_quote_user ON public.quote_owners USING btree (quote_id, user_id);


--
-- Name: index_unique_quote_versions_on_quote_active_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quote_versions_on_quote_active_status ON public.quote_versions USING btree (quote_id) WHERE (status = ANY (ARRAY['draft'::public.quote_status, 'approved'::public.quote_status]));


--
-- Name: index_unique_quote_versions_on_quote_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quote_versions_on_quote_sequential_id ON public.quote_versions USING btree (quote_id, sequential_id);


--
-- Name: index_unique_quote_versions_on_share_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quote_versions_on_share_token ON public.quote_versions USING btree (share_token);


--
-- Name: index_unique_quotes_on_organization_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quotes_on_organization_number ON public.quotes USING btree (organization_id, number);


--
-- Name: index_unique_quotes_on_organization_sequential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_quotes_on_organization_sequential_id ON public.quotes USING btree (organization_id, sequential_id);


--
-- Name: index_unique_starting_invoice_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_starting_invoice_subscription ON public.invoice_subscriptions USING btree (subscription_id, invoicing_reason) WHERE ((invoicing_reason = 'subscription_starting'::public.subscription_invoicing_reason) AND (regenerated_invoice_id IS NULL));


--
-- Name: index_unique_terminating_invoice_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_terminating_invoice_subscription ON public.invoice_subscriptions USING btree (subscription_id, invoicing_reason) WHERE ((invoicing_reason = 'subscription_terminating'::public.subscription_invoicing_reason) AND (regenerated_invoice_id IS NULL));


--
-- Name: index_unique_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unique_transaction_id ON public.events USING btree (organization_id, external_subscription_id, transaction_id);


--
-- Name: index_usage_monitoring_alert_thresholds_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_alert_thresholds_on_organization_id ON public.usage_monitoring_alert_thresholds USING btree (organization_id);


--
-- Name: index_usage_monitoring_alerts_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_alerts_on_billable_metric_id ON public.usage_monitoring_alerts USING btree (billable_metric_id);


--
-- Name: index_usage_monitoring_alerts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_alerts_on_organization_id ON public.usage_monitoring_alerts USING btree (organization_id);


--
-- Name: index_usage_monitoring_alerts_on_subscription_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_alerts_on_subscription_external_id ON public.usage_monitoring_alerts USING btree (subscription_external_id);


--
-- Name: index_usage_monitoring_alerts_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_alerts_on_wallet_id ON public.usage_monitoring_alerts USING btree (wallet_id);


--
-- Name: index_usage_monitoring_triggered_alerts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_triggered_alerts_on_organization_id ON public.usage_monitoring_triggered_alerts USING btree (organization_id);


--
-- Name: index_usage_monitoring_triggered_alerts_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_triggered_alerts_on_subscription_id ON public.usage_monitoring_triggered_alerts USING btree (subscription_id);


--
-- Name: index_usage_monitoring_triggered_alerts_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_monitoring_triggered_alerts_on_wallet_id ON public.usage_monitoring_triggered_alerts USING btree (wallet_id);


--
-- Name: index_usage_thresholds_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_thresholds_on_organization_id ON public.usage_thresholds USING btree (organization_id);


--
-- Name: index_usage_thresholds_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_thresholds_on_plan_id ON public.usage_thresholds USING btree (plan_id);


--
-- Name: index_usage_thresholds_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_thresholds_on_subscription_id ON public.usage_thresholds USING btree (subscription_id);


--
-- Name: index_user_devices_on_user_id_and_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_devices_on_user_id_and_fingerprint ON public.user_devices USING btree (user_id, fingerprint);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: index_wallet_targets_on_billable_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_targets_on_billable_metric_id ON public.wallet_targets USING btree (billable_metric_id);


--
-- Name: index_wallet_targets_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_targets_on_organization_id ON public.wallet_targets USING btree (organization_id);


--
-- Name: index_wallet_targets_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_targets_on_wallet_id ON public.wallet_targets USING btree (wallet_id);


--
-- Name: index_wallet_transaction_consumptions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transaction_consumptions_on_organization_id ON public.wallet_transaction_consumptions USING btree (organization_id);


--
-- Name: index_wallet_transactions_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_billing_entity_id ON public.wallet_transactions USING btree (billing_entity_id);


--
-- Name: index_wallet_transactions_on_credit_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_credit_note_id ON public.wallet_transactions USING btree (credit_note_id);


--
-- Name: index_wallet_transactions_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_invoice_id ON public.wallet_transactions USING btree (invoice_id);


--
-- Name: index_wallet_transactions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_organization_id ON public.wallet_transactions USING btree (organization_id);


--
-- Name: index_wallet_transactions_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_payment_method_id ON public.wallet_transactions USING btree (payment_method_id);


--
-- Name: index_wallet_transactions_on_voided_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_voided_invoice_id ON public.wallet_transactions USING btree (voided_invoice_id);


--
-- Name: index_wallet_transactions_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallet_transactions_on_wallet_id ON public.wallet_transactions USING btree (wallet_id);


--
-- Name: index_wallets_invoice_custom_sections_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_invoice_custom_sections_on_organization_id ON public.wallets_invoice_custom_sections USING btree (organization_id);


--
-- Name: index_wallets_invoice_custom_sections_on_wallet_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_invoice_custom_sections_on_wallet_id ON public.wallets_invoice_custom_sections USING btree (wallet_id);


--
-- Name: index_wallets_invoice_custom_sections_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_wallets_invoice_custom_sections_unique ON public.wallets_invoice_custom_sections USING btree (wallet_id, invoice_custom_section_id);


--
-- Name: index_wallets_on_billing_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_billing_entity_id ON public.wallets USING btree (billing_entity_id);


--
-- Name: index_wallets_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_customer_id ON public.wallets USING btree (customer_id);


--
-- Name: index_wallets_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_organization_id ON public.wallets USING btree (organization_id);


--
-- Name: index_wallets_on_organization_id_and_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_organization_id_and_customer_id ON public.wallets USING btree (organization_id, customer_id);


--
-- Name: index_wallets_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_payment_method_id ON public.wallets USING btree (payment_method_id);


--
-- Name: index_wallets_on_ready_to_be_refreshed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wallets_on_ready_to_be_refreshed ON public.wallets USING btree (ready_to_be_refreshed) WHERE ready_to_be_refreshed;


--
-- Name: index_webhook_endpoints_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_endpoints_on_organization_id ON public.webhook_endpoints USING btree (organization_id);


--
-- Name: index_webhook_endpoints_on_webhook_url_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_webhook_endpoints_on_webhook_url_and_organization_id ON public.webhook_endpoints USING btree (webhook_url, organization_id);


--
-- Name: index_webhooks_for_query; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_for_query ON public.webhooks USING btree (organization_id, webhook_endpoint_id, webhook_type, updated_at);


--
-- Name: index_webhooks_on_endpoint_and_timestamps; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_endpoint_and_timestamps ON public.webhooks USING btree (webhook_endpoint_id, updated_at, created_at);


--
-- Name: index_webhooks_on_endpoint_status_and_timestamps; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_endpoint_status_and_timestamps ON public.webhooks USING btree (webhook_endpoint_id, status, updated_at);


--
-- Name: index_webhooks_on_object_type_and_object_id_and_webhook_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_object_type_and_object_id_and_webhook_type ON public.webhooks USING btree (object_type, object_id, webhook_type);


--
-- Name: index_webhooks_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_organization_id ON public.webhooks USING btree (organization_id);


--
-- Name: index_webhooks_on_updated_at_for_cleanup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_updated_at_for_cleanup ON public.webhooks USING btree (updated_at) INCLUDE (id);


--
-- Name: index_webhooks_on_webhook_endpoint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_webhook_endpoint_id ON public.webhooks USING btree (webhook_endpoint_id);


--
-- Name: index_wt_invoice_custom_sections_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_wt_invoice_custom_sections_unique ON public.wallet_transactions_invoice_custom_sections USING btree (wallet_transaction_id, invoice_custom_section_id);


--
-- Name: unique_default_payment_method_per_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_default_payment_method_per_customer ON public.payment_methods USING btree (customer_id) WHERE ((is_default = true) AND (deleted_at IS NULL));


--
-- Name: enriched_events_default_event_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_enriched_events_on_event_id ATTACH PARTITION public.enriched_events_default_event_id_idx;


--
-- Name: enriched_events_default_organization_id_external_subscript_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_unique_on_enriched_events ATTACH PARTITION public.enriched_events_default_organization_id_external_subscript_idx1;


--
-- Name: enriched_events_default_organization_id_external_subscripti_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_lookup_on_enriched_events ATTACH PARTITION public.enriched_events_default_organization_id_external_subscripti_idx;


--
-- Name: enriched_events_default_organization_id_subscription_id_cha_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_billing_on_enriched_events ATTACH PARTITION public.enriched_events_default_organization_id_subscription_id_cha_idx;


--
-- Name: billable_metrics_grouped_charges _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.billable_metrics_grouped_charges AS
 SELECT billable_metrics.organization_id,
    billable_metrics.code,
    billable_metrics.aggregation_type,
    billable_metrics.field_name,
    charges.plan_id,
    charges.id AS charge_id,
    charges.pay_in_advance,
        CASE
            WHEN (charges.charge_model = 0) THEN (charges.properties -> 'grouped_by'::text)
            ELSE NULL::jsonb
        END AS grouped_by,
    charge_filters.id AS charge_filter_id,
    json_object_agg(billable_metric_filters.key, COALESCE(charge_filter_values."values", '{}'::character varying[]) ORDER BY billable_metric_filters.key) FILTER (WHERE (billable_metric_filters.key IS NOT NULL)) AS filters,
        CASE
            WHEN (charges.charge_model = 0) THEN (charge_filters.properties -> 'grouped_by'::text)
            ELSE NULL::jsonb
        END AS filters_grouped_by
   FROM ((((public.billable_metrics
     JOIN public.charges ON ((charges.billable_metric_id = billable_metrics.id)))
     LEFT JOIN public.charge_filters ON ((charge_filters.charge_id = charges.id)))
     LEFT JOIN public.charge_filter_values ON ((charge_filter_values.charge_filter_id = charge_filters.id)))
     LEFT JOIN public.billable_metric_filters ON ((charge_filter_values.billable_metric_filter_id = billable_metric_filters.id)))
  WHERE ((billable_metrics.deleted_at IS NULL) AND (charges.deleted_at IS NULL) AND (charge_filters.deleted_at IS NULL) AND (charge_filter_values.deleted_at IS NULL) AND (billable_metric_filters.deleted_at IS NULL))
  GROUP BY billable_metrics.organization_id, billable_metrics.code, billable_metrics.aggregation_type, billable_metrics.field_name, charges.plan_id, charges.id, charge_filters.id;


--
-- Name: flat_filters _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.flat_filters AS
 SELECT billable_metrics.organization_id,
    billable_metrics.code AS billable_metric_code,
    charges.plan_id,
    charges.id AS charge_id,
    charges.updated_at AS charge_updated_at,
    charge_filters.id AS charge_filter_id,
    charge_filters.updated_at AS charge_filter_updated_at,
        CASE
            WHEN (charge_filters.id IS NOT NULL) THEN jsonb_object_agg(COALESCE(billable_metric_filters.key, ''::character varying),
            CASE
                WHEN ((charge_filter_values."values")::text[] && ARRAY['__ALL_FILTER_VALUES__'::text]) THEN billable_metric_filters."values"
                ELSE charge_filter_values."values"
            END)
            ELSE NULL::jsonb
        END AS filters,
    (COALESCE(charge_filters.properties, charges.properties) -> 'pricing_group_keys'::text) AS pricing_group_keys,
    charges.pay_in_advance,
    charges.accepts_target_wallet
   FROM ((((public.billable_metrics
     JOIN public.charges ON ((charges.billable_metric_id = billable_metrics.id)))
     LEFT JOIN public.charge_filters ON (((charge_filters.charge_id = charges.id) AND (charge_filters.deleted_at IS NULL))))
     LEFT JOIN public.charge_filter_values ON (((charge_filter_values.charge_filter_id = charge_filters.id) AND (charge_filter_values.deleted_at IS NULL))))
     LEFT JOIN public.billable_metric_filters ON (((billable_metric_filters.id = charge_filter_values.billable_metric_filter_id) AND (billable_metric_filters.deleted_at IS NULL))))
  WHERE ((billable_metrics.deleted_at IS NULL) AND (charges.deleted_at IS NULL))
  GROUP BY billable_metrics.organization_id, billable_metrics.code, charges.plan_id, charges.id, charges.updated_at, charge_filters.id, charge_filters.updated_at;


--
-- Name: payment_receipts before_payment_receipt_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER before_payment_receipt_insert BEFORE INSERT ON public.payment_receipts FOR EACH ROW EXECUTE FUNCTION public.set_payment_receipt_number();


--
-- Name: roles ensure_consistency; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ensure_consistency BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.ensure_role_consistency();


--
-- Name: payment_methods fk_rails_00e7a45b0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT fk_rails_00e7a45b0b FOREIGN KEY (payment_provider_id) REFERENCES public.payment_providers(id);


--
-- Name: pending_vies_checks fk_rails_019e2289e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_vies_checks
    ADD CONSTRAINT fk_rails_019e2289e5 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: wallet_transactions fk_rails_01a4c0c7db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_01a4c0c7db FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: invoice_settlements fk_rails_04388258ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT fk_rails_04388258ff FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscription_fixed_charge_units_overrides fk_rails_0480ef4ad3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_fixed_charge_units_overrides
    ADD CONSTRAINT fk_rails_0480ef4ad3 FOREIGN KEY (fixed_charge_id) REFERENCES public.fixed_charges(id);


--
-- Name: invoices fk_rails_06b7046ec3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_06b7046ec3 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: billing_entities_taxes fk_rails_07b21049f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_taxes
    ADD CONSTRAINT fk_rails_07b21049f2 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: fees fk_rails_085d1cc97b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_085d1cc97b FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: enriched_store_subscription_migrations fk_rails_08d9dce6d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_subscription_migrations
    ADD CONSTRAINT fk_rails_08d9dce6d1 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: add_ons_taxes fk_rails_08dfe87131; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons_taxes
    ADD CONSTRAINT fk_rails_08dfe87131 FOREIGN KEY (add_on_id) REFERENCES public.add_ons(id);


--
-- Name: fees fk_rails_0934890b24; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_0934890b24 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: usage_monitoring_triggered_alerts fk_rails_0baa7bd751; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_triggered_alerts
    ADD CONSTRAINT fk_rails_0baa7bd751 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: coupon_targets fk_rails_0bb6dcc01f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_targets
    ADD CONSTRAINT fk_rails_0bb6dcc01f FOREIGN KEY (coupon_id) REFERENCES public.coupons(id);


--
-- Name: entitlement_entitlements fk_rails_0c9773c34d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlements
    ADD CONSTRAINT fk_rails_0c9773c34d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: customers_taxes fk_rails_0d2be3d72c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_taxes
    ADD CONSTRAINT fk_rails_0d2be3d72c FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: invoices fk_rails_0d349e632f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_0d349e632f FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: ai_conversations fk_rails_0da056ac92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT fk_rails_0da056ac92 FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: integration_customers fk_rails_0e464363cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_customers
    ADD CONSTRAINT fk_rails_0e464363cb FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: integration_mappings fk_rails_0f762162b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_mappings
    ADD CONSTRAINT fk_rails_0f762162b0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_monitoring_triggered_alerts fk_rails_0f807322b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_triggered_alerts
    ADD CONSTRAINT fk_rails_0f807322b1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: fees_taxes fk_rails_103e187859; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees_taxes
    ADD CONSTRAINT fk_rails_103e187859 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applied_invoice_custom_sections fk_rails_10428ecad2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_invoice_custom_sections
    ADD CONSTRAINT fk_rails_10428ecad2 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: quote_versions fk_rails_10ee148d0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_versions
    ADD CONSTRAINT fk_rails_10ee148d0d FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: entitlement_subscription_feature_removals fk_rails_123667657c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_feature_removals
    ADD CONSTRAINT fk_rails_123667657c FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: daily_usages fk_rails_12d29bc654; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_usages
    ADD CONSTRAINT fk_rails_12d29bc654 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: invoices_taxes fk_rails_142809fee1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_taxes
    ADD CONSTRAINT fk_rails_142809fee1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: coupon_targets fk_rails_1454058c96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_targets
    ADD CONSTRAINT fk_rails_1454058c96 FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id);


--
-- Name: invoice_subscriptions fk_rails_150139409e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_subscriptions
    ADD CONSTRAINT fk_rails_150139409e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: entitlement_entitlements fk_rails_173327f0dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlements
    ADD CONSTRAINT fk_rails_173327f0dc FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: quote_owners fk_rails_1811b32fcd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_owners
    ADD CONSTRAINT fk_rails_1811b32fcd FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: coupon_targets fk_rails_189f2a3949; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_targets
    ADD CONSTRAINT fk_rails_189f2a3949 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: customer_metadata fk_rails_195153290d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_metadata
    ADD CONSTRAINT fk_rails_195153290d FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: billing_entities_invoice_custom_sections fk_rails_19c47827ba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_invoice_custom_sections
    ADD CONSTRAINT fk_rails_19c47827ba FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: applied_usage_thresholds fk_rails_1d112bf8a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_usage_thresholds
    ADD CONSTRAINT fk_rails_1d112bf8a0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credits fk_rails_1db0057d9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_1db0057d9b FOREIGN KEY (applied_coupon_id) REFERENCES public.applied_coupons(id);


--
-- Name: webhooks fk_rails_20cc0de4c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT fk_rails_20cc0de4c7 FOREIGN KEY (webhook_endpoint_id) REFERENCES public.webhook_endpoints(id);


--
-- Name: customers_invoice_custom_sections fk_rails_20f157fa49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_invoice_custom_sections
    ADD CONSTRAINT fk_rails_20f157fa49 FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: plans fk_rails_216ac8a975; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT fk_rails_216ac8a975 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: webhook_endpoints fk_rails_21808fa528; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT fk_rails_21808fa528 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: cached_aggregations fk_rails_21eb389927; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cached_aggregations
    ADD CONSTRAINT fk_rails_21eb389927 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: commitments_taxes fk_rails_2259c88f26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments_taxes
    ADD CONSTRAINT fk_rails_2259c88f26 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoices_taxes fk_rails_22af6c6d28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_taxes
    ADD CONSTRAINT fk_rails_22af6c6d28 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: applied_pricing_units fk_rails_22bb2c0770; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_pricing_units
    ADD CONSTRAINT fk_rails_22bb2c0770 FOREIGN KEY (pricing_unit_id) REFERENCES public.pricing_units(id);


--
-- Name: taxes fk_rails_23975f5a47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxes
    ADD CONSTRAINT fk_rails_23975f5a47 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoices_payment_requests fk_rails_2496c105ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_payment_requests
    ADD CONSTRAINT fk_rails_2496c105ed FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_notes_taxes fk_rails_25232a0ec3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes_taxes
    ADD CONSTRAINT fk_rails_25232a0ec3 FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: refunds fk_rails_25267b0e17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_25267b0e17 FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: invoice_settlements fk_rails_2539663124; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT fk_rails_2539663124 FOREIGN KEY (source_payment_id) REFERENCES public.payments(id);


--
-- Name: adjusted_fees fk_rails_2561c00887; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_2561c00887 FOREIGN KEY (fee_id) REFERENCES public.fees(id);


--
-- Name: fees fk_rails_257af22645; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_257af22645 FOREIGN KEY (true_up_parent_fee_id) REFERENCES public.fees(id);


--
-- Name: billing_entities_taxes fk_rails_268c288aaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_taxes
    ADD CONSTRAINT fk_rails_268c288aaa FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: payment_providers fk_rails_26be2f764d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_providers
    ADD CONSTRAINT fk_rails_26be2f764d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charge_filters fk_rails_27b55b8574; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filters
    ADD CONSTRAINT fk_rails_27b55b8574 FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: wallets fk_rails_28077d4aa2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT fk_rails_28077d4aa2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_thresholds fk_rails_2908dd8de5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_thresholds
    ADD CONSTRAINT fk_rails_2908dd8de5 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: wallets fk_rails_2b35eef34b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT fk_rails_2b35eef34b FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: ai_conversations fk_rails_2c06a74f41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT fk_rails_2c06a74f41 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: refunds fk_rails_2dc6171f57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_2dc6171f57 FOREIGN KEY (payment_provider_id) REFERENCES public.payment_providers(id);


--
-- Name: fees fk_rails_2ea4db3a4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_2ea4db3a4c FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: payment_requests fk_rails_2fb2147151; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_requests
    ADD CONSTRAINT fk_rails_2fb2147151 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: credits fk_rails_2fd7ee65e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_2fd7ee65e6 FOREIGN KEY (progressive_billing_invoice_id) REFERENCES public.invoices(id);


--
-- Name: invoice_settlements fk_rails_2ffeff5323; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT fk_rails_2ffeff5323 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: wallets_invoice_custom_sections fk_rails_3092f5f2e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets_invoice_custom_sections
    ADD CONSTRAINT fk_rails_3092f5f2e0 FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: invoices fk_rails_309d3a4412; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_309d3a4412 FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: credits fk_rails_310fcb3585; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_310fcb3585 FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: payment_requests fk_rails_32600e5a72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_requests
    ADD CONSTRAINT fk_rails_32600e5a72 FOREIGN KEY (dunning_campaign_id) REFERENCES public.dunning_campaigns(id);


--
-- Name: customers_taxes fk_rails_33d169382f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_taxes
    ADD CONSTRAINT fk_rails_33d169382f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifetime_usages fk_rails_348acbd245; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifetime_usages
    ADD CONSTRAINT fk_rails_348acbd245 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: fees fk_rails_34ab152115; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_34ab152115 FOREIGN KEY (applied_add_on_id) REFERENCES public.applied_add_ons(id);


--
-- Name: wallets_invoice_custom_sections fk_rails_34b4e489e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets_invoice_custom_sections
    ADD CONSTRAINT fk_rails_34b4e489e6 FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: groups fk_rails_34b5ee1894; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT fk_rails_34b5ee1894 FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id) ON DELETE CASCADE;


--
-- Name: charge_filter_values fk_rails_3640b4a66a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filter_values
    ADD CONSTRAINT fk_rails_3640b4a66a FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscriptions fk_rails_364213cc3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_364213cc3e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: inbound_webhooks fk_rails_36cda06530; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inbound_webhooks
    ADD CONSTRAINT fk_rails_36cda06530 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quantified_events fk_rails_3926855f12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quantified_events
    ADD CONSTRAINT fk_rails_3926855f12 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: invoices fk_rails_3a303bf667; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_3a303bf667 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: payments fk_rails_3ab959bfc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_3ab959bfc4 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: group_properties fk_rails_3acf9e789c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_properties
    ADD CONSTRAINT fk_rails_3acf9e789c FOREIGN KEY (charge_id) REFERENCES public.charges(id) ON DELETE CASCADE;


--
-- Name: invoice_settlements fk_rails_3b7dad8e9c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT fk_rails_3b7dad8e9c FOREIGN KEY (target_invoice_id) REFERENCES public.invoices(id);


--
-- Name: wallet_transaction_consumptions fk_rails_3c786cd3e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction_consumptions
    ADD CONSTRAINT fk_rails_3c786cd3e3 FOREIGN KEY (inbound_wallet_transaction_id) REFERENCES public.wallet_transactions(id);


--
-- Name: daily_usages fk_rails_3c7c3920c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_usages
    ADD CONSTRAINT fk_rails_3c7c3920c0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charges fk_rails_3cfe1d68d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_3cfe1d68d7 FOREIGN KEY (parent_id) REFERENCES public.charges(id);


--
-- Name: integration_collection_mappings fk_rails_3d568ff9de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_collection_mappings
    ADD CONSTRAINT fk_rails_3d568ff9de FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: orders fk_rails_3dad120da9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_3dad120da9 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: entitlement_privileges fk_rails_3e4df02771; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_privileges
    ADD CONSTRAINT fk_rails_3e4df02771 FOREIGN KEY (entitlement_feature_id) REFERENCES public.entitlement_features(id);


--
-- Name: invoices_payment_requests fk_rails_3ec3563cf3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_payment_requests
    ADD CONSTRAINT fk_rails_3ec3563cf3 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: refunds fk_rails_3f7be5debc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_3f7be5debc FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: charges_taxes fk_rails_3ff27d7624; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges_taxes
    ADD CONSTRAINT fk_rails_3ff27d7624 FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: credit_notes fk_rails_41088c7d45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_41088c7d45 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_notes fk_rails_4117574b51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_4117574b51 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: quote_owners fk_rails_45230f8485; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_owners
    ADD CONSTRAINT fk_rails_45230f8485 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: integration_items fk_rails_47d8081062; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_items
    ADD CONSTRAINT fk_rails_47d8081062 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: webhooks fk_rails_49212d501e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT fk_rails_49212d501e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charges fk_rails_4934f27a06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_4934f27a06 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: recurring_transaction_rules_invoice_custom_sections fk_rails_49fcc221b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules_invoice_custom_sections
    ADD CONSTRAINT fk_rails_49fcc221b0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: billing_entities fk_rails_4aa58496c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities
    ADD CONSTRAINT fk_rails_4aa58496c3 FOREIGN KEY (applied_dunning_campaign_id) REFERENCES public.dunning_campaigns(id) ON DELETE SET NULL;


--
-- Name: order_forms fk_rails_4ed54bfec0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_forms
    ADD CONSTRAINT fk_rails_4ed54bfec0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallets fk_rails_4ff087c52e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT fk_rails_4ff087c52e FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id) NOT VALID;


--
-- Name: payment_provider_customers fk_rails_50d46d3679; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_provider_customers
    ADD CONSTRAINT fk_rails_50d46d3679 FOREIGN KEY (payment_provider_id) REFERENCES public.payment_providers(id);


--
-- Name: billable_metric_filters fk_rails_51077e7c0e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billable_metric_filters
    ADD CONSTRAINT fk_rails_51077e7c0e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: commitments fk_rails_51ac39a0c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments
    ADD CONSTRAINT fk_rails_51ac39a0c6 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: credits fk_rails_521b5240ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_521b5240ed FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: recurring_transaction_rules fk_rails_52370612ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules
    ADD CONSTRAINT fk_rails_52370612ae FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: password_resets fk_rails_526379cd99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_resets
    ADD CONSTRAINT fk_rails_526379cd99 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: applied_usage_thresholds fk_rails_52b72c9b0e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_usage_thresholds
    ADD CONSTRAINT fk_rails_52b72c9b0e FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: entitlement_entitlement_values fk_rails_533b639bac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlement_values
    ADD CONSTRAINT fk_rails_533b639bac FOREIGN KEY (entitlement_entitlement_id) REFERENCES public.entitlement_entitlements(id);


--
-- Name: credits fk_rails_5628a713de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_5628a713de FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscriptions fk_rails_56b3626631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_56b3626631 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id) NOT VALID;


--
-- Name: charges_taxes fk_rails_56b7167125; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges_taxes
    ADD CONSTRAINT fk_rails_56b7167125 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: customers fk_rails_58234c715e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_58234c715e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: data_exports fk_rails_5a43da571b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_exports
    ADD CONSTRAINT fk_rails_5a43da571b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoice_settlements fk_rails_5a4b906a16; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_settlements
    ADD CONSTRAINT fk_rails_5a4b906a16 FOREIGN KEY (source_credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: add_ons_taxes fk_rails_5ade8984b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons_taxes
    ADD CONSTRAINT fk_rails_5ade8984b1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quotes fk_rails_5bb40a7bae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_5bb40a7bae FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: error_details fk_rails_5c21eece29; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_details
    ADD CONSTRAINT fk_rails_5c21eece29 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: payment_receipts fk_rails_5c2e0b6d34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receipts
    ADD CONSTRAINT fk_rails_5c2e0b6d34 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_note_items fk_rails_5cb2f24c3d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_items
    ADD CONSTRAINT fk_rails_5cb2f24c3d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_notes fk_rails_5cb67dee79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes
    ADD CONSTRAINT fk_rails_5cb67dee79 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: fixed_charges fk_rails_5e06da3c18; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges
    ADD CONSTRAINT fk_rails_5e06da3c18 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: recurring_transaction_rules fk_rails_5efea6fe31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules
    ADD CONSTRAINT fk_rails_5efea6fe31 FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id) NOT VALID;


--
-- Name: fees fk_rails_6023b3f2dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_6023b3f2dd FOREIGN KEY (add_on_id) REFERENCES public.add_ons(id);


--
-- Name: credit_notes_taxes fk_rails_626209b8d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes_taxes
    ADD CONSTRAINT fk_rails_626209b8d2 FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: order_forms fk_rails_6298debfc7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_forms
    ADD CONSTRAINT fk_rails_6298debfc7 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: payments fk_rails_62d18ea517; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_62d18ea517 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: invoice_metadata fk_rails_63683837a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_metadata
    ADD CONSTRAINT fk_rails_63683837a2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applied_invoice_custom_sections fk_rails_63ac282e70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_invoice_custom_sections
    ADD CONSTRAINT fk_rails_63ac282e70 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: pricing_unit_usages fk_rails_63ca8e33c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_unit_usages
    ADD CONSTRAINT fk_rails_63ca8e33c5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscriptions fk_rails_63d3df128b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_63d3df128b FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: memberships fk_rails_64267aab58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_64267aab58 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: membership_roles fk_rails_65053e240e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_roles
    ADD CONSTRAINT fk_rails_65053e240e FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: integration_collection_mappings fk_rails_650fccfc41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_collection_mappings
    ADD CONSTRAINT fk_rails_650fccfc41 FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id) ON DELETE CASCADE;


--
-- Name: billing_entities_taxes fk_rails_651eadaaa4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_taxes
    ADD CONSTRAINT fk_rails_651eadaaa4 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: fixed_charges_taxes fk_rails_665ae33492; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges_taxes
    ADD CONSTRAINT fk_rails_665ae33492 FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: subscriptions fk_rails_66eb6b32c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_66eb6b32c1 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: integration_resources fk_rails_67d4eb3c92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_resources
    ADD CONSTRAINT fk_rails_67d4eb3c92 FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: customers_invoice_custom_sections fk_rails_68754484c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_invoice_custom_sections
    ADD CONSTRAINT fk_rails_68754484c0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: billing_entities_invoice_custom_sections fk_rails_699cd1384f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_invoice_custom_sections
    ADD CONSTRAINT fk_rails_699cd1384f FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: dunning_campaigns fk_rails_6c720a8ccd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dunning_campaigns
    ADD CONSTRAINT fk_rails_6c720a8ccd FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: adjusted_fees fk_rails_6d465e6b10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_6d465e6b10 FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: invoices_taxes fk_rails_6e148ccbb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_taxes
    ADD CONSTRAINT fk_rails_6e148ccbb1 FOREIGN KEY (tax_id) REFERENCES public.taxes(id) ON DELETE SET NULL;


--
-- Name: pending_vies_checks fk_rails_6e238f3bfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_vies_checks
    ADD CONSTRAINT fk_rails_6e238f3bfc FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: subscriptions_invoice_custom_sections fk_rails_6eb8abe6cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_6eb8abe6cb FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_monitoring_alert_thresholds fk_rails_710f37148d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alert_thresholds
    ADD CONSTRAINT fk_rails_710f37148d FOREIGN KEY (usage_monitoring_alert_id) REFERENCES public.usage_monitoring_alerts(id);


--
-- Name: data_exports fk_rails_73d83e23b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_exports
    ADD CONSTRAINT fk_rails_73d83e23b6 FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: fees_taxes fk_rails_745b4ca7dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees_taxes
    ADD CONSTRAINT fk_rails_745b4ca7dd FOREIGN KEY (fee_id) REFERENCES public.fees(id);


--
-- Name: fixed_charge_events fk_rails_752665cc51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charge_events
    ADD CONSTRAINT fk_rails_752665cc51 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: refunds fk_rails_75577c354e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_75577c354e FOREIGN KEY (payment_provider_customer_id) REFERENCES public.payment_provider_customers(id);


--
-- Name: integrations fk_rails_755d734f25; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT fk_rails_755d734f25 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: commitments fk_rails_76ceb88c74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments
    ADD CONSTRAINT fk_rails_76ceb88c74 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: quote_owners fk_rails_7734750af9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_owners
    ADD CONSTRAINT fk_rails_7734750af9 FOREIGN KEY (quote_id) REFERENCES public.quotes(id);


--
-- Name: fees fk_rails_775eb0ecd8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_775eb0ecd8 FOREIGN KEY (original_fee_id) REFERENCES public.fees(id);


--
-- Name: refunds fk_rails_778360c382; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_778360c382 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_notes_taxes fk_rails_77f2d4440d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_notes_taxes
    ADD CONSTRAINT fk_rails_77f2d4440d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: groups fk_rails_7886e1bc34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT fk_rails_7886e1bc34 FOREIGN KEY (parent_group_id) REFERENCES public.groups(id);


--
-- Name: wallet_transactions fk_rails_78f6642ddf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_78f6642ddf FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applied_add_ons fk_rails_7995206484; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_add_ons
    ADD CONSTRAINT fk_rails_7995206484 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: billable_metric_filters fk_rails_7a0704ce72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billable_metric_filters
    ADD CONSTRAINT fk_rails_7a0704ce72 FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id);


--
-- Name: api_keys fk_rails_7aab96f30e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_7aab96f30e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: adjusted_fees fk_rails_7b324610ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_7b324610ad FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: invoice_custom_sections fk_rails_7c0e340dbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_custom_sections
    ADD CONSTRAINT fk_rails_7c0e340dbd FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscriptions_invoice_custom_sections fk_rails_7c63dd13f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_7c63dd13f0 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: wallet_targets fk_rails_7d0e61668f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_targets
    ADD CONSTRAINT fk_rails_7d0e61668f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charge_filter_values fk_rails_7da558cadc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filter_values
    ADD CONSTRAINT fk_rails_7da558cadc FOREIGN KEY (charge_filter_id) REFERENCES public.charge_filters(id);


--
-- Name: billable_metrics fk_rails_7e8a2f26e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billable_metrics
    ADD CONSTRAINT fk_rails_7e8a2f26e5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charges fk_rails_7eb0484711; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_7eb0484711 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: entitlement_features fk_rails_81d8b323cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_features
    ADD CONSTRAINT fk_rails_81d8b323cf FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: add_ons fk_rails_81e3b6abba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons
    ADD CONSTRAINT fk_rails_81e3b6abba FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallet_targets fk_rails_81eedc32c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_targets
    ADD CONSTRAINT fk_rails_81eedc32c0 FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: payment_methods fk_rails_84a67e8b40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT fk_rails_84a67e8b40 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: payments fk_rails_84f4587409; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_84f4587409 FOREIGN KEY (payment_provider_id) REFERENCES public.payment_providers(id);


--
-- Name: wallet_transaction_consumptions fk_rails_85b9e72931; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction_consumptions
    ADD CONSTRAINT fk_rails_85b9e72931 FOREIGN KEY (outbound_wallet_transaction_id) REFERENCES public.wallet_transactions(id);


--
-- Name: payment_provider_customers fk_rails_86676be631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_provider_customers
    ADD CONSTRAINT fk_rails_86676be631 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: wallets_invoice_custom_sections fk_rails_87bc3bd4cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets_invoice_custom_sections
    ADD CONSTRAINT fk_rails_87bc3bd4cb FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoice_subscriptions fk_rails_88349fc20a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_subscriptions
    ADD CONSTRAINT fk_rails_88349fc20a FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: adjusted_fees fk_rails_885dc100ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_885dc100ef FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: entitlement_entitlement_values fk_rails_8887954ec7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlement_values
    ADD CONSTRAINT fk_rails_8887954ec7 FOREIGN KEY (entitlement_privilege_id) REFERENCES public.entitlement_privileges(id);


--
-- Name: add_ons_taxes fk_rails_89e1020aca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.add_ons_taxes
    ADD CONSTRAINT fk_rails_89e1020aca FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: invoice_metadata fk_rails_8bb5b094c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_metadata
    ADD CONSTRAINT fk_rails_8bb5b094c4 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: fixed_charges_taxes fk_rails_8c09ee2428; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges_taxes
    ADD CONSTRAINT fk_rails_8c09ee2428 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_monitoring_alerts fk_rails_8c18828b53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alerts
    ADD CONSTRAINT fk_rails_8c18828b53 FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id);


--
-- Name: usage_thresholds fk_rails_8df9bf2b6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_thresholds
    ADD CONSTRAINT fk_rails_8df9bf2b6c FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applied_pricing_units fk_rails_8e0c3d0c5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_pricing_units
    ADD CONSTRAINT fk_rails_8e0c3d0c5b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: commitments_taxes fk_rails_8fa6f0d920; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments_taxes
    ADD CONSTRAINT fk_rails_8fa6f0d920 FOREIGN KEY (commitment_id) REFERENCES public.commitments(id);


--
-- Name: fixed_charge_events fk_rails_90302b3ca3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charge_events
    ADD CONSTRAINT fk_rails_90302b3ca3 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: data_export_parts fk_rails_909197908c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_parts
    ADD CONSTRAINT fk_rails_909197908c FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoice_subscriptions fk_rails_90d93bd016; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_subscriptions
    ADD CONSTRAINT fk_rails_90d93bd016 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: adjusted_fees fk_rails_91802dc891; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_91802dc891 FOREIGN KEY (fixed_charge_id) REFERENCES public.fixed_charges(id) NOT VALID;


--
-- Name: data_export_parts fk_rails_9298b8fdad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_parts
    ADD CONSTRAINT fk_rails_9298b8fdad FOREIGN KEY (data_export_id) REFERENCES public.data_exports(id);


--
-- Name: customers fk_rails_94cc21031f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_94cc21031f FOREIGN KEY (applied_dunning_campaign_id) REFERENCES public.dunning_campaigns(id);


--
-- Name: entitlement_subscription_feature_removals fk_rails_95df3194c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_feature_removals
    ADD CONSTRAINT fk_rails_95df3194c5 FOREIGN KEY (entitlement_privilege_id) REFERENCES public.entitlement_privileges(id);


--
-- Name: pending_vies_checks fk_rails_96fc54cd9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_vies_checks
    ADD CONSTRAINT fk_rails_96fc54cd9a FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: fixed_charge_events fk_rails_9881e28151; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charge_events
    ADD CONSTRAINT fk_rails_9881e28151 FOREIGN KEY (fixed_charge_id) REFERENCES public.fixed_charges(id);


--
-- Name: adjusted_fees fk_rails_98980b326b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_98980b326b FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: applied_usage_thresholds fk_rails_9c08b43701; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_usage_thresholds
    ADD CONSTRAINT fk_rails_9c08b43701 FOREIGN KEY (usage_threshold_id) REFERENCES public.usage_thresholds(id);


--
-- Name: plans_taxes fk_rails_9c704027e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans_taxes
    ADD CONSTRAINT fk_rails_9c704027e2 FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: applied_add_ons fk_rails_9c8e276cc0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_add_ons
    ADD CONSTRAINT fk_rails_9c8e276cc0 FOREIGN KEY (add_on_id) REFERENCES public.add_ons(id);


--
-- Name: usage_monitoring_alerts fk_rails_9d8812945e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alerts
    ADD CONSTRAINT fk_rails_9d8812945e FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: wallet_transactions_invoice_custom_sections fk_rails_9e3f99b7a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_9e3f99b7a2 FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: wallet_transactions fk_rails_9ea6759859; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_9ea6759859 FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: credit_note_items fk_rails_9f22076477; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_items
    ADD CONSTRAINT fk_rails_9f22076477 FOREIGN KEY (credit_note_id) REFERENCES public.credit_notes(id);


--
-- Name: quotes fk_rails_a1ab65f1f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_a1ab65f1f7 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: group_properties fk_rails_a2d2cb3819; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_properties
    ADD CONSTRAINT fk_rails_a2d2cb3819 FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: charges fk_rails_a710519346; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_a710519346 FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id);


--
-- Name: recurring_transaction_rules_invoice_custom_sections fk_rails_a7f20c73bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules_invoice_custom_sections
    ADD CONSTRAINT fk_rails_a7f20c73bb FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: integration_items fk_rails_a9dc2ea536; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_items
    ADD CONSTRAINT fk_rails_a9dc2ea536 FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: fixed_charges fk_rails_aa04ceacf6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges
    ADD CONSTRAINT fk_rails_aa04ceacf6 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: entitlement_entitlement_values fk_rails_aa34dd5db6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlement_values
    ADD CONSTRAINT fk_rails_aa34dd5db6 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: commitments_taxes fk_rails_aaa12f7d3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commitments_taxes
    ADD CONSTRAINT fk_rails_aaa12f7d3e FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: usage_monitoring_subscription_activities fk_rails_ab16de0b32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_subscription_activities
    ADD CONSTRAINT fk_rails_ab16de0b32 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: charges_taxes fk_rails_ac146c9541; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges_taxes
    ADD CONSTRAINT fk_rails_ac146c9541 FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: pricing_unit_usages fk_rails_aea6422e6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_unit_usages
    ADD CONSTRAINT fk_rails_aea6422e6a FOREIGN KEY (fee_id) REFERENCES public.fees(id);


--
-- Name: daily_usages fk_rails_b07fc711f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_usages
    ADD CONSTRAINT fk_rails_b07fc711f7 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: billing_entities_invoice_custom_sections fk_rails_b283a89721; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities_invoice_custom_sections
    ADD CONSTRAINT fk_rails_b283a89721 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: entitlement_subscription_feature_removals fk_rails_b3864df641; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_feature_removals
    ADD CONSTRAINT fk_rails_b3864df641 FOREIGN KEY (entitlement_feature_id) REFERENCES public.entitlement_features(id);


--
-- Name: fees fk_rails_b50dc82c1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_b50dc82c1e FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: entitlement_entitlements fk_rails_b61aa73940; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlements
    ADD CONSTRAINT fk_rails_b61aa73940 FOREIGN KEY (entitlement_feature_id) REFERENCES public.entitlement_features(id);


--
-- Name: orders fk_rails_b687c6e23a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_b687c6e23a FOREIGN KEY (order_form_id) REFERENCES public.order_forms(id);


--
-- Name: subscription_activation_rules fk_rails_b749d2045d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_activation_rules
    ADD CONSTRAINT fk_rails_b749d2045d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: presentation_breakdowns fk_rails_b8f3cabc8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presentation_breakdowns
    ADD CONSTRAINT fk_rails_b8f3cabc8e FOREIGN KEY (fee_id) REFERENCES public.fees(id);


--
-- Name: wallet_transactions_invoice_custom_sections fk_rails_b974dac270; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_b974dac270 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: lifetime_usages fk_rails_ba128983c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifetime_usages
    ADD CONSTRAINT fk_rails_ba128983c2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applied_coupons fk_rails_bacb46d2a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_coupons
    ADD CONSTRAINT fk_rails_bacb46d2a3 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: plans_taxes fk_rails_bacde7a063; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans_taxes
    ADD CONSTRAINT fk_rails_bacde7a063 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: wallet_transactions fk_rails_bcb5aecd6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_bcb5aecd6c FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id) NOT VALID;


--
-- Name: usage_monitoring_subscription_activities fk_rails_bda048a8d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_subscription_activities
    ADD CONSTRAINT fk_rails_bda048a8d9 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: dunning_campaign_thresholds fk_rails_bf1f386f75; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dunning_campaign_thresholds
    ADD CONSTRAINT fk_rails_bf1f386f75 FOREIGN KEY (dunning_campaign_id) REFERENCES public.dunning_campaigns(id);


--
-- Name: charge_filter_values fk_rails_bf661ef73d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filter_values
    ADD CONSTRAINT fk_rails_bf661ef73d FOREIGN KEY (billable_metric_filter_id) REFERENCES public.billable_metric_filters(id);


--
-- Name: customers fk_rails_bff25bb1bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_bff25bb1bb FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: enriched_store_migrations fk_rails_c04bd1a196; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_migrations
    ADD CONSTRAINT fk_rails_c04bd1a196 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallet_transactions fk_rails_c29bf4ff0f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_c29bf4ff0f FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id) NOT VALID;


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: pricing_unit_usages fk_rails_c545103d57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_unit_usages
    ADD CONSTRAINT fk_rails_c545103d57 FOREIGN KEY (pricing_unit_id) REFERENCES public.pricing_units(id);


--
-- Name: payment_methods fk_rails_c60c12efbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT fk_rails_c60c12efbd FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: customers_invoice_custom_sections fk_rails_c64033bcb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_invoice_custom_sections
    ADD CONSTRAINT fk_rails_c64033bcb0 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: invites fk_rails_c71f4b2026; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT fk_rails_c71f4b2026 FOREIGN KEY (membership_id) REFERENCES public.memberships(id);


--
-- Name: subscriptions_invoice_custom_sections fk_rails_c82f03a405; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_c82f03a405 FOREIGN KEY (invoice_custom_section_id) REFERENCES public.invoice_custom_sections(id);


--
-- Name: payment_methods fk_rails_c8606f586b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT fk_rails_c8606f586b FOREIGN KEY (payment_provider_customer_id) REFERENCES public.payment_provider_customers(id);


--
-- Name: entitlement_subscription_feature_removals fk_rails_c9183c59d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_subscription_feature_removals
    ADD CONSTRAINT fk_rails_c9183c59d9 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_thresholds fk_rails_caeb5a3949; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_thresholds
    ADD CONSTRAINT fk_rails_caeb5a3949 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: plans fk_rails_cbf700aeb8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT fk_rails_cbf700aeb8 FOREIGN KEY (parent_id) REFERENCES public.plans(id);


--
-- Name: integration_mappings fk_rails_cc318ad1ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_mappings
    ADD CONSTRAINT fk_rails_cc318ad1ff FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: pricing_units fk_rails_cd99351ee3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_units
    ADD CONSTRAINT fk_rails_cd99351ee3 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscription_fixed_charge_units_overrides fk_rails_cdaf36dc89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_fixed_charge_units_overrides
    ADD CONSTRAINT fk_rails_cdaf36dc89 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: integration_customers fk_rails_ce2c63d69f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_customers
    ADD CONSTRAINT fk_rails_ce2c63d69f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallet_transactions fk_rails_d07bc24ce3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_d07bc24ce3 FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: item_metadata fk_rails_d0b1714507; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_metadata
    ADD CONSTRAINT fk_rails_d0b1714507 FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: quote_versions fk_rails_d2d917b73a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quote_versions
    ADD CONSTRAINT fk_rails_d2d917b73a FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: payments fk_rails_d384ec1ebf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_d384ec1ebf FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id) NOT VALID;


--
-- Name: wallet_transaction_consumptions fk_rails_d4abfdb375; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction_consumptions
    ADD CONSTRAINT fk_rails_d4abfdb375 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: idempotency_records fk_rails_d4f02c82b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_records
    ADD CONSTRAINT fk_rails_d4f02c82b2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: entitlement_entitlements fk_rails_d53f825a88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_entitlements
    ADD CONSTRAINT fk_rails_d53f825a88 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: entitlement_privileges fk_rails_d648e28d9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entitlement_privileges
    ADD CONSTRAINT fk_rails_d648e28d9f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscription_fixed_charge_units_overrides fk_rails_d72a9877be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_fixed_charge_units_overrides
    ADD CONSTRAINT fk_rails_d72a9877be FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: wallets fk_rails_d9342a8ca7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT fk_rails_d9342a8ca7 FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id) NOT VALID;


--
-- Name: integration_resources fk_rails_d9448a540b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_resources
    ADD CONSTRAINT fk_rails_d9448a540b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_monitoring_alerts fk_rails_d9ea200904; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alerts
    ADD CONSTRAINT fk_rails_d9ea200904 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: fees fk_rails_d9ffb8b4a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_d9ffb8b4a1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: customers_invoice_custom_sections fk_rails_db9140d0fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_invoice_custom_sections
    ADD CONSTRAINT fk_rails_db9140d0fd FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id);


--
-- Name: enriched_store_subscription_migrations fk_rails_dc444f5f29; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_subscription_migrations
    ADD CONSTRAINT fk_rails_dc444f5f29 FOREIGN KEY (enriched_store_migration_id) REFERENCES public.enriched_store_migrations(id);


--
-- Name: invites fk_rails_dd342449a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT fk_rails_dd342449a6 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: coupon_targets fk_rails_de6b3c3138; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_targets
    ADD CONSTRAINT fk_rails_de6b3c3138 FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: quotes fk_rails_de7694c307; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT fk_rails_de7694c307 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: credit_note_items fk_rails_dea748e529; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_items
    ADD CONSTRAINT fk_rails_dea748e529 FOREIGN KEY (fee_id) REFERENCES public.fees(id);


--
-- Name: customer_metadata fk_rails_dfac602b2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_metadata
    ADD CONSTRAINT fk_rails_dfac602b2c FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: integration_collection_mappings fk_rails_e148d17c1f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_collection_mappings
    ADD CONSTRAINT fk_rails_e148d17c1f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: usage_monitoring_triggered_alerts fk_rails_e3cf54daac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_triggered_alerts
    ADD CONSTRAINT fk_rails_e3cf54daac FOREIGN KEY (usage_monitoring_alert_id) REFERENCES public.usage_monitoring_alerts(id);


--
-- Name: integration_mappings fk_rails_e4a58fbcac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_mappings
    ADD CONSTRAINT fk_rails_e4a58fbcac FOREIGN KEY (billing_entity_id) REFERENCES public.billing_entities(id) ON DELETE CASCADE;


--
-- Name: user_devices fk_rails_e700a96826; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT fk_rails_e700a96826 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: charge_filters fk_rails_e711e8089e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_filters
    ADD CONSTRAINT fk_rails_e711e8089e FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: subscriptions fk_rails_e744efbe51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_e744efbe51 FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id) NOT VALID;


--
-- Name: customers_taxes fk_rails_e86903e081; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers_taxes
    ADD CONSTRAINT fk_rails_e86903e081 FOREIGN KEY (tax_id) REFERENCES public.taxes(id);


--
-- Name: plans_taxes fk_rails_e88403f4b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans_taxes
    ADD CONSTRAINT fk_rails_e88403f4b9 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: recurring_transaction_rules fk_rails_e8bac9c5bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules
    ADD CONSTRAINT fk_rails_e8bac9c5bb FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: fixed_charges fk_rails_e95f72749e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges
    ADD CONSTRAINT fk_rails_e95f72749e FOREIGN KEY (add_on_id) REFERENCES public.add_ons(id);


--
-- Name: integration_customers fk_rails_ea80151038; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_customers
    ADD CONSTRAINT fk_rails_ea80151038 FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: fees fk_rails_eaca9421be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_eaca9421be FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: payment_provider_customers fk_rails_ecb466254b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_provider_customers
    ADD CONSTRAINT fk_rails_ecb466254b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: invoices_payment_requests fk_rails_ed387e0992; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices_payment_requests
    ADD CONSTRAINT fk_rails_ed387e0992 FOREIGN KEY (payment_request_id) REFERENCES public.payment_requests(id);


--
-- Name: usage_monitoring_triggered_alerts fk_rails_ee2b6f04d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_triggered_alerts
    ADD CONSTRAINT fk_rails_ee2b6f04d9 FOREIGN KEY (wallet_id) REFERENCES public.wallets(id);


--
-- Name: recurring_transaction_rules_invoice_custom_sections fk_rails_eeb6a32be1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transaction_rules_invoice_custom_sections
    ADD CONSTRAINT fk_rails_eeb6a32be1 FOREIGN KEY (recurring_transaction_rule_id) REFERENCES public.recurring_transaction_rules(id);


--
-- Name: usage_monitoring_alert_thresholds fk_rails_f18cd04d51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_monitoring_alert_thresholds
    ADD CONSTRAINT fk_rails_f18cd04d51 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: payment_requests fk_rails_f228550fda; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_requests
    ADD CONSTRAINT fk_rails_f228550fda FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: enriched_store_subscription_migrations fk_rails_f232478e56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enriched_store_subscription_migrations
    ADD CONSTRAINT fk_rails_f232478e56 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallet_transactions fk_rails_f32b205d44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_f32b205d44 FOREIGN KEY (voided_invoice_id) REFERENCES public.invoices(id);


--
-- Name: fees fk_rails_f375d320ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees
    ADD CONSTRAINT fk_rails_f375d320ad FOREIGN KEY (fixed_charge_id) REFERENCES public.fixed_charges(id);


--
-- Name: invoice_subscriptions fk_rails_f435d13904; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_subscriptions
    ADD CONSTRAINT fk_rails_f435d13904 FOREIGN KEY (regenerated_invoice_id) REFERENCES public.invoices(id) NOT VALID;


--
-- Name: quantified_events fk_rails_f510acb495; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quantified_events
    ADD CONSTRAINT fk_rails_f510acb495 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: payment_receipts fk_rails_f53ff93138; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receipts
    ADD CONSTRAINT fk_rails_f53ff93138 FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: billing_entities fk_rails_f66617edcb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_entities
    ADD CONSTRAINT fk_rails_f66617edcb FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: order_forms fk_rails_f94f882198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_forms
    ADD CONSTRAINT fk_rails_f94f882198 FOREIGN KEY (quote_version_id) REFERENCES public.quote_versions(id);


--
-- Name: fees_taxes fk_rails_f98413d404; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fees_taxes
    ADD CONSTRAINT fk_rails_f98413d404 FOREIGN KEY (tax_id) REFERENCES public.taxes(id) ON DELETE SET NULL;


--
-- Name: wallet_targets fk_rails_fbd2b9fccb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_targets
    ADD CONSTRAINT fk_rails_fbd2b9fccb FOREIGN KEY (billable_metric_id) REFERENCES public.billable_metrics(id);


--
-- Name: adjusted_fees fk_rails_fd399a23d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjusted_fees
    ADD CONSTRAINT fk_rails_fd399a23d3 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: subscription_activation_rules fk_rails_fd60209637; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_activation_rules
    ADD CONSTRAINT fk_rails_fd60209637 FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id);


--
-- Name: dunning_campaign_thresholds fk_rails_fd84cdb7c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dunning_campaign_thresholds
    ADD CONSTRAINT fk_rails_fd84cdb7c6 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: orders fk_rails_fe8af6535c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_fe8af6535c FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: fixed_charges_taxes fk_rails_fea16bf2e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_charges_taxes
    ADD CONSTRAINT fk_rails_fea16bf2e7 FOREIGN KEY (fixed_charge_id) REFERENCES public.fixed_charges(id);


--
-- Name: presentation_breakdowns fk_rails_ff548a9f4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presentation_breakdowns
    ADD CONSTRAINT fk_rails_ff548a9f4c FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: wallet_transactions_invoice_custom_sections fk_rails_ff75b29299; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transactions_invoice_custom_sections
    ADD CONSTRAINT fk_rails_ff75b29299 FOREIGN KEY (wallet_transaction_id) REFERENCES public.wallet_transactions(id);


--
-- Name: membership_roles membership_role_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_roles
    ADD CONSTRAINT membership_role_membership_fk FOREIGN KEY (membership_id, organization_id) REFERENCES public.memberships(id, organization_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260706173746'),
('20260703164249'),
('20260702074504'),
('20260701083110'),
('20260701083109'),
('20260701083108'),
('20260701083107'),
('20260625095837'),
('20260622113747'),
('20260619065327'),
('20260617145515'),
('20260617072554'),
('20260616160703'),
('20260616155032'),
('20260615181440'),
('20260612150749'),
('20260612113044'),
('20260611162947'),
('20260611145341'),
('20260611145039'),
('20260611122002'),
('20260609173731'),
('20260609165032'),
('20260609161044'),
('20260608111837'),
('20260608074112'),
('20260605170919'),
('20260604153307'),
('20260603121349'),
('20260602175438'),
('20260602092156'),
('20260601174030'),
('20260601120429'),
('20260601120428'),
('20260526142247'),
('20260526131452'),
('20260525102114'),
('20260520134318'),
('20260520075420'),
('20260518152858'),
('20260517101105'),
('20260513181544'),
('20260513105210'),
('20260513105209'),
('20260512155310'),
('20260512142543'),
('20260508134715'),
('20260504134804'),
('20260430102814'),
('20260430102813'),
('20260429145254'),
('20260429133747'),
('20260429123434'),
('20260424170418'),
('20260424131927'),
('20260422085615'),
('20260421123920'),
('20260421103557'),
('20260421021503'),
('20260421013319'),
('20260420114717'),
('20260416124233'),
('20260416124232'),
('20260416111923'),
('20260416111922'),
('20260415160654'),
('20260409161142'),
('20260409151451'),
('20260407091845'),
('20260403184752'),
('20260403184747'),
('20260401143315'),
('20260331122448'),
('20260331103301'),
('20260327140626'),
('20260326130631'),
('20260325150808'),
('20260324124033'),
('20260319125125'),
('20260319103035'),
('20260317134100'),
('20260317132911'),
('20260317132747'),
('20260317132544'),
('20260317130654'),
('20260311121245'),
('20260306115902'),
('20260305165936'),
('20260305161303'),
('20260305161302'),
('20260305100007'),
('20260304074158'),
('20260227184913'),
('20260224134805'),
('20260220131101'),
('20260219130831'),
('20260219102644'),
('20260219083335'),
('20260218102426'),
('20260216115709'),
('20260209103920'),
('20260209103526'),
('20260204153734'),
('20260204130807'),
('20260203145809'),
('20260203145801'),
('20260203145512'),
('20260202155431'),
('20260202150723'),
('20260202134958'),
('20260129145352'),
('20260129105200'),
('20260128073308'),
('20260127163159'),
('20260127150713'),
('20260127150640'),
('20260127150624'),
('20260127150613'),
('20260127150612'),
('20260127150611'),
('20260127114700'),
('20260123102258'),
('20260123102257'),
('20260121112929'),
('20260121111431'),
('20260120195822'),
('20260119162712'),
('20260116162519'),
('20260116121019'),
('20260116121015'),
('20260116110125'),
('20260115164124'),
('20260114153728'),
('20260113102028'),
('20260112140805'),
('20260109132143'),
('20260109110146'),
('20260109092932'),
('20260106120832'),
('20260106120601'),
('20260105144123'),
('20251231162838'),
('20251230154408'),
('20251229153734'),
('20251229153718'),
('20251226145247'),
('20251224152737'),
('20251224152736'),
('20251224152734'),
('20251224152733'),
('20251224152732'),
('20251222163416'),
('20251222151519'),
('20251222151015'),
('20251221174946'),
('20251221174938'),
('20251221174733'),
('20251221174251'),
('20251219115429'),
('20251216100247'),
('20251211154309'),
('20251210151531'),
('20251210133246'),
('20251210133225'),
('20251204142205'),
('20251204101451'),
('20251202141759'),
('20251201094057'),
('20251201084648'),
('20251128102055'),
('20251127145819'),
('20251127123135'),
('20251126171210'),
('20251126170127'),
('20251126165406'),
('20251126164626'),
('20251126145839'),
('20251126135708'),
('20251126134516'),
('20251125174110'),
('20251121143459'),
('20251121113600'),
('20251112112544'),
('20251110191233'),
('20251107102548'),
('20251106093323'),
('20251106092231'),
('20251106091730'),
('20251106072629'),
('20251031112354'),
('20251029140035'),
('20251024200950'),
('20251024130659'),
('20251023154344'),
('20251023154123'),
('20251023153834'),
('20251022104121'),
('20251021114023'),
('20251021105732'),
('20251021083946'),
('20251021073412'),
('20251020142629'),
('20251020090137'),
('20251020074349'),
('20251020073334'),
('20251013101230'),
('20251010092830'),
('20251010073504'),
('20251007160309'),
('20251007103421'),
('20251007082822'),
('20251007082809'),
('20251003171658'),
('20251003171653'),
('20250926185510'),
('20250919124523'),
('20250919124037'),
('20250915100607'),
('20250912081524'),
('20250911124033'),
('20250911111448'),
('20250909125858'),
('20250908085959'),
('20250903165724'),
('20250901143217'),
('20250901141844'),
('20250828153138'),
('20250828144553'),
('20250828142848'),
('20250826081205'),
('20250822100111'),
('20250821094638'),
('20250820200921'),
('20250818154000'),
('20250813174100'),
('20250813172434'),
('20250812132802'),
('20250812082721'),
('20250806174150'),
('20250806173900'),
('20250801072722'),
('20250731145640'),
('20250731144632'),
('20250724104251'),
('20250722094047'),
('20250721220908'),
('20250721212307'),
('20250721211820'),
('20250721192051'),
('20250721150002'),
('20250721150001'),
('20250721150000'),
('20250721091802'),
('20250721090704'),
('20250718174008'),
('20250718140450'),
('20250717142942'),
('20250717140238'),
('20250717092012'),
('20250717071548'),
('20250716150049'),
('20250716143358'),
('20250716142613'),
('20250716132759'),
('20250716132649'),
('20250716123425'),
('20250715124108'),
('20250714131519'),
('20250712000000'),
('20250710102337'),
('20250709171329'),
('20250709085218'),
('20250709082136'),
('20250708094414'),
('20250707113718'),
('20250707113717'),
('20250707100102'),
('20250707100101'),
('20250707100026'),
('20250707100025'),
('20250707100013'),
('20250707100012'),
('20250707100010'),
('20250707095956'),
('20250707095955'),
('20250707095224'),
('20250707095223'),
('20250707094932'),
('20250707094931'),
('20250707094901'),
('20250707094900'),
('20250707090348'),
('20250707090347'),
('20250707090329'),
('20250707090328'),
('20250707090314'),
('20250707090313'),
('20250707085725'),
('20250707085724'),
('20250707085651'),
('20250707085650'),
('20250707085634'),
('20250707085633'),
('20250707085615'),
('20250707085614'),
('20250707083222'),
('20250707083221'),
('20250707083211'),
('20250707083210'),
('20250707083160'),
('20250707083159'),
('20250707082521'),
('20250707082520'),
('20250707082510'),
('20250707082509'),
('20250707082436'),
('20250707082435'),
('20250707081911'),
('20250707081910'),
('20250707081837'),
('20250707081836'),
('20250707081826'),
('20250707081825'),
('20250704800001'),
('20250703133126'),
('20250701141017'),
('20250701133139'),
('20250630180000'),
('20250627134933'),
('20250627134932'),
('20250627134926'),
('20250627134925'),
('20250627134916'),
('20250627134915'),
('20250627124153'),
('20250627124152'),
('20250627124144'),
('20250627124143'),
('20250627124130'),
('20250627124129'),
('20250627124119'),
('20250627124118'),
('20250627124056'),
('20250627124055'),
('20250627124049'),
('20250627124048'),
('20250627124040'),
('20250627124039'),
('20250627124034'),
('20250627124033'),
('20250627124029'),
('20250627124028'),
('20250627124023'),
('20250627124022'),
('20250627124017'),
('20250627124016'),
('20250627124008'),
('20250627124007'),
('20250627123959'),
('20250627123958'),
('20250627091213'),
('20250627091212'),
('20250627091011'),
('20250627091010'),
('20250627084852'),
('20250627084430'),
('20250626175249'),
('20250619144939'),
('20250619143820'),
('20250611083925'),
('20250611072251'),
('20250610173034'),
('20250610063400'),
('20250609121102'),
('20250602145535'),
('20250602075710'),
('20250530112903'),
('20250528133222'),
('20250526134136'),
('20250526133654'),
('20250526133152'),
('20250526130953'),
('20250526111147'),
('20250522134155'),
('20250521151540'),
('20250521135607'),
('20250521104239'),
('20250521095733'),
('20250520170402'),
('20250520155108'),
('20250520143628'),
('20250520080000'),
('20250519092053'),
('20250519092052'),
('20250519092051'),
('20250519085911'),
('20250519085910'),
('20250519085909'),
('20250519084649'),
('20250519084648'),
('20250519084647'),
('20250517100023'),
('20250516115757'),
('20250516115756'),
('20250516115755'),
('20250516100026'),
('20250516100025'),
('20250516100024'),
('20250516095315'),
('20250516095314'),
('20250516095313'),
('20250516084025'),
('20250515085230'),
('20250515083935'),
('20250515083802'),
('20250515083649'),
('20250513153630'),
('20250513153629'),
('20250513153628'),
('20250513152807'),
('20250513152806'),
('20250513152805'),
('20250513151260'),
('20250513151259'),
('20250513151258'),
('20250513144354'),
('20250513144353'),
('20250513144352'),
('20250513132425'),
('20250513132424'),
('20250513132423'),
('20250512151248'),
('20250512151247'),
('20250512151246'),
('20250512144220'),
('20250512144219'),
('20250512144218'),
('20250512142914'),
('20250512142913'),
('20250512142912'),
('20250512130616'),
('20250512130615'),
('20250512130614'),
('20250512123541'),
('20250512123540'),
('20250512123539'),
('20250512122608'),
('20250512122607'),
('20250512122606'),
('20250512081332'),
('20250507154910'),
('20250507110137'),
('20250506170753'),
('20250506145851'),
('20250506145850'),
('20250506145849'),
('20250506144002'),
('20250506144001'),
('20250506144000'),
('20250506121532'),
('20250506121531'),
('20250506121530'),
('20250506115439'),
('20250506115438'),
('20250506115437'),
('20250506085760'),
('20250506085759'),
('20250506085758'),
('20250506084829'),
('20250506084828'),
('20250506084827'),
('20250506084022'),
('20250506084021'),
('20250506084020'),
('20250505161359'),
('20250505161358'),
('20250505161357'),
('20250505142221'),
('20250505142220'),
('20250505142219'),
('20250505140928'),
('20250505140927'),
('20250505140926'),
('20250505135821'),
('20250505135820'),
('20250505135819'),
('20250505125354'),
('20250505125335'),
('20250505125308'),
('20250429150146'),
('20250429150128'),
('20250429150114'),
('20250429100154'),
('20250429100153'),
('20250429100152'),
('20250429100151'),
('20250429100150'),
('20250429100149'),
('20250429100148'),
('20250428154519'),
('20250428154500'),
('20250428154444'),
('20250428140148'),
('20250428140126'),
('20250428140111'),
('20250428130148'),
('20250428130129'),
('20250428130107'),
('20250428111042'),
('20250425134911'),
('20250425134826'),
('20250425132821'),
('20250425132757'),
('20250425132724'),
('20250425132247'),
('20250425130412'),
('20250425130345'),
('20250425130332'),
('20250425124942'),
('20250425124826'),
('20250425124804'),
('20250425124305'),
('20250425124100'),
('20250425123733'),
('20250425122705'),
('20250425122641'),
('20250425122510'),
('20250425102555'),
('20250425102447'),
('20250425102306'),
('20250424140537'),
('20250424140359'),
('20250424135624'),
('20250416125600'),
('20250415143607'),
('20250414122904'),
('20250414122643'),
('20250414121455'),
('20250414091130'),
('20250411152022'),
('20250411112117'),
('20250411110934'),
('20250411110825'),
('20250411074202'),
('20250409140720'),
('20250409140652'),
('20250409100421'),
('20250408121522'),
('20250407202459'),
('20250407000001'),
('20250403110833'),
('20250403093628'),
('20250402152230'),
('20250402152200'),
('20250402152130'),
('20250402152100'),
('20250402152030'),
('20250402152000'),
('20250402151930'),
('20250402151900'),
('20250402151747'),
('20250402151113'),
('20250402150959'),
('20250402150920'),
('20250402135038'),
('20250402113844'),
('20250327130156'),
('20250327130155'),
('20250325162648'),
('20250325145324'),
('20250324125056'),
('20250324122757'),
('20250318175216'),
('20250318093216'),
('20250310213734'),
('20250304163656'),
('20250303104151'),
('20250227155522'),
('20250227091909'),
('20250220223944'),
('20250220180114'),
('20250220180113'),
('20250220180112'),
('20250220085848'),
('20250219205535'),
('20250219164502'),
('20250219152213'),
('20250219124948'),
('20250218165958'),
('20250217152051'),
('20250214091021'),
('20250212123207'),
('20250207142402'),
('20250207094842'),
('20250205184611'),
('20250122130735'),
('20250122112050'),
('20250120151959'),
('20250114172823'),
('20250114163522'),
('20250103124802'),
('20241227161927'),
('20241227154337'),
('20241224142141'),
('20241224141116'),
('20241223154437'),
('20241223144027'),
('20241220160748'),
('20241220095049'),
('20241220084758'),
('20241219152909'),
('20241219145642'),
('20241219122151'),
('20241217120924'),
('20241216140931'),
('20241216110525'),
('20241213182343'),
('20241213142739'),
('20241128132010'),
('20241128091634'),
('20241126141853'),
('20241126103448'),
('20241126102447'),
('20241125194753'),
('20241122141158'),
('20241122140603'),
('20241122134430'),
('20241122111534'),
('20241122105327'),
('20241122105133'),
('20241122104537'),
('20241120094557'),
('20241120090305'),
('20241120085057'),
('20241119114948'),
('20241119110219'),
('20241118165935'),
('20241118103032'),
('20241113181629'),
('20241108103702'),
('20241107093418'),
('20241106104515'),
('20241101151559'),
('20241031123415'),
('20241031102231'),
('20241031095225'),
('20241030123528'),
('20241029141351'),
('20241025081408'),
('20241024082941'),
('20241022144437'),
('20241021140054'),
('20241021095706'),
('20241018112637'),
('20241017082601'),
('20241016133129'),
('20241016104211'),
('20241015132635'),
('20241014093451'),
('20241014000100'),
('20241011123621'),
('20241011123148'),
('20241010055733'),
('20241008080209'),
('20241007092701'),
('20241007083747'),
('20241001112117'),
('20241001105523'),
('20240924114730'),
('20240920091133'),
('20240920084727'),
('20240917145042'),
('20240917144243'),
('20240910111203'),
('20240910093646'),
('20240906170048'),
('20240906154644'),
('20240829093425'),
('20240823092643'),
('20240822142524'),
('20240822082727'),
('20240822080031'),
('20240821174724'),
('20240821172352'),
('20240821093145'),
('20240820125840'),
('20240820090312'),
('20240819092354'),
('20240816075711'),
('20240814144137'),
('20240813121307'),
('20240813095718'),
('20240812130655'),
('20240808132042'),
('20240808085506'),
('20240808080611'),
('20240807113700'),
('20240807100609'),
('20240807072052'),
('20240802115017'),
('20240801142242'),
('20240801134833'),
('20240801134832'),
('20240729154334'),
('20240729152352'),
('20240729151049'),
('20240729134020'),
('20240729133823'),
('20240723150304'),
('20240723150221'),
('20240722201341'),
('20240718105718'),
('20240718080929'),
('20240716154636'),
('20240716153753'),
('20240712090133'),
('20240711094255'),
('20240711091155'),
('20240708195226'),
('20240708081356'),
('20240706204557'),
('20240705125619'),
('20240703061352'),
('20240702081109'),
('20240701184757'),
('20240701083355'),
('20240628083830'),
('20240628083654'),
('20240626094521'),
('20240625090742'),
('20240619082054'),
('20240611074215'),
('20240607095208'),
('20240607095155'),
('20240604141208'),
('20240603095841'),
('20240603080144'),
('20240530123427'),
('20240522105942'),
('20240521143531'),
('20240520115450'),
('20240514081110'),
('20240514072741'),
('20240506085424'),
('20240502095122'),
('20240502075803'),
('20240430133150'),
('20240430100120'),
('20240429141108'),
('20240426143059'),
('20240425131701'),
('20240425082113'),
('20240424124802'),
('20240424110420'),
('20240423155113'),
('20240419085012'),
('20240419071607'),
('20240415122310'),
('20240412133335'),
('20240412085450'),
('20240411114759'),
('20240404123257'),
('20240403084644'),
('20240329112415'),
('20240328153701'),
('20240328075919'),
('20240327071539'),
('20240314172008'),
('20240314170211'),
('20240314165306'),
('20240314163426'),
('20240312141641'),
('20240311091817'),
('20240308150801'),
('20240308104003'),
('20240305164449'),
('20240305093058'),
('20240301133006'),
('20240227161430'),
('20240205160647'),
('20240129155938'),
('20240125080718'),
('20240123104811'),
('20240118141022'),
('20240118140703'),
('20240118135350'),
('20240115130517'),
('20240115102012'),
('20240115094827'),
('20240112091706'),
('20240111155133'),
('20240111151140'),
('20240111140424'),
('20240104152816'),
('20240103125624'),
('20231220140936'),
('20231220115621'),
('20231219121735'),
('20231218170631'),
('20231214133638'),
('20231214103653'),
('20231207095229'),
('20231205153156'),
('20231204151512'),
('20231204131333'),
('20231201091348'),
('20231130085817'),
('20231129145100'),
('20231128092231'),
('20231123105540'),
('20231123095209'),
('20231117123744'),
('20231114092154'),
('20231109154934'),
('20231109141829'),
('20231107110809'),
('20231106145424'),
('20231103144201'),
('20231102154537'),
('20231102141929'),
('20231102085146'),
('20231101080314'),
('20231027144605'),
('20231020091031'),
('20231017082921'),
('20231016115055'),
('20231010090849'),
('20231010085938'),
('20231001070407'),
('20230926144126'),
('20230926132500'),
('20230922064617'),
('20230920083133'),
('20230918090426'),
('20230915135256'),
('20230915120854'),
('20230915073205'),
('20230913123123'),
('20230912082112'),
('20230912082057'),
('20230912082000'),
('20230911185900'),
('20230911083923'),
('20230907153404'),
('20230907064335'),
('20230905081225'),
('20230830120517'),
('20230828085627'),
('20230821135235'),
('20230817092555'),
('20230816091053'),
('20230811120622'),
('20230811081854'),
('20230808144739'),
('20230731135721'),
('20230731095510'),
('20230727163611'),
('20230726171737'),
('20230726165711'),
('20230721073114'),
('20230720204311'),
('20230719100256'),
('20230717090135'),
('20230713122526'),
('20230705213846'),
('20230704150108'),
('20230704144027'),
('20230704112230'),
('20230629100018'),
('20230627080605'),
('20230626124005'),
('20230626123648'),
('20230620211201'),
('20230619101701'),
('20230615183805'),
('20230614191603'),
('20230608154821'),
('20230608133543'),
('20230608085013'),
('20230606164458'),
('20230606085050'),
('20230602090325'),
('20230529093955'),
('20230525154612'),
('20230525122232'),
('20230525120005'),
('20230524130637'),
('20230523140656'),
('20230523094557'),
('20230522113810'),
('20230522093423'),
('20230522091400'),
('20230517093556'),
('20230511124419'),
('20230510113501'),
('20230505093030'),
('20230503143229'),
('20230425130239'),
('20230424210224'),
('20230424154516'),
('20230424150952'),
('20230424092207'),
('20230424091446'),
('20230421094757'),
('20230420120806'),
('20230420114754'),
('20230419123538'),
('20230418151450'),
('20230417140356'),
('20230417131515'),
('20230417122020'),
('20230417094339'),
('20230414130437'),
('20230414074225'),
('20230411085545'),
('20230411083336'),
('20230403094044'),
('20230403093407'),
('20230328161507'),
('20230327134418'),
('20230323112252'),
('20230313145506'),
('20230307131524'),
('20230301122720'),
('20230227145104'),
('20230221102035'),
('20230221070501'),
('20230216145442'),
('20230216140543'),
('20230214145444'),
('20230214100638'),
('20230207110702'),
('20230206143214'),
('20230203132157'),
('20230202163249'),
('20230202150407'),
('20230202110407'),
('20230131152047'),
('20230131144740'),
('20230127140904'),
('20230126103454'),
('20230125104957'),
('20230118100324'),
('20230109095957'),
('20230106152449'),
('20230105094302'),
('20230102150636'),
('20221226091020'),
('20221222164226'),
('20221219111209'),
('20221216154033'),
('20221212153810'),
('20221208142739'),
('20221208140608'),
('20221206094412'),
('20221205112007'),
('20221202130126'),
('20221129133433'),
('20221128132620'),
('20221125111605'),
('20221122163328'),
('20221118093903'),
('20221118084547'),
('20221115160325'),
('20221115155550'),
('20221115135840'),
('20221115110223'),
('20221115100834'),
('20221114102649'),
('20221110151027'),
('20221107151038'),
('20221031144907'),
('20221031141549'),
('20221028160705'),
('20221028124549'),
('20221028091920'),
('20221024090308'),
('20221021135946'),
('20221021135428'),
('20221020093745'),
('20221018144521'),
('20221013140147'),
('20221011133055'),
('20221011083520'),
('20221010142031'),
('20221010083509'),
('20221007075812'),
('20221004092737'),
('20220930143002'),
('20220930134327'),
('20220930123935'),
('20220923092906'),
('20220922105251'),
('20220921095507'),
('20220919133338'),
('20220916131538'),
('20220915092730'),
('20220906130714'),
('20220906065059'),
('20220905142834'),
('20220905095529'),
('20220831113537'),
('20220829094054'),
('20220825051923'),
('20220824113131'),
('20220823145421'),
('20220823135203'),
('20220818151052'),
('20220818141616'),
('20220817095619'),
('20220817092945'),
('20220816120137'),
('20220811155332'),
('20220809083243'),
('20220807210117'),
('20220801101144'),
('20220729062203'),
('20220729055309'),
('20220728144707'),
('20220727161448'),
('20220727132848'),
('20220725152220'),
('20220722123417'),
('20220721150658'),
('20220718124337'),
('20220718083657'),
('20220713171816'),
('20220705155228'),
('20220704145333'),
('20220629133308'),
('20220621153030'),
('20220621090834'),
('20220620150551'),
('20220620141910'),
('20220617124108'),
('20220614110841'),
('20220613130634'),
('20220610143942'),
('20220610134535'),
('20220609080806'),
('20220607082458'),
('20220602145819'),
('20220601150058'),
('20220530091046'),
('20220526101535'),
('20220525122759');

