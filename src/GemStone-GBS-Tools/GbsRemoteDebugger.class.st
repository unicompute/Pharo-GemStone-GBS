Class {
	#name : 'GbsRemoteDebugger',
	#superclass : 'SpPresenter',
	#instVars : [
		'session',
		'exception',
		'listFrames',
		'textSource'
	],
	#category : 'GemStone-GBS-Tools',
	#package : 'GemStone-GBS-Tools'
}

{ #category : 'as yet unclassified' }
GbsRemoteDebugger >> populateFrames [
	"Extract the context from the GciError struct inside the exception"
	| contextOop |
	contextOop := exception tag context.
	listFrames items: { 'Remote Context (OOP: ', contextOop asString, ')' }.
]

{ #category : 'as yet unclassified' }
GbsRemoteDebugger >> session: aSession exception: aGbsError [
	session := aSession.
	exception := aGbsError.
	self populateFrames.
]
