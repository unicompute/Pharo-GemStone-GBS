Class {
	#name : 'GbsRemoteTranscript',
	#superclass : 'SpPresenter',
	#instVars : [
		'textPresenter',
		'btnClear'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'gemstone integration' }
GbsRemoteTranscript class >> installGemStoneProxy [

  | session script aGbsRemoteTranscript |
  aGbsRemoteTranscript := self new.
  session := GbsSessionParameters currentSession.
  session ifNil: [ ^ aGbsRemoteTranscript inform: 'Please log in to GemStone first!' ].

  "1. Write the script using backticks (`) and double quotes ("") to avoid escaping nightmares"
  script := '
	| proxyClass |
	proxyClass := Object subclass: `PharoTranscriptProxy`
		instVarNames: #()
		classVars: #()
		classInstVars: #(`currentLine`)
		poolDictionaries: #()
		inDictionary: UserGlobals.

	proxyClass class compileMethod: `show: aString
		currentLine := (currentLine ifNil: [ """" ]), aString asString.`
	category: `logging`.

	proxyClass class compileMethod: `cr
		| log |
		log := SessionTemps current at: #PharoTranscriptLog ifAbsentPut: [ OrderedCollection new ].
		log add: (currentLine ifNil: [ """" ]).
		currentLine := """".`
	category: `logging`.

	UserGlobals at: #Transcript put: proxyClass.
	System commitTransaction.
	true.'.

  "2. Safely swap them back to actual Smalltalk single quotes before sending!"
  script := script copyReplaceAll: '`' with: ''''.
  script := script copyReplaceAll: '"' with: ''''.

  "3. Send the pristine script to GemStone safely"
  [
    session evaluate: script.
    aGbsRemoteTranscript inform: 'GemStone Transcript Proxy Successfully Installed!'
    ]
    on: Error
    do: [ :ex | aGbsRemoteTranscript inform: 'Installation failed: ' , ex description ]
]

{ #category : 'updating' }
GbsRemoteTranscript >> appendLog: aString [
	"Ported VW Pattern: Push the UI update onto the safe UIManager queue"
	UIManager default defer: [
		| currentText |
		currentText := textPresenter text asString.
		textPresenter text: currentText, aString, Character cr asString.
	].
]

{ #category : 'layout' }
GbsRemoteTranscript >> defaultLayout [
	^ SpBoxLayout newVertical
		add: btnClear expand: false fill: false padding: 2;
		add: textPresenter;
		yourself
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializePresenters [
	textPresenter := self newText.
	textPresenter beNotEditable.
	
	btnClear := self newButton.
	btnClear label: 'Clear'; icon: (self iconNamed: #smallDelete).
	btnClear action: [ textPresenter text: '' ].
]

{ #category : 'initialization' }
GbsRemoteTranscript >> initializeWindow: aWindowPresenter [
	aWindowPresenter 
		title: 'GemStone Remote Transcript (VW Port)';
		initialExtent: 600@400.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> installGemStoneProxy [
	^ self class installGemStoneProxy
]

{ #category : 'initialization' }
GbsRemoteTranscript >> startPolling [
	"Deprecated: The VW port uses push-updates instead of polling. Safely ignore."
	^ self.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> stopPolling [
	"Deprecated: Safely ignore."
	^ self.
]
