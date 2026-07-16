import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { fixupPluginRules } from '@eslint/compat'
import pluginJs from '@eslint/js'
import pluginImport from 'eslint-plugin-import'
import pluginJsxA11y from 'eslint-plugin-jsx-a11y'
import pluginPrettier from 'eslint-plugin-prettier/recommended'
import pluginReact from 'eslint-plugin-react'
import pluginReactHooks from 'eslint-plugin-react-hooks'
import pluginTailwind from 'eslint-plugin-tailwindcss'
import globals from 'globals'
import pluginTypescriptEslint from 'typescript-eslint'

import noDirectRrdNavImport from './eslint-rules/no-direct-rrd-nav-import.js'
import noFormikPropsInEffect from './eslint-rules/no-formik-props-in-effect.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const tailwindConfigPath = resolve(__dirname, 'tailwind.config.ts')

/** @type {import('eslint').Linter.Config[]} */
export default [
  {
    ignores: [
      '**/dist/*',
      '.github/**/*',
      '**/globals.d.ts',
      '**/generated/**/*',
      'cypress/**/*',
      'coverage/**/*',
      '**/node_modules/**/*',
      '**/.pnpm-store/**/*',
    ],
  },

  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.jest,
      },
      sourceType: 'module',
    },
  },

  pluginJs.configs.recommended,
  ...pluginTypescriptEslint.configs.recommended,
  pluginReact.configs.flat.recommended,
  pluginReact.configs.flat['jsx-runtime'],
  {
    files: ['**/*.{js,mjs,cjs,ts,mts,jsx,tsx}'],
    plugins: {
      tailwindcss: pluginTailwind,
    },
    settings: {
      tailwindcss: {
        config: tailwindConfigPath,
      },
    },
    rules: {
      'tailwindcss/classnames-order': 'warn',
      'tailwindcss/enforces-negative-arbitrary-values': 'warn',
      'tailwindcss/enforces-shorthand': 'warn',
      'tailwindcss/no-custom-classname': 'off',
      'tailwindcss/no-contradicting-classname': 'warn',
    },
  },

  {
    files: ['**/*.{js,mjs,cjs,ts,mts,jsx,tsx}'],
    plugins: {
      import: fixupPluginRules(pluginImport),
      'jsx-a11y': pluginJsxA11y,
      'react-hooks': pluginReactHooks,
      lago: {
        rules: {
          'no-direct-rrd-nav-import': noDirectRrdNavImport,
          'no-formik-props-in-effect': noFormikPropsInEffect,
        },
      },
    },
    languageOptions: {
      parser: pluginTypescriptEslint.parser,
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
      ecmaVersion: 6,
      sourceType: 'module',
    },
    rules: {
      ...pluginJsxA11y.configs.recommended.rules,
      ...pluginReactHooks.configs.recommended.rules,

      'no-alert': 'error',
      'no-console': 'error',
      eqeqeq: 'error',
      'no-else-return': 'warn',
      'no-unused-vars': 'off',
      'newline-after-var': ['warn'], // TOFIX: Deprecated rule
      'no-extra-boolean-cast': 'off',
      'no-nested-ternary': 'warn',
      'no-unneeded-ternary': 'warn',
      'no-duplicate-imports': 'error',

      // Prevent barrel imports from large libraries (impacts bundle size and dev performance)
      'no-restricted-imports': [
        'error',
        {
          paths: [
            {
              name: '@mui/material',
              message:
                'Import from @mui/material/* instead. E.g., import Button from "@mui/material/Button"',
            },
          ],
        },
      ],
      // Enforce slug-aware navigation wrappers (custom rule — error level,
      // kept separate from `no-restricted-imports` which is also used below
      // at `warn` severity for formik/dialog deprecations).
      'lago/no-direct-rrd-nav-import': 'error',

      // Plugins
      'import/order': [
        'error',
        {
          groups: ['builtin', 'external', 'internal', 'unknown', 'sibling', 'parent', 'index'],
          'newlines-between': 'always',
        },
      ],
      '@typescript-eslint/no-non-null-assertion': 'error',
      // https://typescript-eslint.io/rules/no-shadow/
      'no-shadow': 'off',
      '@typescript-eslint/no-shadow': 'error',
      // https://typescript-eslint.io/rules/no-unused-expressions/
      'no-unused-expressions': 'off',
      '@typescript-eslint/no-unused-expressions': [
        'error',
        {
          allowTernary: true,
          allowShortCircuit: true,
          allowTaggedTemplates: true,
        },
      ],
      '@typescript-eslint/no-unsafe-function-type': 'warn',
      '@typescript-eslint/ban-ts-comment': 'warn',
      'lago/no-formik-props-in-effect': 'error',
    },
  },
  {
    files: ['**/*.{cjs,mjs}'],
    rules: {
      '@typescript-eslint/no-require-imports': 'off',
    },
  },
  {
    files: ['vite.config.ts', 'scripts/**/*.js'],
    rules: {
      'import/order': 'off',
    },
  },
  {
    files: ['**/*.test.{ts,tsx}', '**/*.spec.{ts,tsx}', '**/__tests__/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
  {
    files: ['**/*.{js,mjs,cjs,ts,mts,jsx,tsx}'],
    rules: {
      'no-restricted-imports': [
        'warn',
        {
          // Formik deprecation warning - use @tanstack/react-form instead
          paths: [
            {
              name: 'formik',
              message: 'Formik is deprecated. Use @tanstack/react-form instead.',
            },
          ],
          // Old dialog components deprecation warning - use ~/components/dialogs instead
          patterns: [
            {
              group: [
                '~/components/designSystem/Dialog',
                '~/components/designSystem/WarningDialog',
                '~/components/designSystem/PreventClosingDrawerDialog',
                '~/components/PremiumWarningDialog',
                '~/components/addOns/*Dialog*',
                '~/components/billableMetrics/*Dialog*',
                '~/components/coupons/*Dialog*',
                '~/components/customers/*Dialog*',
                '~/components/customers/**/*Dialog*',
                '~/components/developers/**/*Dialog*',
                '~/components/exports/*Dialog*',
                '~/components/features/*Dialog*',
                '~/components/invoices/*Dialog*',
                '~/components/invoices/**/*Dialog*',
                '~/components/invoceCustomFooter/*Dialog*',
                '~/components/paymentMethodSelection/*Dialog*',
                '~/components/paymentMethodsList/*Dialog*',
                '~/components/plans/*Dialog*',
                '~/components/settings/**/*Dialog*',
                '~/components/subscriptions/*Dialog*',
                '~/components/subscriptions/**/*Dialog*',
                '~/components/taxes/*Dialog*',
                '~/components/wallets/*Dialog*',
              ],
              // Allow the migrated hook exports (useXxxDialog) that still live
              // in these files; only the legacy component/ref exports stay flagged.
              allowImportNamePattern: '^use',
              message:
                'This dialog component is deprecated. Please use the new dialog management system in ~/components/dialogs instead.',
            },
          ],
        },
      ],
    },
  },

  pluginPrettier,
]
