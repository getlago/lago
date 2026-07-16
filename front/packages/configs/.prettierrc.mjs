export default {
  plugins: ['@trivago/prettier-plugin-sort-imports', 'prettier-plugin-tailwindcss'],
  semi: false,
  singleQuote: true,
  printWidth: 100,
  tabWidth: 2,
  importOrder: ['^@core/(.*)$', '^[~/]', '^./(.*)', '^../(..*)'],
  importOrderSeparation: true,
  importOrderSortSpecifiers: true,
  importOrderCaseInsensitive: true,
  tailwindFunctions: ['tw', 'clsx', 'cva'],
  overrides: [
    {
      files: '*.svg',
      options: { parser: 'html' },
    },
  ],
}
