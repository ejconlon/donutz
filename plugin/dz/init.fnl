;; Objects ---------------------------------------

(fn obj-add-getter [key t]
  (tset t key (fn [obj] (. obj key))))

(fn obj-add-setter [key t]
  (tset t key (fn [obj val] (tset obj key val))))

(fn obj-add-child [key child t]
  (tset t key (error "TODO")))

(fn obj-proxy-mk [attrs vars methods children ofn]
  (local getters {})
  (local setters {})
  (local children {})
  (each [_ key (ipairs attrs)]
    (obj-add-getter key getters))
  (each [_ key (ipairs vars)]
    (obj-add-getter key getters)
    (obj-add-setter key setters))
  (each [key child (pairs children)]
    (obj-add-child key child children))
  (fn run-getter [key]
    (let [mg (. getters key)]
      nil nil
      g (g (ofn))))
  (fn run-child [key]
    (let [mc (. children key)]
      (case mc
        nil nil
        c (c.get (ofn)))))
  (fn index [key] 
    (let [mgr (run-getter key)]
      (case mgr
        nil (let [mcr (run-child key)]
              (case mcr
                nil (error (.. "Invalid reference: " key)))
                cr cr)
        gr gr)))
  (fn newindex [key val] 
    (let [ms (. setters key)]
      (case ms
        nil (error (.. "Invalid assignment: " key))
        _ (s (ofn) val))))
  (local prox
    (collect [key func (pairs methods)] (values key (fn [...] (func (ofn) ...)))))
  (fn prox.__dict []
    (local d {})
    (local obj (ofn))
    (collect [key getter (pairs getters)] (values key (getter obj))))
  ; TODO copy from dict to obj
  (fn prox.__fill [t]
    (local x 1))
  (setmetatable prox
    { :__metatable false
      :__tostring (fn [_] (show t))
      :__index (fn [_ key] (index key))
      :__newindex  (fn [_ key val] (newindex key val))
    }
  ))

;; Instruments ---------------------------------------

(local inst-attrs [])

(local inst-vars [:name :volume :transpose])

(local inst-methods 
  { :clear (fn [obj] (: obj :clear))
  })

(local inst-children
  { :samples
    { :wrap samp-mk
      :get (fn [obj] (. obj :samples))
      :array
      { :lookup (fn [obj ix] (: obj :sample ix))
        :insert (fn [obj ix c] (: obj :insert_sample_at ix c))
        :delete (fn [obj ix] (: obj :delete_sample_at ix))
      }
    }
  })

(fn inst-mk [ofn] (obj-proxy-mk inst-attrs inst-vars inst-methods inst-children ofn))

;; Samples ---------------------------------------

(local samp-attrs [])

(local samp-vars [:name :panning :volume :transpose :fine_tune])

(local samp-methods 
  { :clear (fn [obj] (: obj :clear))
  })

(local samp-children
  {
  })

(fn samp-mk [ofn] (obj-proxy-mk samp-attrs samp-vars samp-methods samp-children ofn))

;; Tracks ---------------------------------------

; (fn raw-track-list [] (. (renoise.song) :tracks))
;
; (fn raw-track-get [ix] (: (renoise.song) :track ix))

; (local track-vars [:name :mute_state :solo_state])
;
; (local track-methods 
;   { :mute (fn [obj] (: obj :mute))
;     :unmute (fn [obj] (: obj :unmute))
;     :solo (fn [obj] (: obj :solo))
;   })
;
; (fn track-mk [ofn] (obj-proxy-mk track-vars track-methods ofn))
;
; (fn track-get [ix] (track-mk (fn [] (raw-track-get ix))))
;
; (fn track-len [] (length (raw-track-list)))

;; Patterns ---------------------------------------

; (fn raw-pat-list [] (. (renoise.song) :patterns))
;
; (fn raw-pat-get [ix] (: (renoise.song) :pattern ix))
;
; (local pat-vars [])
;
; (local pat-methods 
;   { 
;   })
;
; (fn pat-mk [ofn] (obj-proxy-mk pat-vars pat-methods ofn))
;
; (fn pat-get [ix] (pat-mk (fn [] (raw-pat-get ix))))
;
; (fn pat-len [] (length (raw-pat-list)))

;; Songs -----------------------------------------

(local song-attrs [:file_name])

(local song-vars [])

(local song-methods 
  { :render (fn [obj fname] (: obj :render fname))
  })

(local song-children
  { :instruments
    { :wrap inst-mk
      :get (fn [obj] (. obj :instruments))
      :array
      { :lookup (fn [obj ix] (: obj :instruments ix))
        :insert (fn [obj ix c] (: obj :insert_instrument_at ix c))
        :delete (fn [obj ix] (: obj :delete_instrument_at ix))
      }
    }
  })

(fn song-mk [ofn] (obj-proxy-mk song-attrs song-vars song-methods song-children ofn))

(fn song-get [] (song-mk renoise.song))

;; Exports ---------------------------------------

{ : song-get
}
