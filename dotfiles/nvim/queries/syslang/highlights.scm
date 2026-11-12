; extends

; Outline markers include the separator space; keep it visible after the icon.
((outline_1_marker) @slang.outline_1.marker
  (#set! priority 110)
  (#offset! @slang.outline_1.marker 0 1 0 0)
  (#set! conceal " "))

((outline_2_marker) @slang.outline_2.marker
  (#set! priority 110)
  (#offset! @slang.outline_2.marker 0 2 0 0)
  (#set! conceal " "))

((outline_3_marker) @slang.outline_3.marker
  (#set! priority 110)
  (#offset! @slang.outline_3.marker 0 3 0 0)
  (#set! conceal " "))

((outline_4_marker) @slang.outline_4.marker
  (#set! priority 110)
  (#offset! @slang.outline_4.marker 0 4 0 0)
  (#set! conceal " "))

((outline_5_marker) @slang.outline_5.marker
  (#set! priority 110)
  (#offset! @slang.outline_5.marker 0 5 0 0)
  (#set! conceal " "))

((outline_6_marker) @slang.outline_6.marker
  (#set! priority 110)
  (#offset! @slang.outline_6.marker 0 6 0 0)
  (#set! conceal " "))

((task_marker_default) @slang.task_marker_default
  (#set! priority 110)
  (#prose-icon! @slang.task_marker_default "task_default"))

((task_marker_active) @slang.task_active
  (#set! priority 110)
  (#prose-icon! @slang.task_active "task_active"))

((task_marker_done) @slang.task_done
  (#set! priority 110)
  (#prose-icon! @slang.task_done "task_done"))

((task_marker_cancelled) @slang.task_cancelled
  (#set! priority 110)
  (#prose-icon! @slang.task_cancelled "task_cancelled"))

((list_item_marker) @slang.list_item_marker
  (#set! priority 110)
  (#prose-icon! @slang.list_item_marker "bullet"))

((image_start) @slang.image
  (#set! priority 110)
  (#offset! @slang.image 0 0 0 -1)
  (#prose-icon! @slang.image "image"))

((image_start) @slang.image
  (#set! priority 111)
  (#offset! @slang.image 0 1 0 0)
  (#set! conceal " "))
