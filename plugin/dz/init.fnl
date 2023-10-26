
; (fn pat-get-all []
;   (. (renoise.song) :patterns))
;
; (fn pat-get [ix]
;   (. (renoise.song) :patterns ix))
;
; (fn pat-rep [pat]
;   {  ; TODO
;   })
;
; (fn pat-clear! [pat]
;   (: pat :clear))

;; Objects ---------------------------------------

(macro lens-mk [key ofn]
   `{ :getter (fn [] (. (,ofn) ,key))
      :setter (fn [val#] (tset (,ofn) ,key val#))})

(fn obj-proxy-mk [fields methods ofn]
  (local lenses
    (collect [_ key (ipairs fields)] (values key (lens-mk key ofn))))
  (local prox
    (collect [key func (pairs methods)] (values key (fn [...] (func (ofn) ...)))))
  (fn prox.__dict []
    (collect [_ key (ipairs fields)] (values key ((. lenses key :getter)))))
  (setmetatable prox
    { :__metatable
        false
      :__tostring
        (fn [_]
          (show t))
      :__index 
        (fn [_ key]
          (let [g (?. lenses key :getter)] (when (~= g nil) (g))))
      :__newindex 
        (fn [_ key val]
          (let [s (?. lenses key :setter)] (s val)))
    }
  ))

;; Instruments ---------------------------------------

(fn raw-inst-list [] (. (renoise.song) :instruments))

(fn raw-inst-get [ix] (: (renoise.song) :instrument ix))

; (fn raw-inst-ensure [ix] {})

(local inst-fields [:name :volume :transpose])

(local inst-methods 
  { :clear (fn [obj] (: obj :clear))
  })

(fn inst-mk [ofn] (obj-proxy-mk inst-fields inst-methods ofn))

(fn inst-get [ix] (inst-mk (fn [] (raw-inst-get ix))))

(fn inst-len [] (length (raw-inst-list)))

; (fn inst-rep [inst]
;   { ; TODO
;     :name (. inst :name)
;     :samples (icollect [_ s (ipairs (. inst :samples))] rep-samp)
;     :volume (. inst :volume)
;     :transpose (. inst :transpose)
;   })
;
; (fn samp-get [inst ix]
;   (. inst :samples ix))
;
; (fn samp-load! [samp fname]
;   ((: (. s :sample-buffer) :load-from) fname))

;; Tracks ---------------------------------------

(fn raw-track-list [] (. (renoise.song) :tracks))

(fn raw-track-get [ix] (: (renoise.song) :track ix))

(local track-fields [:name :mute_state :solo_state])

(local track-methods 
  { :mute (fn [obj] (: obj :mute))
    :unmute (fn [obj] (: obj :unmute))
    :solo (fn [obj] (: obj :solo))
  })

(fn track-mk [ofn] (obj-proxy-mk track-fields track-methods ofn))

(fn track-get [ix] (track-mk (fn [] (raw-track-get ix))))

(fn track-len [] (length (raw-track-list)))

;; Patterns ---------------------------------------

(fn raw-pat-list [] (. (renoise.song) :patterns))

(fn raw-pat-get [ix] (: (renoise.song) :pattern ix))

(local pat-fields [])

(local pat-methods 
  { 
  })

(fn pat-mk [ofn] (obj-proxy-mk pat-fields pat-methods ofn))

(fn pat-get [ix] (pat-mk (fn [] (raw-pat-get ix))))

(fn pat-len [] (length (raw-pat-list)))


;; Exports ---------------------------------------

{ : inst-get
  : inst-len
  : track-get
  : track-len
  : pat-get 
  : pat-len
}
