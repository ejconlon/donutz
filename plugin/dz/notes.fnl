;; Much of this is from 8fl

(local note-names [:c- :c# :d- :d# :e- :f- :f# :g- :g# :a- :a# :b-])
(local note-map { :names {} :values {} })

(for [i 0 119]
  (let [note (. note-names (+ 1 (% i 12))
        octave (math.floor (/ i 12))
        note-string (string.format "%s%d" note octave)]
    (tset note-map.names note-string i)
    (tset note-map.values i note-string)))

(fn get-note-value [note]
  "Maps note numbers or names to note numbers"
  (match (type note)
    :number note
    :string (. note-map.names note)))

(fn get-note-name [note]
  "Maps note number to note name"
  (match (type note)
    :string note
    :number (. note-map.values note)))

(fn scale [intervals root]
  "Yields a sequence of note values given a list of intervals and root note"
  (let [root (get-note-value (string.lower (or root :c-4)))
        out (match (type root)
              :number get-note-value
              :string get-note-name)]
    (resumable
     (var root (get-note-value root))
     (foreign.coroutine.yield (out root))
     (each [x (seq.cycle intervals)]
       (set root (+ root x))
       (if (< root 128)
         (foreign.coroutine.yield (out root))
         (lua "return"))))))

(fn chord [root intervals]
  "Given root note and list of semitone intervals, return vector of note names"
  (let [rval (get-note-value root)
        vec [(get-note-name root)]]
    (each [_ iv (ipairs intervals)]
      (table.insert vec (get-note-name (+ rval iv))))
    vec))

(fn maj [root] (chord root [4 7]))
(fn min [root] (chord root [3 7]))
;
; {: chord : maj : min }

{ : get-note-value : get-note-name : scale : chord : maj : min }

