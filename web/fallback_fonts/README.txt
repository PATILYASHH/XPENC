Roboto Regular (Apache License 2.0, Google), from the Flutter SDK's
material_fonts artifacts. It sits under the path Flutter's web engine asks
for its default fallback font, so XPENC web never fetches it from
fonts.gstatic.com (see ../flutter_bootstrap.js). The file is TrueType despite
the .woff2 name the engine requests; the renderer reads it by content.
