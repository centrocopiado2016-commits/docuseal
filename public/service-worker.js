self.addEventListener('install', () => {
  console.log('DocuIzzi App installed')
})

self.addEventListener('activate', () => {
  console.log('DocuIzzi App activated')
})

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})
