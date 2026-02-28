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
GbsRemoteTranscript >> startPolling [
	"Deprecated: The VW port uses push-updates instead of polling. Safely ignore."
	^ self.
]

{ #category : 'initialization' }
GbsRemoteTranscript >> stopPolling [
	"Deprecated: Safely ignore."
	^ self.
]
