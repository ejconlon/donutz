;; Objects ---------------------------------------

(fn arr-proxy-mk [defn]
  (fn [ofn]
    (fn rawLen [obj] (length (defn.get (ofn))))

    (local prox {})

    (fn prox.__index [key]
      (local len (rawLen (ofn)))
      (if (and (= (type key) "number") (> key 0) (<= key len))
        (defn.wrap (fn [] (defn.array.lookup (ofn) key)))
        nil))

    (fn prox.__len [] (rawLen (ofn)))

    (fn prox.__iter []
      (local len (rawLen (ofn)))
      (fn it [sub i]
        (local j (+ i 1))
        (if (< i len) 
          (values j (prox.__index j))
          nil))
      (values it {} 0)) 

    (fn prox.__tojson []
      (icollect [_ v (ipairs (defn.get (ofn)))] (tojson (defn.wrap (fn [] v)))))

    (fn prox.__fromjson [t]
      (local tlen (length t))
      (prox.__resize tlen)
      (for [ix 1 tlen] ((. (prox.__index ix) :__fromjson) (. t ix))))

    (fn prox.__alloc []
      (local obj (ofn))
      (local ix (+ 1 (rawLen obj)))
      (defn.array.insert obj ix)
      (prox.__index ix))

    (fn prox.__resize [?size]
      (local size (case ?size nil 0 l l))
      (local mn (case defn.array.minlen nil 0 l l))
      (local goal (if (> mn size) mn size))
      (local obj (ofn))
      (local len (rawLen obj))
      (if (< len goal) 
          (do
            (var ix len)
            (while (< ix goal) (defn.array.insert obj ix) (set ix (+ ix 1))))
          (> len goal)
          (do
            (var ix len)
            (while (> ix goal) (defn.array.delete obj ix) (set ix (- ix 1))))))

    (setmetatable prox
                  {:__metatable false
                   :__tostring (fn [_] (show t))
                   :__ipairs (fn [_] (prox.__iter))
                   :__len (fn [_] (prox.__len))
                   :__index (fn [_ key] (prox.__index key))
                   :__newindex (fn [_ _ _] (error "Use __alloc/__resize"))})))

(fn obj-add-getter [key t]
  (tset t key (fn [obj] (. obj key))))

(fn obj-add-setter [key t]
  (tset t key (fn [obj val] (tset obj key val))))

(fn obj-add-child [key child t ofn]
  (tset t key (case child.array
                  nil (child.wrap (fn [] (child.get (ofn))))
                  _ ((arr-proxy-mk child) ofn))))

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
      (obj-add-child key child children ofn))

    (fn run-getter [key]
      (let [mg (. getters key)]
        (case mg
          nil nil
          g (g (ofn)))))

    (local prox (collect [key func (pairs (or defn.methods []))]
                  (values key (fn [...] (func (ofn) ...)))))

    (fn prox.__index [key]
      (let [mgr (run-getter key)]
        (case mgr
          nil (let [mcr (. children key)]
                (case mcr
                  nil (error (.. "Invalid reference: " key))
                  cr cr))
          gr gr)))

    (fn prox.__newindex [key val]
      (let [ms (. setters key)]
        (case ms
          nil (error (.. "Invalid assignment: " key))
          s (s (ofn) val))))

    (fn prox.__tojson []
      (local obj (ofn))
      (local t {})
      (each [key getter (pairs getters)]
        (tset t key (tojson (getter obj))))
      (each [key child (pairs children)]
        (tset t key (tojson child)))
      t)

    (fn prox.__fromjson [t]
      (local obj (ofn))
      (each [key setter (pairs setters)]
        (case (. t key)
          nil nil
          val (setter obj val)))
      (each [key child (pairs children)]
        (case (. t key)
          nil nil
          val (child.__fromjson val))))

    (setmetatable prox
                  {:__metatable false
                   :__tostring (fn [_] (show t))
                   :__index (fn [_ key] (prox.__index key))
                   :__newindex (fn [_ key val] (prox.__newindex key val))})))

;; Sequencer -----------------------------------------

(local sequ-mk (obj-proxy-mk {}))

;; Instruments ---------------------------------------

(local inst-mk
       (obj-proxy-mk {:vars [:name :volume :transpose]
                      :methods {:clear (fn [obj] (: obj :clear))}
                      :children {:samples {:wrap samp-mk
                                           :get (fn [obj] obj.samples)
                                           :array {:lookup (fn [obj ix]
                                                             (: obj :sample ix))
                                                   :insert (fn [obj ix]
                                                             (: obj 
                                                                :insert_sample_at
                                                                ix))
                                                   :delete (fn [obj ix]
                                                             (: obj 
                                                                :delete_sample_at
                                                                ix))}}}}))

;; Samples ---------------------------------------

(local samp-mk
       (obj-proxy-mk {:vars [:name :panning :volume :transpose :fine_tune]
                      :methods {:clear (fn [obj] (: obj :clear))}}))

;; Tracks ---------------------------------------

(local track-mk
       (obj-proxy-mk {:vars [:name :mute_state :solo_state]
                      :methods {:mute (fn [obj] (: obj :mute))
                                :unmute (fn [obj] (: obj :unmute))
                                :solo (fn [obj] (: obj :solo))}}))

;; Patterns ---------------------------------------

(local pat-mk (obj-proxy-mk {}))

;; Songs -----------------------------------------

(local song-mk
       (obj-proxy-mk {:attrs [:file_name]
                      :methods {:render (fn [obj fname] (: obj :render fname))}
                      :children {:sequencer {:wrap sequ-mk
                                             :get (fn [obj] obj.sequencer)}
                                 :instruments {:wrap inst-mk
                                               :get (fn [obj] obj.instruments)
                                               :array { :minlen 1
                                                        :lookup (fn [obj ix]
                                                                 (: obj
                                                                    :instrument
                                                                    ix))
                                                         :insert (fn [obj ix]
                                                                   (: obj
                                                                      :insert_instrument_at
                                                                      ix))
                                                         :delete (fn [obj ix]
                                                                   (: obj
                                                                      :delete_instrument_at
                                                                      ix))}}}}))

(local song (song-mk (fn [] (renoise.song))))

;; Exports ---------------------------------------

{: song }
