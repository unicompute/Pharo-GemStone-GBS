Class {
	#name : 'GbsRemoteTranscript',
	#superclass : 'SpPresenter',
	#instVars : [
		'textPresenter',
		'btnRefresh',
		'pollingProcess'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'utilities' }
GbsRemoteTranscript class >> show: aString [
    | transcript |
    "Find an already open transcript, or create a new one if closed"
    transcript := self allInstances 
        detect: [ :each | each window isNotNil and: [ each window isOpen ] ]
        ifNone: [ 
            | newTrans |
            newTrans := self new.
            newTrans open.
            newTrans startPolling.
            newTrans 
        ].
        
    transcript appendText: aString.
]

{ #category : 'logic' }
GbsRemoteTranscript >> appendText: aString [
    | currentText |
    currentText := textPresenter text ifNil: [ '' ].
    
    "Append the raw text and add a carriage return"
    textPresenter text: currentText asString, aString, String cr.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> connectPresenters [
	btnRefresh action: [ self fetchNewEntries ].
]

{ #category : 'layout' }
GbsRemoteTranscript >> defaultLayout [
	^ SpBoxLayout newVertical
		add: btnRefresh expand: false fill: false padding: 5;
		add: textPresenter;
		yourself
]

{ #category : 'logic' }
GbsRemoteTranscript >> fetchLogs [
    | rawResult logsString activeSession |
    (GbsSessionParameters pollingEnabled) ifFalse: [ ^ self ].
    activeSession := GbsSessionParameters currentSession.
    
    activeSession ifNotNil: [
        [
            rawResult := activeSession evaluate: 'Transcript fetchAndClear'.
            
            rawResult ifNotNil: [
                "Safely check how to unbox the string"
                logsString := (rawResult class name = #GbsProxy) 
                    ifTrue: [ rawResult asLocalString ] 
                    ifFalse: [ rawResult asString ].
                
                (logsString isNotNil and: [ logsString trim isNotEmpty and: [ logsString trim ~= 'nil' ]]) ifTrue: [
                     "Defer the UI update so the background thread does not crash"
                     UIManager default defer: [
                         textPresenter text: (textPresenter text asString, logsString).
                     ].
                ].
            ].
        ] on: Error do: [ :ex | "Ignore background thread errors" ]
    ].
]

{ #category : 'polling' }
GbsRemoteTranscript >> fetchNewEntries [
	| activeSession logText |
	
	activeSession := GbsSessionParameters currentSession.
	activeSession ifNil: [ ^ self ].
	
	"Because this is now safely on the main thread, we wrap everything in an error block"
	[
		logText := activeSession evaluate: '
			| log |
			log := SessionTemps current at: #RemoteTranscript ifAbsentPut: [ OrderedCollection new ].
			String streamContents: [ :stream |
				log do: [ :each | stream nextPutAll: each asString; nextPut: Character lf ]
			]
		'.
		textPresenter ifNotNil: [ textPresenter text: logText asString ].
	] on: Error do: [ :ex | 
		textPresenter ifNotNil: [ textPresenter text: '--- Polling: Waiting for server response ---' ].
	].
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializePresenters [
	textPresenter := self newText.
	
	btnRefresh := self newButton.
	btnRefresh label: 'Refresh Log'; icon: (self iconNamed: #glamorousRefresh).
	
	"Fetch once safely when the window opens"
	self fetchNewEntries.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializeWindow: aWindowPresenter [
	aWindowPresenter 
		title: 'GemStone Remote Transcript';
		initialExtent: 600@400.
	"Removed the whenClosedDo: stopPolling hook entirely"
]

{ #category : 'polling' }
GbsRemoteTranscript >> startPolling [
	pollingProcess ifNotNil: [ pollingProcess terminate ].
	
	pollingProcess := [
		(Delay forMilliseconds: 500) wait.
		
		[ self window isNotNil and: [ self window isOpen ] ] whileTrue: [
			"Force BOTH the FFI call and the UI update onto the Main Thread!"
			UIManager default defer: [ self fetchNewEntries ].
			(Delay forSeconds: 2) wait.
		]
	] fork.
]

{ #category : 'logic' }
GbsRemoteTranscript >> stopPolling [
	pollingProcess ifNotNil: [ 
		pollingProcess terminate.
		pollingProcess := nil.
	].
]
