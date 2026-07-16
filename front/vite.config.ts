import { sentryVitePlugin } from '@sentry/vite-plugin'
import react from '@vitejs/plugin-react-swc'
import { resolve } from 'node:path'
import { defineConfig, loadEnv } from 'vite'
import { createHtmlPlugin } from 'vite-plugin-html'
import svgr from 'vite-plugin-svgr'
import topLevelAwait from 'vite-plugin-top-level-await'
import wasm from 'vite-plugin-wasm'

import { version } from './package.json'

const icons: Record<string, string> = {
  development: '/favicon-local.svg',
  production: '/favicon-prod.svg',
  staging: '/favicon-staging.svg',
}

const titles: Record<string, string> = {
  development: 'Lago - Local',
  production: 'Lago',
  staging: 'Lago - Cloud',
}

// Local dev only: when running inside a worktree instance (see scripts/lago-worktree.sh),
// show the worktree name in the browser tab to distinguish it from the main app.
const getPageTitle = (mode: string, env: Record<string, string>): string => {
  if (mode === 'development' && env.LAGO_WORKTREE_NAME) return `WT - ${env.LAGO_WORKTREE_NAME}`
  return titles[env.APP_ENV] || titles.production
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const port = env.PORT ? parseInt(env.PORT) : 8080
  const isProduction = mode === 'production'
  const sentryAuthToken = env.SENTRY_AUTH_TOKEN
  const sentryOrg = env.SENTRY_ORG || 'lago'
  const sentryProject = env.SENTRY_FRONT_PROJECT || 'front'
  const appVersion = env.APP_VERSION
  const shouldUploadSourceMaps =
    isProduction && sentryAuthToken && sentryOrg && sentryProject && appVersion

  const plugins = [
    react(),
    wasm(),
    topLevelAwait(),

    svgr({
      include: '**/*.svg',
      svgrOptions: {
        plugins: ['@svgr/plugin-jsx'],
      },
    }),

    createHtmlPlugin({
      inject: {
        data: {
          title: getPageTitle(mode, env),
          favicon: icons[env.APP_ENV] || icons.production,
        },
      },
    }),
  ]

  // Add Sentry plugin only in production builds with required env vars
  if (shouldUploadSourceMaps) {
    plugins.push(
      sentryVitePlugin({
        org: sentryOrg,
        project: sentryProject,
        authToken: sentryAuthToken,
        release: {
          name: appVersion,
        },
        sourcemaps: {
          // Modern Debug ID-based upload: the plugin injects a stable Debug
          // ID into each emitted JS file at build time and writes the same
          // ID into the matching .map. Sentry symbolicates errors by reading
          // the ID from the served JS — no release-name + path coupling,
          // and only .map files get uploaded (vs both .js and .map under
          // the legacy uploader), roughly halving request count.
          assets: ['./dist/**'],
          // Skip Shiki language and theme grammar chunks (renamed with a
          // stable prefix in #3428). They're tokenizer data, not app code
          // — runtime errors don't originate inside them, so symbolicating
          // them in Sentry has no practical value.
          ignore: ['./dist/assets/shiki-lang-*', './dist/assets/shiki-theme-*'],
          // We deliberately do NOT delete .map files after upload. Lago is
          // open source — the JS sources are already public on GitHub, so
          // shipping source maps to production exposes nothing new and lets
          // self-hosters / contributors debug their own deployments with
          // readable stack frames in browser devtools.
        },
        telemetry: false,
      }),
    )

    console.log(
      `✅ Sentry source maps will be uploaded for app version: ${appVersion}, sentryOrg: ${sentryOrg}, sentryProject: ${sentryProject}`,
    )
  } else if (isProduction) {
    const missingVars: string[] = []

    if (!sentryAuthToken) missingVars.push('SENTRY_AUTH_TOKEN')
    if (!sentryOrg) missingVars.push('SENTRY_ORG')
    if (!sentryProject) missingVars.push('SENTRY_FRONT_PROJECT')
    if (!appVersion) missingVars.push('APP_VERSION')

    if (missingVars.length > 0) {
      console.log(
        `⚠️ Sentry source maps upload skipped. Missing environment variables: ${missingVars.join(', ')}`,
      )
    }
  }

  return {
    plugins,
    define: {
      APP_ENV: JSON.stringify(env.APP_ENV),
      API_URL: JSON.stringify(env.API_URL),
      DOMAIN: JSON.stringify(env.LAGO_DOMAIN),
      APP_VERSION: JSON.stringify(appVersion || version), // Fallback to package.json version when APP_VERSION env var is not set
      LAGO_OAUTH_PROXY_URL: JSON.stringify(env.LAGO_OAUTH_PROXY_URL),
      LAGO_DISABLE_SIGNUP: JSON.stringify(env.LAGO_DISABLE_SIGNUP),
      NANGO_PUBLIC_KEY: JSON.stringify(env.NANGO_PUBLIC_KEY),
      SENTRY_DSN: JSON.stringify(env.SENTRY_DSN),
      LAGO_DISABLE_PDF_GENERATION: JSON.stringify(env.LAGO_DISABLE_PDF_GENERATION),
      LAGO_SUPERSET_URL: JSON.stringify(env.LAGO_SUPERSET_URL),
    },
    resolve: {
      alias: {
        '~': resolve(__dirname, 'src'),
        lodash: 'lodash-es',
      },
    },
    server: {
      port,
      host: true,
      strictPort: true,
      allowedHosts: ['app.lago.dev'],
      watch: {
        usePolling: true,
        interval: 1000,
        ignored: [
          '**/node_modules/**',
          '**/.git/**',
          '**/dist/**',
          '**/coverage/**',
          '**/.vite/**',
          '**/packages/**/dist/**',
          '**/*.log',
          '**/cypress/**',
          '**/.pnpm-store/**',
          '**/src/generated/**',
        ],
      },
      // Local dev only: proxy API requests through Vite to avoid CORS when
      // running isolated frontend worktrees (see scripts/lago-worktree.sh).
      // Activated by LAGO_API_PROXY_TARGET in the worktree .env file.
      ...(mode === 'development' &&
        env.LAGO_API_PROXY_TARGET && {
          proxy: {
            '/api': {
              target: env.LAGO_API_PROXY_TARGET,
              changeOrigin: true,
              rewrite: (path: string) => path.replace(/^\/api/, ''),
              secure: false,
              ws: true,
            },
          },
        }),
    },
    optimizeDeps: {
      include: [
        '@apollo/client',
        '@mui/material',
        'react',
        'react-dom',
        'lodash-es',
        'recharts',
        'formik',
        'yup',
      ],
      exclude: ['lago-design-system', 'lago-configs'],
    },
    preview: {
      port,
    },
    build: {
      outDir: 'dist',
      sourcemap: true,
      target: 'esnext',
      rollupOptions: {
        output: {
          // Prefix Shiki language/theme chunks with `shiki-lang-` /
          // `shiki-theme-` so the Sentry uploader can ignore them via a
          // single glob (see `uploadLegacySourcemaps.ignore` above). This
          // does NOT change runtime behavior — chunks remain individually
          // code-split and lazy-loaded, only the output filename changes.
          chunkFileNames: (chunkInfo) => {
            const id = chunkInfo.facadeModuleId || ''
            if (/[\\/]shiki[\\/](?:dist[\\/])?langs[\\/]/.test(id) || /@shikijs[\\/]langs[\\/]/.test(id)) {
              return 'assets/shiki-lang-[name].[hash].js'
            }
            if (/[\\/]shiki[\\/](?:dist[\\/])?themes[\\/]/.test(id) || /@shikijs[\\/]themes[\\/]/.test(id)) {
              return 'assets/shiki-theme-[name].[hash].js'
            }
            return 'assets/[name].[hash].js'
          },
          entryFileNames: 'assets/[name].[hash].js',
          sourcemapFileNames: (chunkInfo) => {
            const id = chunkInfo.facadeModuleId || ''
            if (/[\\/]shiki[\\/](?:dist[\\/])?langs[\\/]/.test(id) || /@shikijs[\\/]langs[\\/]/.test(id)) {
              return 'assets/shiki-lang-[name].[hash].js.map'
            }
            if (/[\\/]shiki[\\/](?:dist[\\/])?themes[\\/]/.test(id) || /@shikijs[\\/]themes[\\/]/.test(id)) {
              return 'assets/shiki-theme-[name].[hash].js.map'
            }
            return 'assets/[name].[hash].js.map'
          },
          manualChunks: {
            'vendor-react': ['react', 'react-dom', 'react-router-dom'],
            'vendor-apollo': ['@apollo/client', 'graphql'],
            'vendor-mui': ['@mui/material', '@mui/x-date-pickers'],
            'vendor-charts': ['recharts'],
            'vendor-editor': ['ace-builds', 'react-ace'],
            'vendor-sentry': ['@sentry/react'],
            'vendor-forms': ['formik', 'yup', 'zod'],
          },
        },
      },
      exclude: ['packages/**'],
    },
  }
})
