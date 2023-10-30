;; Objects ---------------------------------------

(fn arr-proxy-mk [defn]
  (fn [ofn]
    (fn rawLen [obj]
      (length (defn.get obj)))

    (fn rawIndex [obj len key]
      (if (and (= (type key) :number) (> key 0) (<= key len))
          (defn.wrap (fn [] (defn.array.lookup obj key)))
          nil))

    (fn rawIter [obj]
      (local len (rawLen obj))

      (fn it [sub i]
        (local j (+ i 1))
        (if (< i len)
            (values j (rawIndex obj len j))
            nil))

      (values it {} 0))

    (local prox {})

    (fn prox.__len [] (rawLen (ofn)))

    (fn prox.__index [key]
      (local obj (ofn))
      (local len (rawLen obj))
      (rawIndex obj len key))

    (fn prox.__newindex [key val]
      (error "Use __alloc/__resize"))

    (fn prox.__iter [] (rawIter (ofn)))

    (fn prox.__tojson [?opts]
      (icollect [_ v (ipairs (defn.get (ofn)))]
        (tojson (defn.wrap (fn [] v)) ?opts)))

    ; If no insert/delete functions, is array view
    (if (= defn.array.insert nil)
        (do
          (fn prox.__reset [] nil)

          (fn prox.__fromjson [_] nil))
        (do
          (fn rawResize [obj ?size]
            (local size (case ?size nil 0 l l))
            (local mn (case defn.array.minlen nil 0 l l))
            (local goal (if (> mn size) mn size))
            (local len (rawLen obj))
            (if (< len goal)
                (do
                  (var ix len)
                  (while (< ix goal) (defn.array.insert obj ix)
                    (set ix (+ ix 1))))
                (> len goal)
                (do
                  (var ix len)
                  (while (> ix goal) (defn.array.delete obj ix)
                    (set ix (- ix 1))))))

          (fn prox.__resize [?size] (rawResize (ofn) ?size))

          (fn prox.__reset []
            (local obj (ofn))
            (rawResize obj)
            (each [k child (rawIter obj)]
              (child.__reset)))

          (fn prox.__fromjson [t]
            (local obj (ofn))
            (local tlen (length t))
            (rawResize obj tlen)
            (local len (rawLen obj))
            (for [ix 1 tlen]
              (local sub (rawIndex obj len ix))
              (local u (. t ix))
              (sub.__fromjson u)))

          (fn prox.__alloc []
            (local obj (ofn))
            (local newLen (+ 1 (rawLen obj)))
            (defn.array.insert obj newLen)
            (rawIndex obj newLen newLen))))

    (setmetatable prox
                  {:__metatable false
                   :__tostring (fn [_] (show t))
                   :__ipairs (fn [_] (prox.__iter))
                   :__len (fn [_] (prox.__len))
                   :__index (fn [_ key] (prox.__index key))
                   :__newindex (fn [_ key val] (prox.__newindex key val))})))

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

    (fn prox.__reset []
      (if (and (~= defn.methods nil) (~= defn.methods.clear nil))
        (defn.methods.clear (ofn)))
      (each [k child (pairs children)]
        (child.__reset)))

    (fn prox.__tojson [?opts]
      (local obj (ofn))
      (local t {})
      (each [key getter (pairs getters)]
        (tset t key (tojson (getter obj) ?opts)))
      (each [key child (pairs children)]
        (tset t key (tojson child ?opts)))
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

(local sequ-mk (obj-proxy-mk {:attrs [:pattern_sequence]}))

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

;; Sample buffers ---------------------------------------

(local sbuf-mk
       (obj-proxy-mk {:methods {:load_from (fn [obj fname]
                                             (: obj :load_from fname))
                                :save_as (fn [obj fname fmt]
                                           (: obj :save_as fname fmt))}}))

;; Samples ---------------------------------------

(local samp-mk
       (obj-proxy-mk {:vars [:name :panning :volume :transpose :fine_tune]
                      :children {:sample_buffer {:wrap sbuf-mk
                                                 :get (fn [obj]
                                                        obj.sample_buffer)}}
                      :methods {:clear (fn [obj] (: obj :clear))}}))

;; Tracks ---------------------------------------

(local track-mk
       (obj-proxy-mk {:vars [:name :mute_state :solo_state]
                      :methods {:mute (fn [obj] (: obj :mute))
                                :unmute (fn [obj] (: obj :unmute))
                                :solo (fn [obj] (: obj :solo))}}))

;; Pattern Tracks ---------------------------------

(local ptrack-mk (obj-proxy-mk {}))

;; Patterns ---------------------------------------

(local pat-mk
       (obj-proxy-mk {:children {:tracks {:wrap ptrack-mk
                                          :get (fn [obj] obj.tracks)}}}))

;; Songs -----------------------------------------

; Track array is special. Must be in order
; Track1 Track2 Track3 Master Send1 Send2 ...

(fn song-find-master-track-ix [obj]
  (local tracks (. obj :tracks))
  (var ix 1)
  (var search true)
  (while search
    (local track (. tracks ix))
    (if (= track.type renoise.Track.TRACK_TYPE_MASTER)
        (set search false)
        (set ix (+ ix 1))))
  ix)

(fn song-get-master-track [obj]
  (local mix (song-find-master-track-ix obj))
  (: obj :track mix))

(fn song-get-sequ-tracks [obj]
  (local mix (song-find-master-track-ix obj))
  (local t {})
  (for [ix 1 (- mix 1)] (tset t ix (: obj :track ix)))
  t)

(fn song-lookup-sequ-track [obj ix]
  (local mix (song-find-master-track-ix obj))
  (if (< ix mix) (: obj :track ix) nil))

(fn song-insert-sequ-track [obj ix]
  (: obj :insert_track_at ix))

(fn song-delete-sequ-track [obj ix]
  (: obj :delete_track_at ix))

(fn song-get-send-tracks [obj]
  (local len (length obj.tracks))
  (local mix (song-find-master-track-ix obj))
  (local t {})
  (for [ix 1 (- len mix)]
    (tset t ix (: obj :track (+ ix mix))))
  t)

(fn song-lookup-send-track [obj ix]
  (local mix (song-find-master-track-ix obj))
  (: obj :track (+ ix mix)))

(fn song-insert-send-track [obj ix]
  (local mix (song-find-master-track-ix obj))
  (: obj :insert_track_at (+ ix mix)))

(fn song-delete-send-track [obj ix]
  (local mix (song-find-master-track-ix obj))
  (: obj :delete_track_at (+ ix mix)))

(local song-mk
       (obj-proxy-mk {:attrs [:file_name]
                      :vars [:name]
                      :methods {:render (fn [obj fname] (: obj :render fname))}
                      :children {:sequencer {:wrap sequ-mk
                                             :get (fn [obj] obj.sequencer)}
                                 :patterns {:wrap pat-mk
                                            :get (fn [obj] obj.patterns)
                                            :array {:lookup (fn [obj ix]
                                                              (: obj :pattern
                                                                 ix))}}
                                 :master_track {:wrap track-mk
                                                :get song-get-master-track}
                                 :sequ_tracks {:wrap track-mk
                                               :get song-get-sequ-tracks
                                               :array {:minlen 1
                                                       :lookup song-lookup-sequ-track
                                                       :insert song-insert-sequ-track
                                                       :delete song-delete-sequ-track}}
                                 :send_tracks {:wrap track-mk
                                               :get song-get-send-tracks
                                               :array {:lookup song-lookup-send-track
                                                       :insert song-insert-send-track
                                                       :delete song-delete-send-track}}
                                 :instruments {:wrap inst-mk
                                               :get (fn [obj] obj.instruments)
                                               :array {:minlen 1
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
