redact = (editor) ->
  editor.transact ->
    for range in editor.getSelectedBufferRanges()
      redactText(range, editor)

redactText = (range, editor) ->
  originalText = editor.getTextInBufferRange(range)
  redactedText = originalText.replace /([\w'-]+)/g, (match) ->
    redactWord(match)
  editor.setTextInBufferRange(range, redactedText)

redactWord = (word) ->
  Array(word.length + 1).join("█")

module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      editor = atom.workspace.getActiveEditor()
      redact(editor)

  redact: redact
