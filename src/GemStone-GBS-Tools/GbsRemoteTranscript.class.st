Class {
	#name : 'GbsRemoteTranscript',
	#superclass : 'SpPresenter',
	#instVars : [
		'textPresenter',
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

{ #category : 'layout' }
GbsRemoteTranscript >> defaultLayout [
    ^ SpBoxLayout newVertical add: textPresenter; yourself
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
	
	"1. Fetch the remote log from GemStone's temporary session memory"
	logText := activeSession evaluate: '
		| log |
		log := SessionTemps current at: #RemoteTranscript ifAbsentPut: [ OrderedCollection new ].
		String streamContents: [ :stream |
			log do: [ :each | stream nextPutAll: each asString; lf ]
		]
	'.
	
	"2. Safely update the text pane using the correct variable name!"
	textPresenter text: logText asString.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializePresenters [
    textPresenter := self newText.
    textPresenter beNotEditable.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializeWindow: aWindowPresenter [
	aWindowPresenter 
		title: 'GemStone Remote Transcript';
		initialExtent: 600@400;
		whenClosedDo: [ self stopPolling ].
]

{ #category : 'polling' }
GbsRemoteTranscript >> startPolling [
	pollingProcess ifNotNil: [ pollingProcess terminate ].
	
	pollingProcess := [
		"1. Give the window half a second to actually build and open"
		(Delay forMilliseconds: 500) wait.
		
		[ self window isNotNil and: [ self window isOpen ] ] whileTrue: [
			"2. Safely marshal the FFI call and UI update onto the Main UI Thread"
			UIManager default defer: [ 
				self fetchNewEntries 
			].
			
			"3. Wait 2 seconds before asking again"
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
