#!/usr/bin/env node

const fs = require('fs')
const path = require('path')

const TRANSLATIONS_DIR = path.join(__dirname, 'translations')
const BASE_FILE = 'base.json'

// ANSI color codes for better output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
}

function readJsonFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8')
    return JSON.parse(content)
  } catch (error) {
    console.error(`${colors.red}Error reading ${filePath}:${colors.reset}`, error.message)
    process.exit(1)
  }
}

function getAllKeys(obj, prefix = '') {
  let keys = []
  for (const key in obj) {
    const fullKey = prefix ? `${prefix}.${key}` : key
    if (typeof obj[key] === 'object' && obj[key] !== null && !Array.isArray(obj[key])) {
      keys = keys.concat(getAllKeys(obj[key], fullKey))
    } else {
      keys.push(fullKey)
    }
  }
  return keys
}

function main() {
  console.log(`${colors.cyan}=== Translation Files Validator ===${colors.reset}\n`)

  // Read base file
  const basePath = path.join(TRANSLATIONS_DIR, BASE_FILE)
  if (!fs.existsSync(basePath)) {
    console.error(`${colors.red}Error: Base file not found at ${basePath}${colors.reset}`)
    process.exit(1)
  }

  const baseJson = readJsonFile(basePath)
  const baseKeys = new Set(getAllKeys(baseJson))

  console.log(`${colors.blue}Base file:${colors.reset} ${BASE_FILE}`)
  console.log(`${colors.blue}Total keys in base:${colors.reset} ${baseKeys.size}\n`)

  // Get all translation files (excluding base.json)
  const files = fs
    .readdirSync(TRANSLATIONS_DIR)
    .filter((file) => file.endsWith('.json') && file !== BASE_FILE)
    .sort()

  if (files.length === 0) {
    console.log(`${colors.yellow}No translation files found (other than base.json)${colors.reset}`)
    return
  }

  console.log(`${colors.blue}Translation files to check:${colors.reset} ${files.join(', ')}\n`)
  console.log(`${'='.repeat(80)}\n`)

  let hasErrors = false
  const results = []

  // Check each translation file
  for (const file of files) {
    const filePath = path.join(TRANSLATIONS_DIR, file)
    const json = readJsonFile(filePath)
    const keys = new Set(getAllKeys(json))

    // Find missing keys (in base but not in translation)
    const missingKeys = [...baseKeys].filter((key) => !keys.has(key))

    // Find extra keys (in translation but not in base)
    const extraKeys = [...keys].filter((key) => !baseKeys.has(key))

    results.push({
      file,
      totalKeys: keys.size,
      missingKeys,
      extraKeys,
      isValid: missingKeys.length === 0 && extraKeys.length === 0,
    })

    if (missingKeys.length > 0 || extraKeys.length > 0) {
      hasErrors = true
    }
  }

  // Display results
  for (const result of results) {
    if (result.isValid) {
      console.log(`${colors.green}✓ ${result.file}${colors.reset}`)
      console.log(`  Total keys: ${result.totalKeys} (matches base)\n`)
    } else {
      console.log(`${colors.red}✗ ${result.file}${colors.reset}`)
      console.log(`  Total keys: ${result.totalKeys} (base has ${baseKeys.size})`)

      if (result.missingKeys.length > 0) {
        console.log(`  ${colors.red}Missing keys: ${result.missingKeys.length}${colors.reset}`)
        result.missingKeys.slice(0, 10).forEach((key) => {
          console.log(`    - ${key}`)
        })
        if (result.missingKeys.length > 10) {
          console.log(`    ... and ${result.missingKeys.length - 10} more`)
        }
      }

      if (result.extraKeys.length > 0) {
        console.log(`  ${colors.yellow}Extra keys: ${result.extraKeys.length}${colors.reset}`)
        result.extraKeys.slice(0, 10).forEach((key) => {
          console.log(`    - ${key}`)
        })
        if (result.extraKeys.length > 10) {
          console.log(`    ... and ${result.extraKeys.length - 10} more`)
        }
      }

      console.log()
    }
  }

  // Summary
  console.log(`${'='.repeat(80)}\n`)
  const validFiles = results.filter((r) => r.isValid).length
  const totalFiles = results.length

  if (hasErrors) {
    console.log(`${colors.red}Validation failed!${colors.reset}`)
    console.log(`${validFiles}/${totalFiles} files are valid\n`)

    // Provide summary of issues
    const totalMissing = results.reduce((sum, r) => sum + r.missingKeys.length, 0)
    const totalExtra = results.reduce((sum, r) => sum + r.extraKeys.length, 0)

    if (totalMissing > 0) {
      console.log(
        `${colors.red}Total missing keys across all files: ${totalMissing}${colors.reset}`,
      )
    }
    if (totalExtra > 0) {
      console.log(`${colors.yellow}Total extra keys across all files: ${totalExtra}${colors.reset}`)
    }

    process.exit(1)
  } else {
    console.log(`${colors.green}✓ All translation files are valid!${colors.reset}`)
    console.log(`${validFiles}/${totalFiles} files checked successfully\n`)
  }
}

main()
