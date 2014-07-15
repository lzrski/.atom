path = require 'path'
{WorkspaceView} = require 'atom'
fs = require 'fs-plus'
temp = require 'temp'

describe "GitDiff package", ->
  [editor, editorView, projectPath] = []

  beforeEach ->
    spyOn(window, 'setImmediate').andCallFake (fn) -> fn()

    projectPath = temp.mkdirSync('git-diff-spec-')
    fs.copySync(path.join(__dirname, 'fixtures', 'working-dir'), projectPath)
    fs.moveSync(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
    atom.project.setPath(projectPath)

    atom.workspaceView = new WorkspaceView
    atom.workspaceView.attachToDom()

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      editorView = atom.workspaceView.getActiveView()
      {editor} = editorView

    waitsForPromise ->
      atom.packages.activatePackage('git-diff')

  describe "when the editor has modified lines", ->
    it "highlights the modified lines", ->
      expect(editorView.find('.git-line-modified').length).toBe 0
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editorView.find('.git-line-modified').length).toBe 1
      expect(editorView.find('.git-line-modified')).toHaveClass('line-number-0')

  describe "when the editor has added lines", ->
    it "highlights the added lines", ->
      expect(editorView.find('.git-line-added').length).toBe 0
      editor.moveCursorToEndOfLine()
      editor.insertNewline()
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editorView.find('.git-line-added').length).toBe 1
      expect(editorView.find('.git-line-added')).toHaveClass('line-number-1')

  describe "when the editor has removed lines", ->
    it "highlights the line preceeding the deleted lines", ->
      expect(editorView.find('.git-line-added').length).toBe 0
      editor.setCursorBufferPosition([5])
      editor.deleteLine()
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editorView.find('.git-line-removed').length).toBe 1
      expect(editorView.find('.git-line-removed')).toHaveClass('line-number-4')

  describe "when a modified line is restored to the HEAD version contents", ->
    it "removes the diff highlight", ->
      expect(editorView.find('.git-line-modified').length).toBe 0
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editorView.find('.git-line-modified').length).toBe 1
      editor.backspace()
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editorView.find('.git-line-modified').length).toBe 0

  describe "when a modified file is opened", ->
    it "highlights the changed lines", ->
      nextTick = false
      filePath = atom.project.resolve('sample.txt')
      buffer = atom.project.bufferForPathSync(filePath)
      buffer.setText("Some different text.")

      waitsForPromise ->
        atom.workspace.open('sample.txt')

      runs ->
        editorView = atom.workspaceView.getActiveView()

      setImmediate ->
        nextTick = true

      waitsFor ->
        nextTick

      runs ->
        expect(editorView.find('.git-line-modified').length).toBe 1
        expect(editorView.find('.git-line-modified')).toHaveClass('line-number-0')

  describe "move-to-next-diff/move-to-previous-diff events", ->
    it "moves the cursor to first character of the next/previous diff line", ->
      editor.insertText('a')
      editor.setCursorBufferPosition([5])
      editor.deleteLine()
      advanceClock(editor.getBuffer().stoppedChangingDelay)

      editor.setCursorBufferPosition([0])
      editorView.trigger 'git-diff:move-to-next-diff'
      expect(editor.getCursorBufferPosition()).toEqual [4, 4]

      editorView.trigger 'git-diff:move-to-previous-diff'
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

    it "wraps around to the first/last diff in the file", ->
      editor.insertText('a')
      editor.setCursorBufferPosition([5])
      editor.deleteLine()
      advanceClock(editor.getBuffer().stoppedChangingDelay)

      editor.setCursorBufferPosition([0])
      editorView.trigger 'git-diff:move-to-next-diff'
      expect(editor.getCursorBufferPosition()).toEqual [4, 4]

      editorView.trigger 'git-diff:move-to-next-diff'
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

      editorView.trigger 'git-diff:move-to-previous-diff'
      expect(editor.getCursorBufferPosition()).toEqual [4, 4]

  describe "when the showIconsInEditorGutter config option is true", ->
    beforeEach ->
      atom.config.set 'git-diff.showIconsInEditorGutter', true

    it "the gutter has a git-diff-icon class", ->
      expect(editorView.find('.gutter')).toHaveClass 'git-diff-icon'

    it "keeps the git-diff-icon class when editor.showLineNumbers is toggled", ->
      atom.config.set 'editor.showLineNumbers', false
      expect(editorView.find('.gutter')).not.toHaveClass 'git-diff-icon'

      atom.config.set 'editor.showLineNumbers', true
      expect(editorView.find('.gutter')).toHaveClass 'git-diff-icon'

    it "removes the git-diff-icon class when the showIconsInEditorGutter config option set to false", ->
      atom.config.set 'git-diff.showIconsInEditorGutter', false
      expect(editorView.find('.gutter')).not.toHaveClass 'git-diff-icon'
