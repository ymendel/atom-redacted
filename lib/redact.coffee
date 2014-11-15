redact = (editor) ->
  editor.transact ->
    for range in editor.getSelectedBufferRanges()
      redactText(range, editor)

redactText = (range, editor) ->
  originalText = editor.getTextInBufferRange(range)
  redactedText = Array(originalText.length).join("x")
  editor.setTextInBufferRange(range, redactedText)

module.exports =
  activate: ->
    atom.workspaceView.command 'redacted:redact', '.editor', ->
      editor = atom.workspace.getActiveEditor()
      redact(editor)

  redact: redact
