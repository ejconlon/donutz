(fn hello [] "hello")

;; TODO
(fn example-song! [] nil)

; ;; From 8fl
; (fn clear-song! []
;   (let [song (renoise.song)]
;     (while (< 1 (# (. song :sequencer :pattern_sequence)))
;       (: (. song :sequencer) :delete_sequence_at
;         (# (. song :sequencer :pattern_sequence))))
;     (: (. song :patterns 1) :clear)))

(fn get-pat [ix]
  (. (renoise.song) :patterns ix))

(fn rep-pat [p]
  {  ; TODO
  })

(fn clear-pat! [i]
  (: i :clear))

(fn get-inst [ix]
  (. (renoise.song) :instruments ix))

(fn rep-inst [i]
  { ; TODO
    :name (. i name)
    :samples (icollect [_ s (ipairs (. i :samples))] rep-samp)
  })

(fn clear-inst! [i]
  (: i :clear))

(fn rep-samp [i]
  { ; TODO
  })

{ : hello
  : example-song!
  : get-pat
  : rep-pat
  : clear-pat!
  : get-inst
  : rep-inst
  : clear-inst!
  : rep-samp
}
