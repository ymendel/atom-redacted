{$, EditorView, View} = require 'atom'

module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      editor   = atom.workspace.getActiveEditor()
      redactor = new PercentRedactor(editor: editor, percent: 25)
      redactor.redact()

    atom.workspaceView.command 'redacted:percent-toggle', '.editor', ->
      view = new RedactPercentView
      view.toggle()
      false

    atom.workspaceView.command 'redacted:pattern-toggle', '.editor', ->
      view = new RedactPatternView
      view.toggle()
      false

class Redactor
  constructor: (options) ->
    @editor  = options.editor

  redact: ->
    @editor.transact =>
      ranges = @editor.getSelectedBufferRanges()
      selection = null
      if ranges.length is 1 and ranges[0].isEmpty()
        selection = @editor.selectAll()[0]
        ranges    = [selection.getBufferRange()]

      for range in ranges
        this.redactRange(range)

      selection?.clear()

  redactRange: (range) ->
    originalText = @editor.getTextInBufferRange(range)
    redactedText = originalText.replace @regex, (match) =>
      if this.shouldRedact()
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

class PercentRedactor extends Redactor
  constructor: (options) ->
    super
    @percent = (options.percent or 25) / 100
    @regex   = /([\w'-]+)/g

    if options.percent == 101
      @regex = /(\S+)/g
    else if options.percent == 102
      @full_line = true
      @regex = /^\s*(.+)\s*$/gm

  shouldRedact: ->
    Math.random() < @percent

class PatternRedactor extends Redactor
  constructor: (options) ->
    super
    @regex = options.regex

  shouldRedact: ->
    true


class RedactInputView extends View
  @content: ->
    @div class: "redact-input #{@contentClass} overlay from-top mini", =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'message', outlet: 'message'

  detaching: false

  initialize: ->
    @miniEditor.hiddenInput.on 'focusout', => @detach() unless @detaching
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

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
    input  = @miniEditor.getText()
    editor = atom.workspace.getActiveEditor()

    @detach()

    return unless editor? and input.length

    this.redactor(editor, input).redact()

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
      @message.text(@messageText)
      @miniEditor.focus()

class RedactPercentView extends RedactInputView
  @contentClass: 'redact-percent'

  initialize: ->
    @messageText = 'Enter a percentage'

    super

    @miniEditor.getModel().on 'will-insert-text', ({cancel, text}) =>
      cancel() unless text.match(/[0-9]/)

  redactor: (editor, input) ->
    return unless editor? and input?

    percent = parseInt(input)

    new PercentRedactor(editor: editor, percent: percent)

class RedactPatternView extends RedactInputView
  @contentClass: 'redact-pattern'

  initialize: ->
    @messageText = 'Enter a string'

    super

  redactor: (editor, input) ->
    return unless editor? and input?

    pattern = new RegExp(input, 'g')

    new PatternRedactor(editor: editor, regex: pattern)
