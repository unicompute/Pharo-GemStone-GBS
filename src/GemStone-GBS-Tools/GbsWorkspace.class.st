Class {
	#name : 'GbsWorkspace',
	#superclass : 'SpPresenter',
	#instVars : [
		'textEditor',
		'btnExecute',
		'btnCommit',
		'btnAbort'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'layout' }
GbsWorkspace >> defaultLayout [
	^ SpBoxLayout newVertical
		spacing: 5;
		add: (SpBoxLayout newHorizontal
			spacing: 5;
			add: btnExecute;
			add: btnCommit;
			add: btnAbort;
			yourself) height: 30;
		add: textEditor;
		yourself
]

{ #category : 'actions' }
GbsWorkspace >> doAbort [
	GbsSessionParameters currentSession ifNotNil: [ :session |
		session abort.
		self inform: 'GemStone: Aborted and Synced to latest state.'
	].
]

{ #category : 'actions' }
GbsWorkspace >> doCommit [
	GbsSessionParameters currentSession ifNotNil: [ :session |
		session commitTransaction
			ifTrue: [ self inform: 'GemStone: Commit Successful!' ]
			ifFalse: [ self inform: 'GemStone: Commit Failed (Conflict)!' ]
	]
]

{ #category : 'actions' }
GbsWorkspace >> doIt [
	| text |
	text := textEditor selectedText.
	text isEmpty ifTrue: [ text := textEditor text ].
	
	GbsSessionParameters currentSession ifNil: [ 
		^ self inform: 'Not connected to GemStone!' 
	].
	
	"Safely evaluate without returning or inspecting the proxy"
	GbsSessionParameters currentSession evaluate: text asString.
	self inform: 'GemStone: Execution Complete'.
]

{ #category : 'actions' }
GbsWorkspace >> executeInGemStone [
    | code result |
    code := self selectedCodeOrAll.
    code ifEmpty: [ ^ self ].

    [ 
        result := GbsSessionParameters currentSession evaluate: code.
        result inspect.

        "Log success to transcript"
        GbsRemoteTranscript show: 'Successfully executed: ', code
    ] on: Error do: [ :ex |
        (ex isKindOf: GbsError)
            ifTrue: [ ex defaultAction ]
            ifFalse: [ 
                (ex messageText includesSubstring: 'session ID is invalid')
                    ifTrue: [ 
                        GbsRemoteTranscript show: 'Error: GemStone Session expired.'.
                        self inform: 'GemStone Session expired. Please run the Login script again.' ]
                    ifFalse: [ 
                        GbsRemoteTranscript show: 'Execution Error: ', ex messageText.
                        ex pass ]
            ]
    ]
]

{ #category : 'actions' }
GbsWorkspace >> gemStoneDebugIt [
    | code |
    code := self selectedCodeOrAll.
    code ifEmpty: [ ^ self ].

    [ 
        GbsSessionParameters currentSession evaluate: code.
        self inform: 'GemStone: Executed (No errors to debug)'.
        GbsRemoteTranscript show: 'Debug It: Executed without errors.'
    ] on: Error do: [ :ex |
        "Check if it's a GemStone error or local error"
        (ex isKindOf: GbsError)
            ifTrue: [ 
                "GemStone server error - let it propagate for debugging"
                ex pass ]
            ifFalse: [ 
                "Local Pharo error"
                GbsRemoteTranscript show: 'Debug It Error caught: ', ex messageText.
                ex inspect.
                self inform: 'Local Error caught. Inspecting exception...' ]
    ]
]

{ #category : 'actions' }
GbsWorkspace >> gemStonePrintIt [
	| text result proxyString currentText |
	text := textEditor selectedText.
	text isEmpty ifTrue: [ text := textEditor text ].
	
	GbsSessionParameters currentSession ifNil: [ 
		^ self inform: 'Not connected to GemStone!' 
	].
	
	"1. Ask GemStone to evaluate the code AND convert the result to a String on the server!"
	result := GbsSessionParameters currentSession evaluate: '( ', text asString, ' ) printString'.
	
	"2. Safely append the result to the bottom of the Workspace"
	proxyString := result asString.
	currentText := textEditor text asString.
	textEditor text: currentText , ' "', proxyString, '" '.
]

{ #category : 'initialization' }
GbsWorkspace >> initialize [

  super initialize.
  "In Pharo 13, we ensure the code presenter is ready for interaction"
  textEditor
    syntaxHighlight: true;
    beForObject: self.

  textEditor bindKeyCombination: $g command toAction: [ self executeInGemStone ].
  textEditor bindKeyCombination: $g control toAction: [ self executeInGemStone ]
]

{ #category : 'initialization' }
GbsWorkspace >> initializePresenters [
	textEditor := self newCode.
	textEditor syntaxHighlight: true.
	textEditor beForObject: self.
	textEditor contextMenu: [ self workspaceMenu ].
	
	textEditor bindKeyCombination: $d command toAction: [ self doIt ].
	textEditor bindKeyCombination: $p command toAction: [ self gemStonePrintIt ].
	
	"CRITICAL FIX: Point this to doIt, NOT inspectIt!"
	btnExecute := self newButton
		label: 'Execute in GemStone (Cmd+G)';
		icon: ( self iconNamed: #glamorousPlay );
		action: [ self doIt ].
		
	btnCommit := self newButton label: 'Commit'; icon: (self iconNamed: #smallSave); action: [ self doCommit ].
	btnAbort := self newButton label: 'Abort (Sync)'; icon: (self iconNamed: #smallCancel); action: [ self doAbort ].
]

{ #category : 'initialization' }
GbsWorkspace >> initializeShortcutKeys [
    textEditor bindKeyCombination: $g command toAction: [ self executeInGemStone ].
    textEditor bindKeyCombination: $g control toAction: [ self executeInGemStone ]
]

{ #category : 'initialization' }
GbsWorkspace >> initializeWindow: aWindowPresenter [

  aWindowPresenter
    title: 'GemStone Workspace';
    initialExtent: 600 @ 400
]

{ #category : 'private' }
GbsWorkspace >> insertResult: aString [

  | text selectionEnd newText |
  text := textEditor text asString.
  selectionEnd := textEditor selectionInterval last.

  newText := ( text copyFrom: 1 to: selectionEnd ) , ' ' , aString
             , ( text copyFrom: selectionEnd + 1 to: text size ).

  textEditor text: newText
]

{ #category : 'gemstone actions' }
GbsWorkspace >> inspectIt [

  | code rawResult |
  code := self selectedCodeOrAll.
  code ifEmpty: [ ^ self ].

  [ "Wrap code in a Block to safely execute multiple statements"
    rawResult := GbsSessionParameters currentSession evaluate: '[ ' , code , ' ] value'.

    "Inspect the raw result (either a Proxy or a native Pharo object)"
    rawResult inspect
    ]
    on: Error
    do: [ :ex | "Check if it's a GemStone error or local error"
        ( ex isKindOf: GbsError )
          ifTrue: [ "GemStone server error - pass it up to open debugger" ex pass ]
          ifFalse: [ "Local Pharo error" self inform: 'Local Error: ' , ex messageText ]
        ]
]

{ #category : 'local actions' }
GbsWorkspace >> localDebugIt [

  | code method context process |
  code := self selectedCodeOrAll.
  code ifEmpty: [ ^ self ].

  [ "1. Tell the compiler this is a headless DoIt (isScripting: true)"
    method := Smalltalk compiler
                source: code;
                isScripting: true;
                compile.

    "2. Create a runtime context for the method"
    context := Context
                 sender: nil
                 receiver: nil
                 method: method
                 arguments: #(  ).

    "3. Create a suspended process for this context"
    process := Process forContext: context priority: Processor userSchedulingPriority.

    "4. Tell the process to open the debugger on itself"
    process debug
    ]
    on: Error
    do: [ :ex | self inform: 'Pharo Local Error: ' , ex messageText ]
]

{ #category : 'local actions' }
GbsWorkspace >> localDoIt [
    | code |
    code := self selectedCodeOrAll.
    code ifEmpty: [ ^ self ].

    [ 
        "Execute locally using standard Pharo Compiler"
        Smalltalk compiler evaluate: code.
        self inform: 'Local DoIt: Executed'
    ] on: Error do: [ :ex | 
        self inform: 'Local Error: ', ex messageText 
    ]
]

{ #category : 'actions' }
GbsWorkspace >> localInspectIt [
    | code result |
    code := self selectedCodeOrAll.
    code ifEmpty: [ ^ self ].

    [ 
        result := Smalltalk compiler evaluate: code.
        result inspect
    ] on: Error do: [ :ex | 
        self inform: 'Local Error: ', ex messageText 
    ]
]

{ #category : 'actions' }
GbsWorkspace >> localPrintIt [

  | code result |
  code := self selectedCodeOrAll.
  code ifEmpty: [ ^ self ].

  [
    result := Smalltalk compiler evaluate: code.
    "Use our manual insertion helper"
    self insertResult: result printString
    ]
    on: Error
    do: [ :ex | self inform: 'Local Error: ' , ex messageText ]
]

{ #category : 'initialization' }
GbsWorkspace >> openRemoteDebuggerOn: aGbsError session: aSession [

  GbsRemoteDebugger new
    session: aSession;
    exception: aGbsError;
    open
]

{ #category : 'private' }
GbsWorkspace >> replaceSelectionWith: aString [

  | text selectionInterval newText |
  text := textEditor text asString.
  selectionInterval := textEditor selectionInterval.

  newText := ( text copyFrom: 1 to: selectionInterval first - 1 ) , aString
             , ( text copyFrom: selectionInterval last + 1 to: text size ).

  textEditor text: newText.
  "Move cursor to end of inserted text"
  textEditor selectionInterval:
    ( selectionInterval first + aString size to: selectionInterval first + aString size - 1 )
]

{ #category : 'private' }
GbsWorkspace >> selectedCodeOrAll [

  | code |
  code := textEditor selectedText.
  code ifEmpty: [ code := textEditor text ].
  ^ code
]

{ #category : 'private' }
GbsWorkspace >> selectedText [

  ^ textEditor selectedText
]

{ #category : 'layout' }
GbsWorkspace >> staticLayout [

  ^ SpBoxLayout newVertical
      add: textEditor;
      yourself
]

{ #category : 'accessing' }
GbsWorkspace >> textEditor [
    ^ textEditor
]

{ #category : 'menus' }
GbsWorkspace >> workspaceMenu [

  | menu |
  menu := self newMenu.

  "--- GEMSTONE ACTIONS ---"
  menu addGroup: [ :group |
      group addItem: [ :item |
          item
            name: 'GemStone Do it';
            shortcut: $d command;
            icon: ( self iconNamed: #smallDoIt );
            action: [ self doIt ]
          ].
      group addItem: [ :item |
          item
            name: 'GemStone Inspect it';
            shortcut: $i command;
            icon: ( self iconNamed: #smallInspectIt );
            action: [ self inspectIt ]
          ].
      group addItem: [ :item |
          item
            name: 'GemStone Print it';
            shortcut: $p command;
            icon: ( self iconNamed: #smallPrintIt );
            action: [ self gemStonePrintIt ]
          ].

      "Debug It now calls the specific method"
      group addItem: [ :item |
          item
            name: 'GemStone Debug it';
            icon: ( self iconNamed: #smallDebug );
            action: [ self gemStoneDebugIt ]
          ]
      ].

  "--- EDITING ---"
  menu addGroup: [ :group |
      group addItem: [ :item |
          item
            name: 'Copy';
            shortcut: $c command;
            icon: ( self iconNamed: #smallCopy );
            action: [ Clipboard clipboardText: self selectedText ]
          ].
      group addItem: [ :item |
          item
            name: 'Cut';
            shortcut: $x command;
            icon: ( self iconNamed: #smallCut );
            action: [
                Clipboard clipboardText: self selectedText.
                self replaceSelectionWith: ''
                ]
          ].
      group addItem: [ :item |
          item
            name: 'Paste';
            shortcut: $v command;
            icon: ( self iconNamed: #smallPaste );
            action: [ self replaceSelectionWith: Clipboard clipboardText ]
          ]
      ].

  "--- LOCAL ACTIONS ---"
  menu addGroup: [ :group |
      group addItem: [ :item |
          item
            name: 'Local Do it';
            icon: ( self iconNamed: #smallDoIt );
            action: [ self localDoIt ]
          ].
      group addItem: [ :item |
          item
            name: 'Local Inspect it';
            icon: ( self iconNamed: #smallInspectIt );
            action: [ self localInspectIt ]
          ].
      group addItem: [ :item |
          item
            name: 'Local Print it';
            icon: ( self iconNamed: #smallPrintIt );
            action: [ self localPrintIt ]
          ].

      "Debug It now calls the specific method"
      group addItem: [ :item |
          item
            name: 'Local Debug it';
            icon: ( self iconNamed: #smallDebug );
            action: [ self localDebugIt ]
          ]
      ].

  ^ menu
]
