(fn hello [] "hello")

;; TODO
(fn example-song! [] nil)

;; From 8fl
(fn clear-song! []
  (let [song (renoise.song)]
    (while (< 1 (# (. song :sequencer :pattern_sequence)))
      (: (. song :sequencer) :delete_sequence_at
        (# (. song :sequencer :pattern_sequence))))
    (: (. song :patterns 1) :clear)))


{ : hello
  : example-song!
  : clear-song!
}
