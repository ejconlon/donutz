;; Extracted from submodules/fennel/src/fennel/repl.fnl
;; This is needed to maintain locals across repl prompts.

(fn splice-save-locals [env lua-source scope]
  (let [saves (icollect [name (pairs env.___replLocals___)]
                (: "local %s = ___replLocals___['%s']"
                   :format (or (. scope.manglings name) name) name))
        binds (icollect [raw name (pairs scope.manglings)]
                (when (not (. scope.gensyms name))
                  (: "___replLocals___['%s'] = %s"
                     :format raw name)))
        gap (if (lua-source:find "\n") "\n" " ")]
    (.. (if (next saves) (.. (table.concat saves " ") gap) "")
        (match (lua-source:match "^(.*)[\n ](return .*)$")
          (body return) (.. body gap (table.concat binds " ") gap return)
          _ lua-source))))

