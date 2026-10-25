; extends

(inline_link
  (link_text) @markup.link.external
  (link_destination) @_destination
  (#prose-external-link? @_destination)
  (#set! priority 110))

(image
  "!" @markup.image
  (#prose-icon! @markup.image "image")
  (#set! priority 110))

(image
  "[" @markup.image
  (#set! conceal " ")
  (#set! priority 110))

(image (image_description) @markup.image)
