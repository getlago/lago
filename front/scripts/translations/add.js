/* eslint no-console: ["error", { allow: ["info"] }] */
import fs from 'node:fs'

const KEY_RANDOM_CHARS_LENGTH = 11
const TRANSLATIONS_FOLDER = './translations'
const baseTranslationsFile = 'base.json'

function createRandomCharChain() {
  let result = ''
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789'
  const charactersLength = characters.length
  let counter = 0

  while (counter < KEY_RANDOM_CHARS_LENGTH) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength))
    counter += 1
  }
  return result
}

function extractFiles(isIntl) {
  const files = fs.readdirSync(TRANSLATIONS_FOLDER)

  if (isIntl) {
    return files
  }

  return files.filter((file) => file.includes(baseTranslationsFile))
}

function generateNewKeys(count) {
  const allTranslationsFromBaseFile = JSON.parse(
    fs.readFileSync(`${TRANSLATIONS_FOLDER}/${baseTranslationsFile}`),
    'utf-8',
  )
  // Ignore timezone keys as they're used in the config without calling translate
  const existingKeysInTranslationFile = Object.keys(allTranslationsFromBaseFile).filter(
    (key) => key.split('_')[0] !== 'TZ',
  )

  const newKeys = {}

  for (let i = 0; i < Number(count); i++) {
    const key = `text_${Date.now() + createRandomCharChain()}`

    if (newKeys[key] || existingKeysInTranslationFile.includes(key)) {
      i--
      continue
    }

    newKeys[key] = ''
  }

  return newKeys
}

async function addNewTranslationsKey({ count, isIntl }) {
  const files = extractFiles(isIntl)
  const newKeys = generateNewKeys(count)

  files.forEach((file) => {
    const filePath = `${TRANSLATIONS_FOLDER}/${file}`
    const allTranslationsFromFile = JSON.parse(fs.readFileSync(filePath), 'utf-8')

    // Append the new keys to the existing ones in the file
    const updatedTranslations = { ...allTranslationsFromFile, ...newKeys }

    // Write the updated translations back to the file
    fs.writeFileSync(filePath, JSON.stringify(updatedTranslations, null, 2), 'utf-8')
  })
}

/**
 * Extract wrapper
 */
async function main() {
  try {
    const args = process.argv.slice(2)
    let isIntl

    if (args.find((arg) => arg === '--intl')) {
      isIntl = true
    } else {
      isIntl = false
    }

    const count = args.filter((arg) => !arg.startsWith('--'))[0] || '1'

    await addNewTranslationsKey({ count: Number(count), isIntl })

    console.info('\u001b[' + 32 + 'm' + '✔ All good' + '\u001b[0m')
  } catch (error) {
    console.info('\u001b[' + 31 + 'm' + '\nTranslation keys addition failed' + '\u001b[0m', error)
    process.exit(1)
  }
}

main()
