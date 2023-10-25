
(fn pat-get-all []
  (. (renoise.song) :patterns))

(fn pat-get [ix]
  (. (renoise.song) :patterns ix))

(fn pat-rep [pat]
  {  ; TODO
  })

(fn pat-clear! [pat]
  (: pat :clear))

(macro lens-mk [key ofn]
   `{ :getter (fn [] (. (,ofn) ,key))
      :setter (fn [val#] (tset (,ofn) ,key val#))})

(fn proxy-mk [keys ofn]
  (local lenses
    (collect [_ key (ipairs keys)] (values key (lens-mk key ofn))))
  (local t {})
  (fn t.dict []
    (collect [_ key (ipairs keys)] (values key ((. lenses key :getter)))))
  (fn t.show []
    (show (t.dict)))
  ; TODO this kind of thing is per-model - define on inst
  ; (fn t.clear []
  ;   (: (ofn) :clear))
  (setmetatable t
    { :__metatable
        false
      :__tostring
        (fn [_]
          (show (t.dict)))
      :__index 
        (fn [_ key]
          (let [g (?. lenses key :getter)] (when (~= g nil) (g))))
      :__newindex 
        (fn [_ key val]
          (let [s (?. lenses key :setter)] (s val)))
    }
  ))

(local inst-keys [:name :volume])

(fn inst-mk [ofn]
  (proxy-mk inst-keys ofn))

(fn inst-get [ix]
  (inst-mk (fn [] (. (renoise.song) :instruments ix))))

(fn inst-len [] (length (. (renoise.song) :instruments)))

; (fn inst-attrs [obj]
;   (local keys [:name :volume]
;   (collect [_ key ipairs(inst-keys)]
;   { :name (mk-lens obj :name)
;     :volume (mk-lens obj :volume)
;     :
;   })
;
; (fn inst-new [obj]
;   (local attrs
;     {[:name])
;   (setmetatable {}
;     { :__metatable false
;       :__index
;       (fn [_ key]
;         (print (.. "Got " key))
;         (case key
;           :name (. obj :name)))
;       :__newindex
;       (fn [_ key val]
;         (print (.. "Got " key))
;         (case key
;           :name (tset .obj :name val)))
;       :__tostring
;       (fn [_] "")
;     }))
;
; (fn inst-rep [inst]
;   { ; TODO
;     :name (. inst :name)
;     :samples (icollect [_ s (ipairs (. inst :samples))] rep-samp)
;     :volume (. inst :volume)
;     :transpose (. inst :transpose)
;   })
;
; (fn inst-clear! [inst]
;   (: inst :clear))
;
; (fn samp-get [inst ix]
;   (. inst :samples ix))
;
; (fn samp-rep [samp]
;   { ; TODO
;   })
;
; (fn samp-load! [samp fname]
;   ((: (. s :sample-buffer) :load-from) fname))

{ : inst-get
  : inst-len
}
