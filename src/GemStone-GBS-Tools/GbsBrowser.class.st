Class {
	#name : 'GbsBrowser',
	#superclass : 'SpPresenter',
	#instVars : [
		'classList',
		'methodList',
		'codeView',
		'currentClassName'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'actions' }
GbsBrowser >> compileMethod: sourceString [
	| escapedSource script result |
	
	currentClassName ifNil: [ 
		self inform: 'Please select a class first!'. 
		^ self 
	].
	
	"1. Escape single quotes in the Pharo source code so it can be safely injected into a String script"
	escapedSource := sourceString copyReplaceAll: '''' with: ''''''.
	
	"2. Ask the remote GemStone class to compile the string"
	script := '
	| cls |
	cls := Smalltalk at: #', currentClassName asString, '.
	cls compileMethod: ''', escapedSource, ''' category: ''User-Defined''.
	''Method compiled successfully!''
	'.
	
	result := GbsSessionParameters currentSession evaluate: script.
	
	self inform: 'GemStone: ', result asString.
	
	"3. Refresh the method list so your newly saved method instantly appears in the UI!"
	self loadMethodListFor: currentClassName.
]

{ #category : 'initialization' }
GbsBrowser >> connectPresenters [
	classList whenSelectionChangedDo: [ :selection |
		selection selectedItem ifNotNil: [ :className |
			currentClassName := className.
			self loadMethodListFor: className.
			self showClassDefinition: className.
		]
	].
	
	methodList whenSelectionChangedDo: [ :selection |
		selection selectedItem ifNotNil: [ :selector |
			currentClassName ifNotNil: [
				self showMethodSource: selector class: currentClassName
			]
		]
	].
	
	"--> Catch Cmd+S / Ctrl+S to save the code!! <--"
	codeView whenSubmitDo: [ :text |
		self compileMethod: text asString
	].
]

{ #category : 'layout' }
GbsBrowser >> defaultLayout [
    ^ SpPanedLayout newVertical
        positionOfSlider: 40 percent;
        add: (SpPanedLayout newLeftToRight
                add: classList;
                add: methodList;
                yourself);
        add: codeView;
        yourself
]

{ #category : 'initialization' }
GbsBrowser >> initializePresenters [
    classList := self newList.
    methodList := self newList.
    codeView := self newCode. 
    codeView syntaxHighlight: true.

    "Load Class List (as one big string for speed)"
    self loadClassList.

    "Action: When Class is selected"
    classList whenSelectionChangedDo: [ :selection | 
        selection selectedItem ifNotNil: [ :clsName | 
            currentClassName := clsName.
            self loadMethodListFor: clsName.
            self showClassDefinition: clsName.
        ]
    ].

    "Action: When Method is selected"
    methodList whenSelectionChangedDo: [ :selection | 
        selection selectedItem ifNotNil: [ :selector | 
            self showMethodSource: selector class: currentClassName.
        ]
    ].
]

{ #category : 'initialization' }
GbsBrowser >> initializeWindow: aWindowPresenter [
    aWindowPresenter title: 'GemStone System Browser'; initialExtent: 800@600.
]

{ #category : 'data fetching' }
GbsBrowser >> loadClassList [
    | allNamesString |
    allNamesString := GbsSessionParameters currentSession evaluate: '
        | stream names |
        stream := WriteStream on: String new.
        names := (ClassOrganizer new classes collect: [:c | c name]) asSortedCollection.
        names do: [:n | stream nextPutAll: n; cr].
        stream contents
    '.
    classList items: allNamesString lines.
]

{ #category : 'data fetching' }
GbsBrowser >> loadMethodListFor: aClassName [
    | selectorsString |
    selectorsString := GbsSessionParameters currentSession evaluate: '
        | cls stream sels |
        cls := Smalltalk at: ', aClassName asSymbol printString, '.
        stream := WriteStream on: String new.
        sels := cls selectors asSortedCollection.
        sels do: [:s | stream nextPutAll: s; cr].
        stream contents
    '.
    methodList items: selectorsString lines.
]

{ #category : 'display' }
GbsBrowser >> showClassDefinition: aClassName [
    | def |
    def := GbsSessionParameters currentSession evaluate: aClassName, ' definition'.
    codeView text: def.
]

{ #category : 'display' }
GbsBrowser >> showMethodSource: aSelector class: aClassName [
    | query source |
    
    "Construct the GemStone code using a template."
    "Example result: (Object compiledMethodAt: #printString) sourceString"
    query := '({1} compiledMethodAt: #{2}) sourceString' 
                format: { aClassName . aSelector }.

    "Execute on GemStone"
    source := GbsSessionParameters currentSession evaluate: query.
    
    "Update the text view (ensure we get a String, not a Proxy)"
    codeView text: source asString.
]
