$ = null
{CompositeDisposable} = require 'atom'

MouseEventWhichDict = {"left click": 1, "middle click": 2, "right click": 3}
module.exports =
  disposable: null

  config:
    disableComplete:
      title: 'Disable auto complete'
      type: 'boolean'
      default: false
    autoBuildTagsWhenActive:
      title: 'Automatically rebuild tags'
      description: 'Rebuild tags file each time a project path changes'
      type: 'boolean'
      default: false
    buildTimeout:
      title: 'Build timeout'
      description: 'Time (in milliseconds) to wait for a tags rebuild to finish'
      type: 'integer'
      default: 10000
    cmd:
      type: 'string'
      default: ""
    cmdArgs:
      description: 'Add specified ctag command args like: --exclude=lib --exclude=*.js'
      type: 'string'
      default: ""
    extraTagFiles:
      description: 'Add specified tagFiles. (Make sure you tag file generate with --fields=+KSn)'
      type: 'string'
      default: ""
    GotoSymbolKey:
      description: 'combine bindings: alt, ctrl, meta, shift'
      type: 'array'
      default: ["alt"]
    GotoSymbolClick:
      type: 'string'
      default: "left click"
      enum: ["left click", "middle click", "right click"]

  provider: null

  activate: ->
    @stack = []

    @ctagsCache = require "./ctags-cache"

    @ctagsCache.activate()

    @ctagsCache.initTags(atom.project.getPaths(), atom.config.get('atom-ctags-with-file-path.autoBuildTagsWhenActive'))
    @disposable = atom.project.onDidChangePaths (paths)=>
      @ctagsCache.initTags(paths, atom.config.get('atom-ctags-with-file-path.autoBuildTagsWhenActive'))

    atom.commands.add 'atom-workspace', 'atom-ctags-with-file-path:rebuild', (e, cmdArgs)=>
      console.error "rebuild: ", e
      @ctagsCache.cmdArgs = cmdArgs if Array.isArray(cmdArgs)
      @createFileView().rebuild(true)
      if t
        clearTimeout(t)
        t = null

    atom.commands.add 'atom-workspace', 'atom-ctags-with-file-path:toggle-project-symbols', =>
      @createFileView().toggleAll()

    atom.commands.add 'atom-text-editor',
      'atom-ctags-with-file-path:toggle-file-symbols': => @createFileView().toggle()
      'atom-ctags-with-file-path:go-to-declaration': => @createFileView().goto()
      'atom-ctags-with-file-path:return-from-declaration': => @createGoBackView().toggle()

    atom.workspace.observeTextEditors (editor) =>
      editorView = atom.views.getView(editor)
      {$} = require 'atom-space-pen-views' unless $
      $(editorView).on 'mousedown', (event) =>
        which = atom.config.get('atom-ctags-with-file-path.GotoSymbolClick')
        return unless MouseEventWhichDict[which] == event.which
        for keyName in atom.config.get('atom-ctags-with-file-path.GotoSymbolKey')
          return if not event[keyName+"Key"]
        @createFileView().goto()

    if not atom.packages.isPackageDisabled("symbols-view")
      atom.packages.disablePackage("symbols-view")
      alert "Warning from atom-ctags-with-file-path:
              atom-ctags-with-file-path replaces and enhances the symbols-view package.
              Therefore, symbols-view has been disabled."

    atom.config.observe 'atom-ctags-with-file-path.disableComplete', =>
      return unless @provider
      @provider.disabled = atom.config.get('atom-ctags-with-file-path.disableComplete')

    initExtraTagsTime = null
    atom.config.observe 'atom-ctags-with-file-path.extraTagFiles', =>
      clearTimeout initExtraTagsTime if initExtraTagsTime
      initExtraTagsTime = setTimeout((=>
        @ctagsCache.initExtraTags(atom.config.get('atom-ctags-with-file-path.extraTagFiles').split(" "))
        initExtraTagsTime = null
      ), 1000)

  deactivate: ->
    if @disposable?
      @disposable.dispose()
      @disposable = null

    if @fileView?
      @fileView.destroy()
      @fileView = null

    if @projectView?
      @projectView.destroy()
      @projectView = null

    if @goToView?
      @goToView.destroy()
      @goToView = null

    if @goBackView?
      @goBackView.destroy()
      @goBackView = null

    @ctagsCache.deactivate()

  createFileView: ->
    unless @fileView?
      FileView  = require './file-view'
      @fileView = new FileView(@stack)
      @fileView.ctagsCache = @ctagsCache
    @fileView

  createGoBackView: ->
    unless @goBackView?
      GoBackView = require './go-back-view'
      @goBackView = new GoBackView(@stack)
    @goBackView

  provide: ->
    unless @provider?
      CtagsProvider = require './ctags-provider'
      @provider = new CtagsProvider()
      @provider.ctagsCache = @ctagsCache
      @provider.disabled = atom.config.get('atom-ctags-with-file-path.disableComplete')
    @provider
