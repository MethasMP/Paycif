import { pgTable, uuid, text, timestamp, boolean, integer, bigint, numeric, decimal, pgEnum, doublePrecision } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

// ----------------------------------------------------------------------------
// ENUMS
// ----------------------------------------------------------------------------
export const kycStatusEnum = pgEnum('kyc_status_enum', ['PENDING', 'APPROVED', 'REJECTED']);
export const settlementStatusEnum = pgEnum('settlement_status_enum', ['UNSETTLED', 'PENDING', 'SETTLED', 'FAILED', 'DISPUTED']);

// ----------------------------------------------------------------------------
// TABLES
// ----------------------------------------------------------------------------

export const profiles = pgTable('profiles', {
  id: uuid('id').primaryKey().defaultRandom(),
  username: text('username').unique().notNull(),
  fullName: text('full_name'),
  email: text('email'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
  omiseCustomerId: text('omise_customer_id').unique(),
  preferredPaymentMethodId: text('preferred_payment_method_id'),
  preferredPaymentMethodType: text('preferred_payment_method_type'),
  biometricEnabled: boolean('biometric_enabled').default(false),
  hasPin: boolean('has_pin').default(false),
  kycStatus: text('kyc_status').default('PENDING'),
  kycTier: text('kyc_tier').default('tier0'),
  externalCustomerId: text('external_customer_id').unique(),
  externalCustomerType: text('external_customer_type').default('OMISE'),
  openfortWalletAddress: text('openfort_wallet_address'),
  coinflowCustomerId: text('coinflow_customer_id'),
  paymentProvider: text('payment_provider').default('coinflow'),
  lastLat: doublePrecision('last_lat'),
  lastLng: doublePrecision('last_lng'),
  lastTxnAt: timestamp('last_txn_at', { withTimezone: true }),
  accountStatus: text('account_status').default('ACTIVE'),
  verifiedAt: timestamp('verified_at', { withTimezone: true }),
  idLast4: text('id_last_4'),
});

export const transactions = pgTable('transactions', {
  id: uuid('id').primaryKey().defaultRandom(),
  referenceId: text('reference_id').unique(),
  description: text('description'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  metadata: text('metadata'), // jsonb
  status: text('status').notNull().default('PENDING'),
  gatewayFee: bigint('gateway_fee', { mode: 'bigint' }).default(0n),
  providerMetadata: text('provider_metadata').default('{}'), // jsonb
  type: text('type').default('PAYOUT'),
  amount: bigint('amount', { mode: 'bigint' }).default(0n),
  profileId: uuid('profile_id').references(() => profiles.id, { onDelete: 'cascade' }),
});

export const ledgerEntries = pgTable('ledger_entries', {
  id: uuid('id').primaryKey().defaultRandom(),
  transactionId: uuid('transaction_id').notNull().references(() => transactions.id, { onDelete: 'cascade' }),
  profileId: uuid('profile_id').notNull().references(() => profiles.id, { onDelete: 'cascade' }),
  amount: bigint('amount', { mode: 'bigint' }).notNull(),
  type: text('type').notNull().default('CREDIT'),
  currency: text('currency').default('THB'),
  description: text('description'),
  balanceAfter: bigint('balance_after', { mode: 'bigint' }),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
});

// identity_verification table has been dropped to conform to pure Delegated KYC

export const exchangeRates = pgTable('exchange_rates', {
  id: uuid('id').primaryKey().defaultRandom(),
  fromCurrency: text('from_currency').notNull(),
  toCurrency: text('to_currency').notNull(),
  midRate: numeric('mid_rate', { precision: 20, scale: 10 }).notNull(),
  providerRate: numeric('provider_rate', { precision: 20, scale: 10 }).notNull(),
  spread: numeric('spread', { precision: 10, scale: 5 }).notNull().default('0'),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const cacheSavedPaymentMethods = pgTable('cache_saved_payment_methods', {
  userId: uuid('user_id').primaryKey().references(() => profiles.id, { onDelete: 'cascade' }),
  paymentMethodsJson: text('payment_methods_json').notNull(), // jsonb
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const auditLogs = pgTable('audit_logs', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => profiles.id, { onDelete: 'cascade' }),
  action: text('action').notNull(),
  resourceType: text('resource_type').notNull(),
  resourceId: text('resource_id'),
  metadata: text('metadata'), // jsonb
  requestId: text('request_id'),
  ipAddress: text('ip_address'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
});

export const userDeviceBindings = pgTable('user_device_bindings', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => profiles.id, { onDelete: 'cascade' }),
  deviceId: text('device_id').notNull(),
  publicKey: text('public_key').notNull(),
  isActive: boolean('is_active').default(true),
  lastUsedAt: timestamp('last_used_at', { withTimezone: true }).defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  deviceName: text('device_name').default('Unknown Device'),
  osType: text('os_type').default('web'),
  appVersion: text('app_version'),
  trustScore: integer('trust_score').default(100),
  metadata: text('metadata').default('{}'), // jsonb
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  revokedReason: text('revoked_reason'),
});

// ----------------------------------------------------------------------------
// RELATIONS
// ----------------------------------------------------------------------------

export const profilesRelations = relations(profiles, ({ many }) => ({
  transactions: many(transactions),
  ledgerEntries: many(ledgerEntries),
  deviceBindings: many(userDeviceBindings),
}));

export const transactionsRelations = relations(transactions, ({ one, many }) => ({
  profile: one(profiles, {
    fields: [transactions.profileId],
    references: [profiles.id],
  }),
  ledgerEntries: many(ledgerEntries),
}));

export const ledgerEntriesRelations = relations(ledgerEntries, ({ one }) => ({
  transaction: one(transactions, {
    fields: [ledgerEntries.transactionId],
    references: [transactions.id],
  }),
  profile: one(profiles, {
    fields: [ledgerEntries.profileId],
    references: [profiles.id],
  }),
}));

export const jobs = pgTable('jobs', {
  id: uuid('id').primaryKey().defaultRandom(),
  type: text('type').notNull(),
  payload: text('payload').default('{}'), // jsonb
  status: text('status').default('pending'),
  errorMessage: text('error_message'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
  lockedAt: timestamp('locked_at', { withTimezone: true }),
});
