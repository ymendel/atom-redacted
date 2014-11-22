module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      editor   = atom.workspace.getActiveEditor()
      redactor = new Redactor(editor: editor, percent: 25)
      redactor.redact()

class Redactor
  constructor: (args) ->
    @editor  = args.editor
    @percent = (args.percent or 25) / 100

  redact: ->
    @editor.transact =>
      for range in @editor.getSelectedBufferRanges()
        this.redactText(range)

  redactText: (range) ->
    originalText = @editor.getTextInBufferRange(range)
    redactedText = originalText.replace /([\w'-]+)/g, (match) =>
      if Math.random() < @percent
        this.redactWord(match)
      else
        match
    @editor.setTextInBufferRange(range, redactedText)

  redactWord: (word) ->
    Array(word.length + 1).join("█")
