Class {
	#name : 'GbsRemoteTranscript',
	#superclass : 'SpPresenter',
	#instVars : [
		'textPresenter',
		'btnRefresh'
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

{ #category : 'actions' }
GbsRemoteTranscript >> fetchNewEntries [
	| activeSession logText safeScript |
	
	textPresenter text: 'Fetching from GemStone...'.
	
	activeSession := GbsSessionParameters currentSession.
	activeSession ifNil: [ 
		textPresenter text: '--- Not connected to a session ---'. 
		^ self 
	].
	
	safeScript := '
		| log |
		log := SessionTemps current at: #RemoteTranscript ifAbsent: [ nil ].
		log ifNil: [ ^ ''--- No logs recorded yet ---'' ].
		
		String streamContents: [ :stream |
			log do: [ :each | 
				stream nextPutAll: each asString; nextPut: Character lf 
			]
		]
	'.
	
	[
		logText := activeSession evaluate: safeScript.
		textPresenter text: logText asString.
	] on: Error do: [ :ex | 
		textPresenter text: '--- Safe Mode Caught Error: ', ex printString, ' ---'.
	].
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializePresenters [
	textPresenter := self newText.
	btnRefresh := self newButton.
	btnRefresh label: 'Refresh Log'; icon: (self iconNamed: #glamorousRefresh).
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializeWindow: aWindowPresenter [
	aWindowPresenter 
		title: 'GemStone Remote Transcript (Safe Mode)';
		initialExtent: 600@400.
]
