;; Objects ---------------------------------------

(fn obj-add-getter [key t]
  (tset t key
    (fn [obj] (. obj key))))

(fn obj-add-setter [key t]
  (tset t key
    (fn [obj val] (tset obj key val))))

(fn obj-add-child [key child t]
  (tset t key
    (fn [ofn]
      (case child.array
        nil (child.wrap ofn)
        _ ((arr-proxy-mk child) ofn)))))

(fn obj-proxy-mk [defn]
  (fn [ofn]
    (local getters {})
    (local setters {})
    (local children {})
    (each [_ key (ipairs (or defn.attrs []))]
      (obj-add-getter key getters))
    (each [_ key (ipairs (or defn.vars []))]
      (obj-add-getter key getters)
      (obj-add-setter key setters))
    (each [key child (pairs (or defn.children []))]
      (obj-add-child key child children))
    (fn run-getter [key]
      (let [mg (. getters key)]
        nil nil
        g (g (ofn))))
    (fn run-child [key]
      (let [mc (. children key)]
        (case mc
          nil nil
          c (c ofn))))
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
      (collect [key func (pairs (or defn.methods []))]
        (values key (fn [...] (func (ofn) ...)))))
    (fn prox.__tojson []
      (local obj (ofn))
      (fn ofnx [] obj)
      (local t {})
      (each [key getter (pairs getters)]
        (tset t key (tojson (getter obj))))
      (each [key child (pairs getters)]
        (tset t key (tojson (child ofnx))))
      t)
    ; (fn prox.__fromjson [t]
    ;   ; TODO copy from dict to obj
    ;   (error "TODO"))
    (tset prox :__ofn ofn)
    (setmetatable prox
      { :__metatable false
        :__tostring (fn [_] (show t))
        :__index (fn [_ key] (index key))
        :__newindex  (fn [_ key val] (newindex key val))
      }
    )))

(fn arr-proxy-mk [defn]
  (fn [ofn]
    (error "TODO")))

;; Sequencer -----------------------------------------

(local sequ-mk (obj-proxy-mk
  {
  }))

;; Instruments ---------------------------------------

(local inst-mk (obj-proxy-mk
  { :vars [:name :volume :transpose]
    :methods 
    { :clear (fn [obj] (: obj :clear))
    }
    :children
    { :samples
      { :wrap samp-mk
        :get (fn [obj] obj.samples)
        :array
        { :lookup (fn [obj ix] (: obj :sample ix))
          :insert (fn [sub ix c] (: sub :insert_sample_at ix c))
          :delete (fn [sub ix] (: sub :delete_sample_at ix))
        }
      }
    }
  }))

;; Samples ---------------------------------------

(local samp-mk (obj-proxy-mk
  { :vars [:name :panning :volume :transpose :fine_tune]
    :methods
    { :clear (fn [obj] (: obj :clear))
    }
  }))

;; Tracks ---------------------------------------

(local track-mk (obj-proxy-mk
  { :vars [:name :mute_state :solo_state]
    :methods 
    { :mute (fn [obj] (: obj :mute))
      :unmute (fn [obj] (: obj :unmute))
      :solo (fn [obj] (: obj :solo))
    }
  }))

;; Patterns ---------------------------------------

(local pat-mk (obj-proxy-mk
  { 
  }))

;; Songs -----------------------------------------


(local song-mk (obj-proxy-mk
  { :attrs [:file_name]
    :methods
    { :render (fn [obj fname] (: obj :render fname))
    }
    :children
    { :sequencer
      { :wrap sequ-mk
        :get (fn [obj] obj.sequencer)
      }
      :instruments
      { :wrap inst-mk
        :get (fn [obj] obj.instruments)
        :array
        { :lookup (fn [obj ix] (: obj :instruments ix))
          :insert (fn [sub ix c] (: sub :insert_instrument_at ix c))
          :delete (fn [sub ix] (: sub :delete_instrument_at ix))
        }
      }
    }
  }))
   

(local song (song-mk (fn [] (renoise.song))))

;; Exports ---------------------------------------

{ : song
}
