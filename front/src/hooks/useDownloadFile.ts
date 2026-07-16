import { addToast } from '~/core/apolloClient'

export const useDownloadFile = () => {
  const showDownloadError = () => {
    addToast({
      severity: 'danger',
      translateKey: 'text_1760517105743y1n6z2u1063',
    })
  }

  // Use this function to download a file from a given URL that has no CORS issues
  const downloadFileFromURL = async (fileName: string, url?: string | null) => {
    if (!url) {
      showDownloadError()
      return
    }

    try {
      const response = await fetch(url)
      const blob = await response.blob()
      const objectUrl = window.URL.createObjectURL(blob)
      const link = document.createElement('a')

      link.href = objectUrl
      link.setAttribute('download', fileName)
      document.body.appendChild(link)
      link.click()
      link.remove()
      window.URL.revokeObjectURL(objectUrl)
    } catch {
      showDownloadError()
    }
  }

  const openNewTab = (url: string) => {
    // We open a window, add url then focus on different lines, in order to prevent browsers to block page opening
    // It could be seen as unexpected popup as not immediatly done on user action
    // https://stackoverflow.com/questions/2587677/avoid-browser-popup-blockers
    // Also, we need to use setTimeout to avoid Safari blocking the popup
    setTimeout(() => {
      const myWindow = window.open('', '_blank')

      if (myWindow?.location?.href) {
        myWindow.location.href = url
        return myWindow?.focus()
      }

      myWindow?.close()
      showDownloadError()
    }, 0)
  }

  const openAndCloseTab = (url: string) => {
    // We open a window, add url then focus on different lines, in order to prevent browsers to block page opening
    // It could be seen as unexpected popup as not immediatly done on user action
    // https://stackoverflow.com/questions/2587677/avoid-browser-popup-blockers
    // Also, we need to use setTimeout to avoid Safari blocking the popup
    setTimeout(() => {
      const myWindow = window.open('', '_blank')

      if (myWindow?.location?.href) {
        myWindow.location.href = url
        myWindow?.focus()

        // Timeout so we can close the tab after the download is launched
        // 500ms should be enough, and we don't want to keep the tab opened for too long
        setTimeout(() => {
          myWindow?.close()
        }, 500)
        return
      }

      myWindow?.close()
      showDownloadError()
    }, 0)
  }

  const handleDownloadFile = (fileUrl?: string | null) => {
    if (!fileUrl) return showDownloadError()

    openNewTab(fileUrl)
  }

  // Use this function to download a file from a given URL that has CORS issues
  // this will open the file in a new tab, let the browser download the file then close the tab
  const handleDownloadFileWithCors = (fileUrl?: string | null) => {
    if (!fileUrl) return showDownloadError()

    openAndCloseTab(fileUrl)
  }

  return { downloadFileFromURL, handleDownloadFile, openNewTab, handleDownloadFileWithCors }
}
