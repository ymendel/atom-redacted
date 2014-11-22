{$, EditorView, Point, View} = require 'atom'

module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      editor   = atom.workspace.getActiveEditor()
      redactor = new Redactor(editor: editor, percent: 25)
      redactor.redact()

    atom.workspaceView.command 'redacted:percent-toggle', '.editor', ->
      view = new RedactPercentView
      view.toggle()
      false

class Redactor
  constructor: (args) ->
    @editor  = args.editor
    @percent = (args.percent or 25) / 100
    @regex   = /([\w'-]+)/g
    if args.percent == 101
      @regex = /(\S+)/g
    else if args.percent == 102
      @full_line = true
      @regex = /^\s*(.+)\s*$/gm

  redact: ->
    @editor.transact =>
      for range in @editor.getSelectedBufferRanges()
        this.redactRange(range)

  redactRange: (range) ->
    originalText = @editor.getTextInBufferRange(range)
    redactedText = originalText.replace @regex, (match) =>
      if Math.random() < @percent
        this.redactText(match)
      else
        match
    @editor.setTextInBufferRange(range, redactedText)

  redactText: (text) ->
    if @full_line
      breakdown = text.match(/^(\s*)(.+)(\s*)$/)[1..]
      breakdown[1] = this.redactWord(breakdown[1])
      breakdown.join("")
    else
      this.redactWord(text)

  redactWord: (word) ->
    Array(word.length + 1).join("█")

class RedactPercentView extends View
  @content: ->
    @div class: 'redact-percent overlay from-top mini', =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'message', outlet: 'message'

  detaching: false

  initialize: ->
    @miniEditor.hiddenInput.on 'focusout', => @detach() unless @detaching
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

    @miniEditor.getModel().on 'will-insert-text', ({cancel, text}) =>
      cancel() unless text.match(/[0-9]/)

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

   detach: ->
    return unless @hasParent()

    @detaching = true
    miniEditorFocused = @miniEditor.isFocused
    @miniEditor.setText('')

    super

    @restoreFocus() if miniEditorFocused
    @detaching = false

  confirm: ->
    percent = @miniEditor.getText()
    editor  = atom.workspace.getActiveEditor()

    @detach()

    return unless editor? and percent.length
    percent = parseInt(percent)

    redactor = new Redactor(editor: editor, percent: percent)
    redactor.redact()

  storeFocusedElement: ->
    @previouslyFocusedElement = $(':focus')

  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.workspaceView.focus()

  attach: ->
    if editor = atom.workspace.getActiveEditor()
      @storeFocusedElement()
      atom.workspaceView.append(this)
      @message.text("Enter a percentage")
      @miniEditor.focus()
