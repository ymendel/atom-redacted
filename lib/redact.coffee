{$, TextEditorView, View} = require 'atom-space-pen-views'

module.exports =
  activate: ->
    atom.commands.add '.editor', 'redacted:redact', ->
      redactor = new PercentRedactor(25)
      redactor.redact()

    atom.commands.add '.editor', 'redacted:percent-toggle', ->
      view = new RedactPercentView
      view.toggle()
      false

    atom.commands.add '.editor', 'redacted:pattern-toggle', ->
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
    this.redactChars(text)

  redactChars: (chars) ->
    Array(chars.length + 1).join("█")

class PercentRedactor extends Redactor
  constructor: (percent) ->
    super
    @percent = (percent or 25) / 100
    @regex   = /(\w+(?:[\w'-]*\w+)?)/g

  redactText: (text) ->
    text.replace /[\w']/g, (match) =>
      this.redactChars(match)

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
    breakdown[1] = this.redactChars(breakdown[1])
    breakdown.join("")

class PatternRedactor extends AlwaysRedactor
  constructor: (regex) ->
    super
    @regex = regex

class RedactInputView extends View
  @content: ->
    @div class: "redact-input #{@contentClass}", =>
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'message', outlet: 'message'

  initialize: ->
    @miniEditor.on 'blur', => @close()

    atom.commands.add this.element,
      'core:confirm': =>
        @confirm()
      'core:cancel': =>
        @close()

  toggle: ->
    if @panel?.isVisible()
      @close()
    else
      @attach()

  close: ->
    @miniEditor.setText('')
    @panel?.hide()
    atom.workspace.getActivePane().activate()

  confirm: ->
    input  = @miniEditor.getText()
    editor = atom.workspace.getActiveEditor()

    @close()

    return unless editor? and input.length

    this.redactor(input).redact()

  attach: ->
    if editor = atom.workspace.getActiveEditor()
      @panel = atom.workspace.addModalPanel(item: this)
      @message.text(@messageText)
      @miniEditor.focus()

class RedactPercentView extends RedactInputView
  @contentClass: 'redact-percent'

  initialize: ->
    @messageText = 'Enter a percentage'
    super

    @miniEditor.preempt 'textInput', (e) =>
      false unless e.originalEvent.data.match(/[0-9]/)

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
