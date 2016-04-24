prelude = require 'prelude-ls'
{find,each,map,filter,reject,empty,Obj} = prelude

module.exports = class Repo
  ->
    @nodes = {}
    @refs = {}

  inspect: ->
    "Repo<#{object-size(@nodes)}>"

  process-wire-cmd: ([ctyp, {ni,ri,nti,rti,sni,gni,name,attrs,ati,bri,val}]) ->
    switch ctyp
    case 'core'
      @nodes[ni] = new Node {repo:@,ni,nti,name,attrs}
    case 'comp'
      @nodes[ni] = new Node {repo:@,ni,nti,name,attrs}
      gni = ni
      @refs[ri] = ref = new Ref {repo:@,ri,rti,sni,gni,dep:true}
      source = @nodes[sni] or throw "node #{sni} not found"
      target = @nodes[gni] or throw "node #{gni} not found"
      before-ref = if bri then (@refs[bri] || throw "ref #{bri} not found")
      ins-ref source.refs, ref, before-ref
      target.inrefs.push ref
    case 'link'
      @refs[ri] = ref = new Ref {repo:@,ri,rti,sni,gni,dep:false}
      source = @nodes[sni] or throw "node #{sni} not found"
      target = @nodes[gni] or throw "node #{gni} not found"
      before-ref = if bri then (@refs[bri] || throw "ref #{bri} not found")
      ins-ref source.refs, ref, before-ref
      target.inrefs.push ref
    case 'move'
      node = @nodes[ni]
      ref = node.parent-ref!
      ref.source!.rm-ref ref
      ref.sni = sni
      ref.rti = rti
      @nodes[sni].add-ref ref, {bri}
    case 'name'
      @nodes[ni].name = name
    case 'ntyp'
      node = @nodes[ni] or throw "node #{ni} not found"
      node.nti = nti
    case 'attr'
      if ati == '5' # name
        @nodes[ni].name = name
      else
        @nodes[ni].attrs[ati] = val
    case 'rtyp'
      ref = @refs[ri] or throw "ref #{ri} not found"
      ref.rti = rti
    case 'del'
      parent-ref = @nodes[ni].parent-ref!
      parent-ref.source!.rm-ref(parent-ref)
      delete @nodes[ni]
    case 'ulnk'
      ref = @refs[ri]
      ref.source!.rm-ref(ref)
      ref.target!.rm-inref(ref)
    case 'root'
      @root = ni

  export-wire-cmds: (cb) ->
    e = new Exporter(@, cb)
    e.export!

  export-repo: ->
    e = new RawExporter(@)
    e.export!

class Node
  ({@repo,@ni,@nti,@name,@attrs}) ->
    @attrs ?= {}
    @refs = []
    @inrefs = []

  type: -> @repo.nodes[@nti]
  parent-ref: -> @inrefs |> find (ref) -> ref.dep
  parent: -> (r = @parent-ref!) && r.source!

  add-ref: (ref, {bri}) ->
    before-ref = if bri then (@repo.refs[bri] or throw "bri not found")
    ins-ref @refs, ref, before-ref
  rm-ref: (ref) -> rm-ref @refs, ref
  rm-inref: (ref) -> rm-ref @inrefs, ref

class Ref
  ({@repo,@ri,@rti,@sni,@gni,@dep}) ->

  inspect: -> JSON.stringify [@ri,@rti,@sni,@gni,@dep]
  source: -> @repo.nodes[@sni] or throw "@sni not found in #{@inspect!}"
  target: -> @repo.nodes[@gni] or throw "@gni not found in #{@inspect!}"
  type:   -> @repo.nodes[@rti] or throw "@rti not found in #{@inspect!}"

rm-ref = (list, ref) ->
  if (index = list.index-of ref) != -1
    list.splice index, 1
  else
    throw "Could not find ref in list"

ins-ref = (list, ref, before-ref) ->
  if before-ref
    index = list.index-of(before-ref)
    if index == -1
      console.log "list", list
      console.log "ref", ref
      console.log "before-ref", before-ref
      throw "before-ref not found in list"
    list.splice(index, 0, ref)
  else
    list.push(ref)

class Exporter
  (@repo,@command-callback) ->
    #console.log "repo", @repo
    @queue = <[ 1 2 3 4 5 6 7 8 9 10 112 ]>
    @known = build-obj-with-keys @queue, true
    @ignored = {}
    @dumped = {}
    @last-func-id = -1
    @funcs = []
    @dependencies = {}
    @dependants = {}
    @ri-order = {}

  export: ->
    while ni = @queue.shift!
      break if @limit && @dumped.size >= @limit
      @migrate-node(ni)

  export-command: (cmd, args) ->
    @command-callback [cmd, args]

  migrate-node: (ni) ->
    return if @limit && @dumped.size >= @limit
    return if @dumped[ni]
    #console.log "\nNode #{ni}"
    return if ni == '947' || ni == '126' || ni == '122'
    node = @repo.nodes[ni] or throw "node not found #{ni}"
    {nti,name,attrs} = node

    if nti == ni || @dumped[nti]
      # Find parent ref
      pr = node.parent-ref!
      #if pr
        #console.log "--- pr", pr, pr.ri, pr.sni, pr.gni, pr.dep
      dumpable-attrs = {}
      if pr && @dumped[pr.sni] && @dumped[pr.rti]
        for ati, val of attrs
          if @dumped[ati]
            dumpable-attrs[ati] = val
          else
            @depends-on ati, {ni,ati,val}, ({ni,ati,val}) ~>
              @export-command 'attr', {ni,ati,val}
        {ri,sni,rti} = pr
        #console.log "(1) - comp", {ri,sni,rti,ni,nti,name,attrs:dumpable-attrs}
        @export-command 'comp', {ri,sni,rti,bri:@track-and-find-bri(sni,ri),ni,nti,name,attrs:dumpable-attrs}
      else
        @export-command 'core', {ni,nti,name}
        for ati, val of attrs
          @depends-on ati, {ni,ati,val}, ({ni,ati,val}) ~>
            @export-command 'attr', {ni,ati,val}
        if pr
          @depends-on pr.sni, {pr,ni,name,dumpable-attrs}, ({pr,ni,name,dumpable-attrs}) ~>
            @depends-on pr.rti, {pr,ni,name,dumpable-attrs}, ({pr,ni,name,dumpable-attrs}) ~>
              {ri,sni,rti} = pr
              #console.log "(2) - comp", {ri,sni,rti,ni,nti,name,attrs:dumpable-attrs}
              @export-command 'comp', {ri,sni,rti,bri:@track-and-find-bri(sni,ri),ni,nti,name,attrs:dumpable-attrs}

      rm-item ni, @queue
      @dumped[ni] = true
      @resolve-dependency ni

      if refs = node.refs
        for ref in refs
          @depends-on ref.rti, {ref}, ({ref}) ~>
            if ref.dep
              @migrate-node ref.gni
            else
              @depends-on ref.gni, {ref}, ({ref}) ~>
                {ri,sni,rti,gni,dep} = ref
                #console.log "(3) - link", {ri,sni,rti,gni}
                @export-command 'link', {ri,sni,rti,gni,bri:@track-and-find-bri(sni,ri)}
    else
      @depends-on nti, {ni}, ({ni}) ~> @migrate-node ni

  discover: (ni) ->
    unless @known[ni] || @ignored[ni]
      @queue.push ni
      @known[ni] = true

  depends-on: (ni-list, arg, func) ->
    ni-list = to-array(ni-list) |> reject (ni) ~> @dumped[ni]
    if ni-list |> empty
      func(arg)
    else
      func-id = (@last-func-id += 1)
      @funcs[func-id] = -> func(arg)
      @dependencies[func-id] = ni-list
      for ni in ni-list
        @dependants[ni] ?= []
        @dependants[ni].push func-id
        @discover ni

  resolve-dependency: (ni) ->
    func-ids = @dependants[ni]
    if func-ids && func-ids.length > 0
      for func-id in func-ids
        rm-item ni, @dependencies[func-id]
        if @dependencies[func-id].length == 0
          delete @dependencies[func-id]
          func = @funcs[func-id]
          delete @funcs[func-id]
          func!
    delete @dependants[ni]

  track-and-find-bri: (ni, ri) ->
    ri-list = @repo.nodes[ni].refs |> map (.ri)
    @ri-order[ni] ?= [ri-list, []]
    [orig, curr] = @ri-order[ni]
    if curr.index-of(ri) != -1
      throw "ri already exported. ni:#{ni}, ri:#{ri}, ri-list:#{ri-list}, orig: #{orig}, curr: #{curr}"
    index = orig.index-of ri
    if index == -1
      throw "ri node found in orig: #{ri} - #{orig} (ni: #{ni})"
    candidates = orig.slice(index + 1)
    bri = candidates |> find (cand) -> curr.index-of(cand) != -1
    if bri
      bri-index = curr.index-of(bri)
      if bri-index == -1
        throw "bri not found in curr: #{bri} - #{curr}"
      curr.splice(bri-index, 0, ri)
    else
      #if ri == '144'
        #throw "#{ni},#{ri} pushed to curr"
      curr.push ri
    bri

class RawExporter
  (@repo) ->

  export: ->
    data = {root:@repo.root,nodes:{},refs:{}}
    for ni, node of @repo.nodes
      {nti,name,attrs} = node
      refs = node.refs |> map (r) -> r.ri
      inrefs = node.inrefs |> map (r) -> r.ri
      data.nodes[ni] = {ni,nti,name,attrs,refs,inrefs}
    for ri, ref of @repo.refs
      {rti,sni,gni,dep} = ref
      data.refs[ri] = {ri,rti,sni,gni,dep}
    data


obj-filter = (cb, obj) ->
  new-obj = {}
  for key, val of obj
    if cb(key, val)
      new-obj[key] = val
  new-obj

obj-each = (cb, obj) ->
  for key, val of obj
    cb(key, val)

rm-item = (x, arr) ->
  index = arr.index-of x
  if index != -1
    arr.splice index, 1
  arr


build-obj-with-keys = (keys, value) ->
  obj = {}
  for key in keys
    obj[key] = value
  obj

to-array = (x) -> if is-array(x) then x else [x]
is-array = (x) -> _prt(x) === '[object Array]'
_prt = (x) -> Object.prototype.toString.call(x)

object-size = (obj) ->
  size = 0
  for key, value of obj
    if obj.hasOwnProperty(key)
      size += 1
  size
