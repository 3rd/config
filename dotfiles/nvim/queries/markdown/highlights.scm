; extends

(atx_h1_marker) @markup.heading.1.marker
(atx_h2_marker) @markup.heading.2.marker
(atx_h3_marker) @markup.heading.3.marker
(atx_h4_marker) @markup.heading.4.marker
(atx_h5_marker) @markup.heading.5.marker
(atx_h6_marker) @markup.heading.6.marker
(setext_h1_underline) @markup.heading.1.marker
(setext_h2_underline) @markup.heading.2.marker

((fenced_code_block_delimiter) @markup.raw.delimiter
  (#set! priority 110))

[(list_marker_dot) (list_marker_parenthesis)] @markup.list.numbered

(link_reference_definition
  (link_destination) @markup.link.external
  (#prose-external-link? @markup.link.external))
