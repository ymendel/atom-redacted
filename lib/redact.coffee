{$, EditorView, View} = require 'atom'

module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      redactor = new PercentRedactor(25)
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
  constructor: ->
    @editor = atom.workspace.getActiveEditor()

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
    this.redactWord(text)

  redactWord: (word) ->
    Array(word.length + 1).join("█")

class PercentRedactor extends Redactor
  constructor: (percent) ->
    super
    @percent = (percent or 25) / 100
    @regex   = /([\w'-]+)/g

  shouldRedact: ->
    Math.random() < @percent

class AlwaysRedactor extends Redactor
  shouldRedact: ->
    true

class NonWhitespaceRedactor extends AlwaysRedactor
  constructor: ->
    super
    @regex = /(\S+)/g

class FullLineRedactor extends AlwaysRedactor
  constructor: ->
    super
    @regex = /^\s*(.+)\s*$/gm

  redactText: (text) ->
    breakdown = text.match(/^(\s*)(.+)(\s*)$/)[1..]
    breakdown[1] = this.redactWord(breakdown[1])
    breakdown.join("")

class PatternRedactor extends AlwaysRedactor
  constructor: (regex) ->
    super
    @regex = regex


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

    this.redactor(input).redact()

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

  redactor: (input) ->
    percent = parseInt(input)
    if percent == 101
      new NonWhitespaceRedactor
    else if percent == 102
      new FullLineRedactor
    else
      new PercentRedactor(percent)

class RedactPatternView extends RedactInputView
  @contentClass: 'redact-pattern'

  initialize: ->
    @messageText = 'Enter a string'
    super

  redactor: (input) ->
    pattern = new RegExp(input, 'g')
    new PatternRedactor(pattern)
