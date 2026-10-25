; extends

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
