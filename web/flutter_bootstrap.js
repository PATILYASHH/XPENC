{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // No `serviceWorkerSettings`: Flutter's own service worker would claim the
  // same scope as XPENC web's (sw.js, registered by index.html) and the two
  // would keep replacing each other.
  config: {
    // Offline from the first byte: the rendering engine ships next to the
    // app instead of loading from Google's CDN...
    canvasKitBaseUrl: 'canvaskit/',
    // ...and so do fallback fonts, which Flutter would otherwise fetch from
    // fonts.gstatic.com. Only Roboto is here (fallback_fonts/); a glyph no
    // bundled font has shows as a box rather than reaching out.
    fontFallbackBaseUrl: 'fallback_fonts/',
  },
});
